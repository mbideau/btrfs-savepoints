#!/bin/sh
#
# Backup and Restore instantly with ease your BTRFS filesystem
#
# Standards in this script:
#   POSIX compliance:
#      - http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#      - https://www.gnu.org/software/autoconf/manual/autoconf.html#Portable-Shell
#   CLI standards:
#      - https://www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces
#
# Source code, documentation and support:
#   https://github.com/mbideau/btrfs-savepoints
#
# Copyright (C) 2020-2021 Michael Bideau [France]
#
# This file is part of btrfs-savepoints.
#
# btrfs-savepoints is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# btrfs-savepoints is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with btrfs-savepoints. If not, see <https://www.gnu.org/licenses/>.
#

# TODO implement option --dry-run for deletion (especialy with --force-deletion)
# TODO read ISO/non-ISO date, and write ISO date if option --iso-date is provided

# halt on first error
set -e


# package infos
PROGRAM_NAME=btrfs-sp
VERSION=0.1.0
# shellcheck disable=SC2034
PACKAGE_NAME=btrfs-savepoints
AUTHOR='Michael Bideau'
HOME_PAGE='https://github.com/mbideau/btrfs-savepoints'
REPORT_BUGS_TO="$HOME_PAGE/issues"


# functions

# usage
usage()
{
    cat <<ENDCAT

$PROGRAM_NAME - $( \
__ 'backup and restore instantly with ease your BTRFS filesystem.')

$(__ 'USAGE')

    $PROGRAM_NAME [$(__ 'OPTIONS')] $(__ 'COMMAND') [$(__ 'CMD_ARGS')]

    $PROGRAM_NAME new-conf $(__ 'CONFIG') $(__ 'MOUNTED_PATH') $(__ 'SUBVOL_PATH')
    $PROGRAM_NAME ls-conf

    $PROGRAM_NAME backup
    $PROGRAM_NAME restore  $(__ 'CONFIG') $(__ 'SAVEPOINT')
    $PROGRAM_NAME delete   $(__ 'CONFIG') $(__ 'SAVEPOINT') ..$(__ 'SAVEPOINTS')..

    $PROGRAM_NAME ls
    $PROGRAM_NAME diff $(__ 'CONFIG') $(__ 'SP_REF') $(__ 'SP_CMP')
    $PROGRAM_NAME subvol-diff $(__ 'CONFIG') $(__ 'SP_CMP')

    $PROGRAM_NAME prune
    $PROGRAM_NAME replace-diff
    $PROGRAM_NAME rotate-number

    $PROGRAM_NAME log
    $PROGRAM_NAME log-add

    $PROGRAM_NAME [ -h | --help ]


$(__ 'COMMANDS')

    backup
        $(__ 'For each configuration, may create a new snapshot and do pruning.')
        $(__ 'Alias'): create | save | add | bak | new

    restore
        $(__ 'Restore/replace the current BTRFS subvolume with the specified savepoint.')
        $(__ 'Alias'): rest | rollback | roll

    delete
        $(__ 'Remove savepoints.')
        $(__ 'Alias'): del | remove | rm

    new-conf
        $(__ 'Create a new savepoint configuration.')
        $(__ 'Alias'): create-conf | add-conf

    ls-conf
        $(__ 'List the configurations.')
        $(__ 'Alias'): list-conf

    ls
        $(__ 'List all the savepoints.')
        $(__ 'Alias'): list | list-savepoints | list-backups

    prune
        $(__ "Run the pruning algorithm (same as '%s' then '%s')." 'purge-diff' 'purge-number')
        $(__ 'Alias'): rotate | rot | purge

    replace-diff
        $(__ 'Run the purge-diff algorithm, that replace savepoints that have no differences by a symlink.')
        $(__ 'Alias'): purge-diff

    rotate-number
        $(__ 'Run the purge-number algorithm that delete savepoints based on a retention strategy that keep X savepoints for each kind of time unit (sessions, minutes, hours, days, weeks, months, years).')
        $(__ 'Alias'): purge-number

    log
        $(__ 'Print/read the persistent log.')
        $(__ 'Alias'): log-print | log-read

    log-add
        $(__ 'Add/write something to the persistent log.')
        $(__ 'Alias'): log-write

    diff
        $(__ 'Get differences between two savepoints (of the same configuration).')

    subvol-diff
        $(__ 'Get differences between current subvolume and a savepoint (of the same configuration).')
        $(__ 'Alias'): sub-diff | subvolume-diff


$(__ 'OPTIONS') $(__ 'For all commands')

    -g | --global-config $(__ 'CONFIG')
        $(__ 'Path to a global configuration file.')
        $(__ 'Default to'): '$DEFAULT_CONFIG_GLOBAL'.

    -r | --from-toplevel-subvol PATH
        $(__ 'Prefix paths with the specified PATH'), $(
        __ 'then add the relatives prefixes from BTRFS top level subvolume'), $(\
        __ 'instead of paths relative to mounted root filesystem').
        $(__ "This is mainly used in initramfs or systemd unit when root filesystem is not mounted")
        $(__ "but instead the whole BTRFS tree is mounted at PATH (with the subvolume '%s')." 'id:5')

    --help-conf
        $(__ 'Display help message about the configuration.')

    -h | --help
        $(__ 'Display help message.')

    -v | --version
        $(__ 'Display version and license informations.')

    --initramfs
        $(__ "When specified, will understand that it is executed in the initramfs"), $(__ "meaning :")
            * $(__ "trying to source the helper function script at :")
                $INITRAMFS_HELPER_SCRIPT
            * $(__ "replacing error and message functions with the one from the helper script")
        $(__ "Meant to be used only when executed by an %s script." 'initramfs-tools')
        $(__ "Do not use it manually from command line (except for testing puppose).")

    --systemd
        $(__ "When specified, will understand that it is executed in the systemd LSB context"), $(__ "meaning :")
            * $(__ "trying to source the helper function script at :")
                $SYSTEMD_HELPER_SCRIPT
            * $(__ "replacing error and message functions with the one from the helper script")
        $(__ "Meant to be used only when executed by a %s unit." 'systemd')
        $(__ "Do not use it manually from command line (except for testing puppose).")


$(__ 'OPTIONS') $(__ 'By commands')

    backup | create | save | add | bak | new

        -c | --config CONFIG
            $(__ 'Name of the configuration')
            $(__ "Only alphanum characters are allowed, plus the following: '%s'." '-._@')

        -d | --date DATETIME
            $(__ 'A datetime (Y-m-d H:M:S) that defines the savepoint taking date time.')

        -i | --skip-free-space
            $(__ 'Skip checking free space')

        -m | --moment MOMENT
            $(__ 'A moment name in the system execution. It can be :')
                * boot
                * suspend
                * resume
                * reboot
                * shutdown
                * halt

        -s | --safe
            $(__ 'Indicate that the savepoint should be considered/flagged as a safe one.')
            $(__ 'Only savepoint that are made when the system is not running and was properly stoped, should be considered safe. Which are the following cases :')
                * $(__ 'reboot/shutdown')
                * $(__ 'offline using a LIVE system if properly stopped before')
                * $(__ 'boot (before mounting rootfs) if properly stopped before')
            $(__ 'Only reboot/shutdown are recommended because it ensures the system has properly stopped.')
            $(__ 'If the system was not properly stopped or is running with rootfs mounted,')
            $(__ 'it can cause savepoint to be made meanwhile the state of an application is not coherent, and then,')
            $(__ 'if restored, will restore an unstable/incoherent system.')
            $(__ 'Hence that important feature/option.')

        -u | --suffix SUFFIX
            $(__ 'A suffix to add to the savepoint filename.')
            $(__ "Only alphanum characters are allowed, plus the following: '%s'." '-._@')

        --now DATETIME
            $(__ 'A datetime (Y-m-d H:M:S) that indicate when is "now".')
            $(__ 'Mainly used for purging backup based on number refering to a unit of time.')

        --no-purge-diff
            $(__ 'Do not trigger the purging of savepoint based on differences.')
            $(__ 'It normaly happens after a savepoint have been created.')

        --no-purge-number
            $(__ 'Do not trigger the purging of savepoint based on numbers.')
            $(__ 'It normaly happens after a savepoint have been created.')

        --purge-number-no-session
            $(__ "Use the 'no-session' algorithm when pruning savepoints.")

    restore | rest | rollback | roll

        -d | --date DATETIME
            $(__ 'A datetime (Y-m-d H:M:S) that defines the restoration event date time.')

        -i | --skip-free-space
            $(__ 'Skip checking free space')

        -u | --suffix SUFFIX
            $(__ 'A suffix to add to the savepoint filename.')
            $(__ "Only alphanum characters are allowed, plus the following: '%s'." '-._@')

        --now DATETIME
            $(__ 'A datetime (Y-m-d H:M:S) that indicate when is "now".')
            $(__ 'Mainly used for purging backup based on number refering to a unit of time.')

    delete | del | remove | rm

        -f | --force-deletion
            $(__ 'By default, the savepoint may not be really removed, but instead just be renamed/moved up if a newer symlink where pointing at it, it will just replace that symlink.')
            $(__ 'In order to really delete it and all the symlinks pointing at it (recursively), that option must be specified.')

    new-conf | create-conf | add-conf

        -o | --no-defaults-copy
            $(__ 'Do not copy all the savepoint configuration defaults to the new configuration file.')

    ls-conf | list-conf

        --format-gui
            $(__ 'Format the output for the restoration GUI.')

    ls | list | list-savepoints | list-backups

        -c | --config CONFIG
            $(__ 'Name of the configuration')

        --format-gui
            $(__ 'Format the output for the restoration GUI.')

    prune | rotate | rot | purge
    replace-diff | purge-diff
    rotate-number | purge-number

        -u | --suffix SUFFIX
            $(__ 'A suffix to add to the savepoint filename.')
            $(__ "Only alphanum characters are allowed, plus the following: '%s'." '-._@')

        --now DATETIME
            $(__ 'A datetime (Y-m-d H:M:S) that indicate when is "now".')
            $(__ 'Mainly used for purging backup based on number refering to a unit of time.')

        --purge-number-no-session
            $(__ "Use the 'no-session' algorithm when pruning savepoints.")

    diff
    subvol-diff
        --no-ignore-patterns
            $(__ "Do not ignore the patterns configured with the variable '%s'." 'DIFF_IGNORE_PATTERNS')


$(__ 'CONFIGURATION')

    $(__ "See the option '%s' or the man page '%s'." '--help-conf' "${PROGRAM_NAME}.conf")


$(__ 'FILES')

    $DEFAULT_CONFIG_GLOBAL
        $(__ 'The default global configuration path (if not overriden with option %s).' '--global-config')

    $DEFAULT_CONFIG_LOCAL
        $(__ 'The default configuration path for local overrides.')

    $DEFAULT_CONFIGS_DIR
        $(__ 'Directory where to find the configurations for each managed folder.')


$(__ 'NOTES')
    $(__ 'The backup directory must be reachable inside the top level BTRFS filesystem mount.')
    $(__ "This implies that it must be in the same BTRFS filesystem than the backuped subvolumes (and also because of '%s')." 'btrfs send/receive')


$(__ 'EXAMPLES')

    $(__ 'Get the differences between two snapshots.')
    \$ $PROGRAM_NAME diff rootfs 2020-12-25_22h00m00.shutdown.safe 2019-12-25_21h00m00.shutdown.safe


$(__ 'ENVIRONMENT')

    DEBUG
        $(__ "Print debuging information to '%s' only if %s='%s'." 'STDERR' 'DEBUG' "$PROGRAM_NAME")

    LANGUAGE
    LC_ALL
    LANG
    TEXTDOMAINDIR
        $(__ "Influence the translation.")
        $(__ "See %s documentation." 'GNU gettext')


$(__ 'AUTHORS')

    $(__ 'Written by'): $AUTHOR


$(__ 'REPORTING BUGS')

    $(__ 'Report bugs to'): <$REPORT_BUGS_TO>


$(__ 'COPYRIGHT')

    $(usage_version | tail -n +2 | sed "2,$ s/^/    /")


$(__ 'SEE ALSO')

    $(__ 'Home page'): <$HOME_PAGE>

ENDCAT
}

# display version
usage_version()
{
    _year="$(date '+%Y')"
    # shellcheck disable=SC2039
    cat <<ENDCAT
$PROGRAM_NAME $VERSION
Copyright (C) 2020$([ "$_year" = '2020' ] || echo "-$_year") $AUTHOR.
$(__ "License %s: %s <%s>" 'GPLv3+' 'GNU GPL version 3 or later' 'https://gnu.org/licenses/gpl.html')
$(__ "This is free software: you are free to change and redistribute it.")
$(__ "There is NO WARRANTY, to the extent permitted by law.")
ENDCAT
}

# display help for the configuration
help_conf()
{
    cat <<ENDCAT

$PROGRAM_NAME - $( \
__ 'backup and restore instantly with ease your BTRFS filesystem.')

$(__ 'CONFIGURATION')

    $(__ 'Global variables')

        LOCAL_CONF
            $(__ 'File for local overrides of global configuration.')
            $(__ "It is recommended to put it where the backups are, at the root of the backups dir.")
            $(__ 'Example'):
                LOCAL_CONF=/backups/$PROGRAM_NAME/$PROGRAM_NAME.conf

        CONFIGS_DIR
            $(__ 'Directory where to find the configurations.')
            $(__ "It is recommended to put it where the backups are, at the root of the backups dir.")
            $(__ 'Example'):
                CONFIGS_DIR=/backups/$PROGRAM_NAME/conf.d

        ENSURE_FREE_SPACE_GB
            $(__ 'How much free space to preserve (in Gb).')
            $(__ 'Example'):
                ENSURE_FREE_SPACE_GB=1.2

        NO_FREE_SPACE_ACTION
            $(__ 'What action to do when there is not enough free space according to the variable %s.' \
                'ENSURE_FREE_SPACE_GB')
            $(__ 'Allowed values are the following'): fail ($(__ 'default')) | warn | prune | shell:%script%
            $(__ "Where the '%s' is the path of a shell script (called with '%s' binary)" '%script%' 'sh'), $(__ "and have the following argument (in that order) :")
                * $(__ "path of the file or directory considered")
                * $(__ "current free space available (in %s)" 'Gb')
                * $(__ "limit of free space required (in %s)" 'Gb')
            $(__ 'Example'):
                NO_FREE_SPACE_ACTION=prune

        PERSISTENT_LOG
            $(__ "Path to a 'persistent' text file (that will not be affected by rollbacks).")
            $(__ "It is recommended to put it where the backups are, at the root of the backups dir.")
            $(__ "The path is relative to the BTRFS top level subvolume.")
            $(__ 'Example'):
                PERSISTENT_LOG=/backups/$PROGRAM_NAME/$PROGRAM_NAME.log

        LOCAL_CONF_FROM_TOPLEVEL_SUBVOL
        CONFIGS_DIR_FROM_TOPLEVEL_SUBVOL
        PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL
            $(__ 'Paths relatives to the BTRFS top level subvolume %s.' '(id:5)')
            $(__ 'Example') ($(__ "If the persistent log is on a subvolume '%s' mounted at '%s'" \
                               '@backups' '/backups')):
                PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL=/@backups/$PROGRAM_NAME/$PROGRAM_NAME.log


    $(__ 'Default savepoint variables in the global configuration')
        $(__ "Just use the same as the savepoint variables (below), but prefix them by: '%s' (i.e.: %s)." \
            'SP_DEFAULT_' 'SP_DEFAULT_KEEP_NB_SESSIONS=4')
        $(__ "Except for the '%s' and '%s' variables, for which it would makes no sense." \
            'SUBVOLUME' 'SUBVOLUME_FROM_TOPLEVEL_SUBVOL')


    $(__ 'Savepoint configuration variables')

        SUBVOLUME
            $(__ "The (mounted) subvolume path to manage (backup/restore).")
            $(__ 'Example') ($(__ "For the root filesystem '%s' mounted at '%s'" '/@rootfs' '/')):
                SUBVOLUME=/

        SUBVOLUME_FROM_TOPLEVEL_SUBVOL
            $(__ 'Path of the subvolume relative to the BTRFS top level subvolume %s.' '(id:5)')
            $(__ "It is the same as the '%s' options parameter, when mounting the subvolume." \
                'subvol')
            $(__ 'Example') ($(__ "For the root filesystem '%s' mounted at '%s'" '/@rootfs' '/')):
                SUBVOLUME_FROM_TOPLEVEL_SUBVOL=/@rootfs

        SAVEPOINTS_DIR_BASE
            $(__ 'Where to backup the savepoint.')
            $(__ 'This path should belong to a mounted BTRFS subvolume.')
            $(__ 'Example (recommended)'):
                SAVEPOINTS_DIR_BASE=/backups/$PROGRAM_NAME
                $(__ "Final savepoints directory for configuration '%s', will be :" 'rootfs')
                    /backups/$PROGRAM_NAME/rootfs

        SAVEPOINTS_DIR_BASE_FROM_TOPLEVEL_SUBVOL
            $(__ 'Path of the savepoints dir relative to the BTRFS top level subvolume %s.' '(id:5)')
            $(__ 'Example') ($(__ "If the savepoints dir is on a subvolume '%s' mounted at '%s'" \
                               '@backups' '/backups')):
                SAVEPOINTS_DIR_BASE_FROM_TOPLEVEL_SUBVOL=/@backups/$PROGRAM_NAME

        BACKUP_BOOT
        BACKUP_REBOOT
        BACKUP_SHUTDOWN
        BACKUP_HALT
        BACKUP_SUSPEND
        BACKUP_RESUME
            $(__ 'When it should be automatically backuped.')
            $(__ 'Values allowed are:') yes|no|true|false
            $(__ 'Example'):
                BACKUP_REBOOT=no

        SUFFIX_BOOT
        SUFFIX_REBOOT
        SUFFIX_SHUTDOWN
        SUFFIX_HALT
        SUFFIX_SUSPEND
        SUFFIX_RESUME
            $(__ 'With what suffix.')
            $(__ 'Example'):
                SUFFIX_SUSPEND=.unsafe

        SAFE_BACKUP
            $(__ 'When it is considered a safe backup.')
            $(__ 'Example (recommended)'):
                SAFE_BACKUP=reboot,shutdown

        KEEP_NB_SESSIONS
        KEEP_NB_MINUTES
        KEEP_NB_HOURS
        KEEP_NB_DAYS
        KEEP_NB_WEEKS
        KEEP_NB_MONTHS
        KEEP_NB_YEARS
            $(__ 'How much backup to keep.')
                $(__ 'SESSION: between BOOT/RESUME and one of REBOOT/SHUTDOWN/HALT/SUSPEND')
            $(__ 'Example'):
                KEEP_NB_SESSIONS=5

        DIFF_IGNORE_PATTERNS
            $(__ 'What patterns to ignores when comparing savepoints.')
            $(__ 'Not yet used.')
            $(__ 'Example'):
                DIFF_IGNORE_PATTERNS='*.bak|*.swap|*.tmp|~*'

        HOOK_BEFORE_BACKUP
        HOOK_AFTER_BACKUP
        HOOK_BEFORE_RESTORE
        HOOK_AFTER_RESTORE
        HOOK_BEFORE_DELETE
        HOOK_AFTER_DELETE
            $(__ 'What to execute before/after backuping and/or restoring.')
            $(__ 'The hook command will be suffixed with 2 arguments') :
                * $(__ 'the BTRFS subvolume considered for the operation')
                * $(__ 'the savepoint considered for the operation')
            $(__ 'Except for the %s hooks that will only have the 2nd one.' 'DELETE')
            $(__ "The hook command will be executed by '%s'." 'sh -c')
            $(__ 'Example') ($(__ 'using a custom shell script')) :
                HOOK_BEFORE_BACKUP='/path/to/my_hook_script.sh'
            $(__ 'Example') ($(__ 'using a shell command ignoring the 2 arguments')):
                HOOK_BEFORE_BACKUP='btrfs balance -d 0 /mnt/toplevel && true'

        NO_PURGE_DIFF
            $(__ "Do not trigger the '%s' algorith after a savepoint creation." 'purge-diff')
            $(__ 'Values allowed are:') yes|no|true|false
            $(__ 'Example'):
                NO_PURGE_DIFF=yes

        NO_PURGE_NUMBER
            $(__ "Do not trigger the '%s' algorith after a savepoint creation." 'purge-number')
            $(__ 'Values allowed are:') yes|no|true|false
            $(__ 'Example'):
                NO_PURGE_NUMBER=yes

        PURGE_NUMBER_NO_SESSION
            $(__ "Use the 'no-session' algorithm when pruning savepoints.")
            $(__ 'Example'):
                PURGE_NUMBER_NO_SESSION=yes


$(__ 'FILES')

    $DEFAULT_CONFIG_GLOBAL
        $(__ 'The default global configuration path (if not overriden with option %s).' '--global-config')

    $DEFAULT_CONFIG_LOCAL
        $(__ 'The default configuration path for local overrides.')

    $DEFAULT_CONFIGS_DIR
        $(__ 'Directory where to find the configurations for each managed folder.')


$(__ 'AUTHORS')

    $(__ 'Written by'): $AUTHOR


$(__ 'REPORTING BUGS')

    $(__ 'Report bugs to'): <$REPORT_BUGS_TO>


$(__ 'COPYRIGHT')

    $(usage_version | tail -n +2 | sed "2,$ s/^/    /")


$(__ 'SEE ALSO')

    $(__ 'Home page'): <$HOME_PAGE>

ENDCAT
}

# sets all required defautls variables and exports
set_default_vars()
{
    # current script infos
    THIS_SCRIPT_PATH="$(realpath "$0")"
    THIS_SCRIPT_NAME="$(basename "$THIS_SCRIPT_PATH")"
    THIS_SCRIPT_DIR="$(dirname "$THIS_SCRIPT_PATH")"

    # configs
    DEFAULT_CONFIG_GLOBAL=/etc/btrfs-sp/btrfs-sp.conf
    DEFAULT_CONFIG_LOCAL=/etc/btrfs-sp/btrfs-sp.local.conf
    DEFAULT_CONFIGS_DIR=/etc/btrfs-sp/conf.d

    # dates
    DATE_TEXT_FORMAT='%Y-%m-%d_%Hh%Mm%S'
    DATE_STD_FORMAT='%Y-%m-%d %H:%M:%S'
    DATE_TEXT_REGEX='[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}h[0-9]\{2\}m[0-9]\{2\}'
    DATE_STD_REGEX='[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}'
    CURRENT_DATE_TEXT="$(date "+$DATE_TEXT_FORMAT")"
    MSG_DATETIME_FORMAT='%Y-%m-%d %H:%M:%S '

    # initram and systemd environments
    INITRAMFS_HELPER_SCRIPT=/scripts/functions
    SYSTEMD_HELPER_SCRIPT=/lib/lsb/init-functions

    # btrfs-diff utility
    if [ "$BTRFS_DIFF_BIN" = '' ] || [ ! -x "$BTRFS_DIFF_BIN" ]; then
        BTRFS_DIFF_BIN="$(command -v btrfs-diff 2>/dev/null || true)"
    fi

    # free space defaults
    DEFAULT_ENSURE_FREE_SPACE_GB=1
    DEFAULT_NO_FREE_SPACE_ACTION=fail

    # technical vars
    IFS_BAK="$IFS"
    MODE_DIR_CREATED='0770'

    # functions for output messages
    fun_fatal_error='fatal_error'
    fun_warning='warning'

    # default for translated messages
    GETTEXT='echo'
}

# sets all required locale variables and exports
setup_language()
{
    # translation variables

    # gettext binary or echo
    GETTEXT="$(command -v gettext 2>/dev/null || command -v echo)"

    # gettext domain name
    TEXTDOMAIN="$PROGRAM_NAME"

    # gettext domain directory
    if [ "$TEXTDOMAINDIR" = '' ]; then
        if [ -d "$THIS_SCRIPT_DIR"/locale ]; then
            TEXTDOMAINDIR="$THIS_SCRIPT_DIR"/locale
        elif [ -d /usr/share/locale ]; then
            TEXTDOMAINDIR=/usr/share/locale
        fi
    fi

    # environment variable priority defined by gettext are : LANGUAGE, LC_ALL, LC_xx, LANG
    # see: https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html#Locale-Environment-Variables
    # and: https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html#The-LANGUAGE-variable

    # gettext requires that at least one local is specified and different from 'C' in order to work
    if { [ "$LC_ALL" = '' ] || [ "$LC_ALL" = 'C' ]; } && { [ "$LANG" = '' ] || [ "$LANG" = 'C' ]; }
    then

        # set the LANG to C.UTF-8 so gettext can handle the LANGUAGE specified
        LANG=C.UTF-8
    fi

    # export language settings
    export TEXTDOMAIN
    export TEXTDOMAINDIR
    export LANGUAGE
    export LC_ALL
    export LANG
}

# translate a text and use printf to replace strings
# @param  $1  string  the string to translate
# @param  ..  string  string to substitute to '%s' (see printf format)
__()
{
    _t="$("$GETTEXT" "$1" | tr -d '\n')"
    shift
    # shellcheck disable=SC2059
    printf "$_t\\n" "$@"
}

# backup a folder/subvolume (may create a new btrfs snapshot and prune old ones)
#
# print to STDOUT the name of the configurations that have triggered a backup
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $NAME                string  name of the current configuration being processed
# @env  $THIS_SCRIPT_NAME    string  name of this script (without extension)
# @env  $CURRENT_DATE_TEXT   string  current date
# @env  $SAVEPOINTS_DIR      string  path of the savepoints directory (for the current configuration)
# @env  $SUFFIX_BOOT         string  suffix to add at boot savepoint
# @env  $SUFFIX_SUSPEND      string  suffix to add at suspend savepoint
# @env  $SUFFIX_RESUME       string  suffix to add at resume savepoint
# @env  $SUFFIX_REBOOT       string  suffix to add at reboot savepoint
# @env  $SUFFIX_SHUTDOWN     string  suffix to add at shutdown savepoint
# @env  $SUFFIX_HALT         string  suffix to add at halt savepoint
# @env  $HOOK_BEFORE_BACKUP  string  shell command to execute before the backuping
# @env  $HOOK_AFTER_BACKUP   string  shell command to execute after the backuping
# @env  $SAFE_BACKUP         string  list of moemnt that are considered as safe for backuping (coma separated)
# @env  $opt_moment          string  the moment of the backup
#
# and indirectly all the required variables of the functions: purge_diff() and purge_number()
#
cmd_backup()
{
    _ind='   '

    # if is this the moment of a backup
    if [ "$opt_moment" = '' ] || bool "$(get_opt_or_var_value "BACKUP_$opt_moment")"; then

        if [ "$opt_moment" != '' ]; then
            debug "${_ind}backup is enabled for '$opt_moment'"
        fi

        debug "${_ind}backuping (creating a new savepoint)"
        _ind='       '

        # ensure the subvolume exists and is a subvolume
        _subvol_path="$SUBVOLUME"
        if [ "$opt_from_toplevel_subvol" != '' ]; then
            _subvol_path="$(path_join "$opt_from_toplevel_subvol" \
                                      "$SUBVOLUME_FROM_TOPLEVEL_SUBVOL")"
        fi
        debug "${_ind}subvolume src: '%s'" "$_subvol_path"
        if ! is_btrfs_subvolume "$_subvol_path"; then
            "$fun_fatal_error" "$(__ "the folder at '%s' is not a subvolume")" "$_subvol_path"
        fi

        # define the savepoint path
        _ref_date="$CURRENT_DATE_TEXT"
        if [ "$opt_date" != '' ]; then
            _ref_date="$(get_date_to_text "$opt_date" || true)"
            if [ "$_ref_date" = '' ]; then
                "$fun_fatal_error" "$(__ "invalid date option '%s'")" "$opt_date"
            fi
        fi
        _sp_suffix="$opt_suffix"
        _add_safe_suffix=false
        if [ "$opt_moment" != '' ]; then
            _sp_suffix_value="$(get_opt_or_var_value "SUFFIX_$(upper "$opt_moment")")"
            _sp_suffix="${_sp_suffix}${_sp_suffix_value}"
            if [ "$_sp_suffix" = '' ]; then
                _sp_suffix=".$opt_moment"
            fi
            if echo ",$(get_opt_or_var_value 'SAFE_BACKUP')," | grep -q ",$opt_moment,"; then
                _add_safe_suffix=true
            fi
        fi
        if bool "$_add_safe_suffix" || bool "$opt_safe"; then
            _sp_suffix="${_sp_suffix}.safe"
        fi
        _sp_fn="${_ref_date}${_sp_suffix}"
        _sp_dir="$SAVEPOINTS_DIR"
        _sp_path="$_sp_dir/$_sp_fn"
        debug "${_ind}savepoint path: $_sp_path"

        # if the destination exists, it might be a bug (shoud not happen)
        if [ -e "$_sp_path" ]; then
            "$fun_fatal_error" "$(__ "the savepoint '%s' already exists ! (bug ?)" "$_sp_path")"
        fi

        log "[$NAME] CMD backup '%s'" "$_sp_fn"

        # trigger the hook before backup
        _hook="$(get_opt_or_var_value 'HOOK_BEFORE_BACKUP')"
        if [ "$_hook" ]; then
            _hook="$_hook '$_subvol_path' '$_sp_path'"
            debug "${_ind}triggering the hook command '%s'" "$_hook"
            if ! sh -c "$_hook"; then
                log "[$NAME] ERR %s hook '%s' failed" 'before' "$_hook"
                "$fun_fatal_error" "the hook command '%s' has failed" "$_hook"
            fi
        fi

        # ensure there is enough space left
        if ! bool "$opt_skip_free_space"; then
            ensure_enough_free_space "$_sp_dir"
        fi

        # ensure the savepoints directory exist
        if [ ! -d "$_sp_dir" ]; then
            debug "${_ind}creating savepoints directory '%s'" "$_sp_dir"
            # shellcheck disable=SC2174
            mkdir -m "$MODE_DIR_CREATED" -p "$_sp_dir"
        fi

        # backup the btrfs subvolume to it
        debug "${_ind}backup the btrfs subvolume '%s' to '%s' (read-only)" \
            "$(basename "$_subvol_path")" "$_sp_fn"
        if ! btrfs subvolume snapshot -r "$_subvol_path" "$_sp_path" >/dev/null; then
            log "[$NAME] ERR failed to snapshot '%s' to '%s'" "$_subvol_path" "$_sp_path"
            "$fun_fatal_error" "$(__ "failed to snapshot '%s' to '%s'" "$_subvol_path" "$_sp_path")"
        fi
        log "[$NAME] + %s <== %s" "$_sp_fn" "$_subvol_path"
        echo "$NAME"

        # pruning savepoints
        prune_savepoints "$_sp_fn"

        # trigger the hook after backup
        _hook="$(get_opt_or_var_value 'HOOK_AFTER_BACKUP')"
        if [ "$_hook" ]; then
            _hook="$_hook '$_subvol_path' '$_sp_path'"
            debug "${_ind}triggering the hook command '%s'" "$_hook"
            if ! sh -c "$_hook"; then
                log "[$NAME] ERR %s hook '%s' failed" 'after' "$_hook"
                "$fun_fatal_error" "the hook command '%s' has failed" "$_hook"
            fi
        fi
    fi
}

# restore a folder/subvolume from a savepoint
#
# @param  $1  string  name of the savepoint to restore from
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $NAME                string  name of the current configuration being processed
# @env  $CURRENT_DATE_TEXT    string  current date
# @env  $SAVEPOINTS_DIR       string  path of the savepoints directory (for the current configuration)
# @env  $HOOK_BEFORE_RESTORE  string  shell command to execute before the restoration
# @env  $HOOK_AFTER_RESTORE   string  shell command to execute after the restoration
#
cmd_restore()
{
    _sp_from="$SAVEPOINTS_DIR/$1"
    if [ ! -e "$_sp_from" ]; then
        "$fun_fatal_error" "$(__ "the savepoint '%s' doesn't exist")" "$_sp_from"
    fi

    # if the savepoint is a symlink
    if [ -L "$_sp_from" ]; then

        # get use its target savepoint
        _sp_from_target="$(realpath "$_sp_from")"

        # and ensure it is a savepoint (belonging to the savepoints directory)
        if [ "$(dirname "$_sp_from_target")" != "$(realpath "$SAVEPOINTS_DIR")" ]; then
            "$fun_fatal_error" "$(__ "the savepoint '%s' is a link to '%s', that doesn't belong to savepoints dir '%s'" \
                "$_sp_from" "$_sp_from_target" "$(realpath "$SAVEPOINTS_DIR")")"
        fi
        _sp_from="$_sp_from_target"
    fi

    # define the new savepoint path
    _ref_date="$CURRENT_DATE_TEXT"
    if [ "$opt_date" != '' ]; then
        _ref_date="$(get_date_to_text "$opt_date" || true)"
        if [ "$_ref_date" = '' ]; then
            "$fun_fatal_error" "$(__ "invalid date option '%s'" "$opt_date")"
        fi
    fi

    # ensure the subvolume exists and is a subvolume
    _subvol_path="$SUBVOLUME"
    if [ "$opt_from_toplevel_subvol" != '' ]; then
        _subvol_path="$(path_join "$opt_from_toplevel_subvol" \
                                    "$SUBVOLUME_FROM_TOPLEVEL_SUBVOL")"
    fi
    debug "   subvolume dest: '$_subvol_path'"
    if ! is_btrfs_subvolume "$_subvol_path"; then
        "$fun_fatal_error" "$("the folder at '%s' is not a subvolume" "$_subvol_path")"
    fi

    # TODO ensure the subvolume is not mounted or is read-only
    #      but for now, that incompatible with the almost continuous snapshoting idea

    # snapshot to flag the actual state of the subvolume
    # (the .0 is to maintain alphanum order to appear before the 'after-restoration' one)
    _snap_to_fn="${_ref_date}${opt_suffix}.0.before-restoring-from-$1"
    _snap_to="$SAVEPOINTS_DIR/$_snap_to_fn"
    if [ -e "$_snap_to" ]; then
        "$fun_fatal_error" "$(__ "the savepoint '%s' already exists ! (bug ?)" "$_snap_to")"
    fi

    log "[$NAME] CMD restore '%s'" "$1"

    # trigger hook before restoration
    _hook="$(get_opt_or_var_value 'HOOK_BEFORE_RESTORE')"
    if [ "$_hook" ]; then
        _hook="$_hook '$_subvol_path' '$_sp_from'"
        debug "${_ind}triggering the hook command '%s'" "$_hook"
        if ! sh -c "$_hook"; then
            log "[$NAME] ERR %s hook '%s' failed" 'before' "$_hook"
            "$fun_fatal_error" "the hook command '%s' has failed" "$_hook"
        fi
    fi

    # ensure there is enough space left
    if ! bool "$opt_skip_free_space"; then
        ensure_enough_free_space "$(dirname "$_snap_to")"
    fi

    # creating a new read-only snapshot from the current subvolume
    # and add it to the list of savepoints (renamed)
    debug "   creating a savepoint (snapshot ro) '%s' from subvolume '%s'" "$_snap_to_fn" "$_subvol_path"
    if ! btrfs subvolume snapshot -r "$_subvol_path" "$_snap_to" >/dev/null; then
        log "[$NAME] ERR failed to create snapshot (ro) from '%s' to '%s'" "$_subvol_path" "$_snap_to"
        "$fun_fatal_error" "$(__ "failed to create snapshot (ro) from '%s' to '%s'" "$_subvol_path" "$_snap_to")"
    fi

    log "[$NAME] + %s <== %s" "$_snap_to_fn" "$_subvol_path"

    # remove existing subvolume
    debug "   removing the subvolume '%s'" "$_subvol_path"
    if ! btrfs subvolume delete --commit-after "$_subvol_path" >/dev/null; then
        log "[$NAME] ERR failed to delete subvolume '%s'" "$_subvol_path"
        "$fun_fatal_error" "$(__ "failed to delete subvolume '%s'" "$_subvol_path")"
    fi

    log "[$NAME] - %s" "$_subvol_path"

    # creating the subvolume from a snapshot (read-write) of the savepoint
    debug "   creating the subvolume (snapshot rw) '%s' from the savepoint (snapshot ro) '%s'" \
        "$(basename "$_subvol_path")" "$1"
    if ! btrfs subvolume snapshot "$_sp_from" "$_subvol_path" >/dev/null; then
        log "[$NAME] ERR failed to create snapshot (rw) from '%s' to '%s'" "$_sp_from" "$_subvol_path"
        "$fun_fatal_error" "$(__ "failed to create snapshot (rw) from '%s' to '%s'" "$_sp_from" "$_subvol_path")"
    fi

    log "[$NAME] + %s <<< %s" "$_subvol_path" "$1"

    # snapshot again to flag the restoration point
    # (the .1 is to maintain alphanum order to appear after the 'before-restoration' one)
    _snap_to_fn="${_ref_date}${opt_suffix}.1.after-restoration-is-equals-to-$1"
    _snap_to="$SAVEPOINTS_DIR/$_snap_to_fn"
    if [ -e "$_snap_to" ]; then
        log "[$NAME] ERR the savepoint '%s' already exists ! (bug ?)" "$_snap_to"
        "$fun_fatal_error" "$(__ "the savepoint '%s' already exists ! (bug ?)" "$_snap_to")"
    fi

    # creating a new read-only snapshot from the current subvolume (restored)
    # and add it to the list of savepoints (renamed)
    debug "   creating a savepoint (snapshot ro) '%s' from subvolume '%s'" "$_snap_to_fn" "$_subvol_path"
    if ! btrfs subvolume snapshot -r "$_subvol_path" "$_snap_to" >/dev/null; then
        log "[$NAME] ERR failed to create snapshot (ro) from '%s' to '%s'" "$_subvol_path" "$_snap_to"
        "$fun_fatal_error" "$(__ "failed to create snapshot (ro) from '%s' to '%s'" "$_subvol_path" "$_snap_to")"
    fi

    log "[$NAME] + %s <== %s" "$_snap_to_fn" "$_subvol_path"

    debug "   restoration complete"

    # trigger hook after restoration
    _hook="$(get_opt_or_var_value 'HOOK_AFTER_RESTORE')"
    if [ "$_hook" ]; then
        _hook="$_hook '$_subvol_path' '$_sp_from'"
        debug "${_ind}triggering the hook command '%s'" "$_hook"
        if ! sh -c "$_hook"; then
            log "[$NAME] ERR %s hook '%s' failed" 'after' "$_hook"
            "$fun_fatal_error" "the hook command '%s' has failed" "$_hook"
        fi
    fi

    # pruning savepoints
    prune_savepoints "$_snap_to_fn"
}

# delete a savepoint
#
# @param  ..  string  names of savepoints to delete
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $SAVEPOINTS_DIR      string  path of the savepoints directory (for the current configuration)
# @env  $opt_force_deletion   bool   if 'true' force the deletion of the savepoint (see remove_savepoint())
#
cmd_delete()
{

    # for each savepoint's name specified
    for _sp_fn in "$@"; do

        # delete the savepoint
        _sp_path="$SAVEPOINTS_DIR/$_sp_fn"
        if [ ! -e "$_sp_path" ]; then
            "$fun_warning" "$(__ "savepoint '%s' doesn't exist" "$_sp_path")"
        else
            debug "   removing savepoint '%s'" "$_sp_path"
            log "[$NAME] CMD delete '%s'%s" "$_sp_fn" \
                "$(if bool "$opt_force_deletion"; then echo ' (--force-deletion)'; fi)"
            _ind='      '
            remove_savepoint "$_sp_path" "$opt_force_deletion"
        fi
    done
}

# create a new configuration for a subvolume
#
# @param  $1  string  name of the configuration
# @param  $2  string  path of the subvolume when mounted
# @param  $3  string  path of the subvolume relative to BTRFS top level subvolume mount point (id:5)
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $CONFIGS_DIR          string  path of the configurations directory
# @env  $THIS_SCRIPT_NAME     string  name of this script (without extension)
# @env  $CURRENT_DATE_TEXT    string  current date
# @env  $opt_no_defaults_copy  bool   if 'true' do not copy the current default variables
#
cmd_add_conf()
{
    _name="$1"
    _subv_path="$2"
    _subv_rel_path="$3"

    debug "Adding configuration '%s' for the subvolume '%s' (%s)" \
        "$_name" "$_subv_path" "$_subv_rel_path"

    if ! is_conf_name_valid "$_name"; then
        "$fun_fatal_error" "$(__ "invalid configuration's name '%s'" "$_name")"
    fi

    _conf_path="$CONFIGS_DIR/${_name}.conf"

    if [ -e "$_conf_path" ]; then
        "$fun_fatal_error" "$(__ "configuration file '%s' already exists" "$_conf_path")"
    fi
    if [ "$_subv_path" = '' ]; then
        "$fun_fatal_error" "$(__ "argument '%s' is not defined" "$(__ 'MOUNTED_PATH')")"
    fi
    if [ "$_subv_rel_path" = '' ]; then
        "$fun_fatal_error" "$(__ "argument '%s' is not defined" "$(__ 'SUBVOL_PATH')")"
    fi
    if [ ! -d "$_subv_path" ]; then
        "$fun_fatal_error" "$(__ "path '%s' is not a folder" "$_subv_path")"
    fi
    if ! is_btrfs_subvolume "$_subv_path"; then
        "$fun_fatal_error" "$(__ "folder '%s' is not a BTRFS subvolume" "$_subv_path")"
    fi

    debug "Creating configuration file '%s'" "$_conf_path"
    cat > "$_conf_path" <<ENDCAT
# configuration file for $THIS_SCRIPT_NAME, subvolume '$_name'

# subvolume path when mounted
SUBVOLUME='$_subv_path'

# subvolume path relative to btrfs top level mount point (id:5)
SUBVOLUME_FROM_TOPLEVEL_SUBVOL='$_subv_rel_path'

ENDCAT
    _default_values_txt=
    if ! bool "$opt_no_defaults_copy"; then
        debug "Copying current defaults values to it"
        echo "# copied current ($CURRENT_DATE_TEXT) defaults values" >> "$_conf_path"
        for var in \
            BACKUP_BOOT BACKUP_REBOOT BACKUP_SHUTDOWN BACKUP_HALT BACKUP_SUSPEND BACKUP_RESUME br \
            SUFFIX_BOOT SUFFIX_REBOOT SUFFIX_SHUTDOWN SUFFIX_HALT SUFFIX_SUSPEND SUFFIX_RESUME br \
            SAFE_BACKUP br \
            KEEP_NB_SESSIONS KEEP_NB_MINUTES KEEP_NB_HOURS KEEP_NB_DAYS KEEP_NB_WEEKS \
            KEEP_NB_MONTHS KEEP_NB_YEARS br \
            DIFF_IGNORE_PATTERNS br \
            HOOK_BEFORE_BACKUP HOOK_AFTER_BACKUP HOOK_BEFORE_RESTORE HOOK_AFTER_RESTORE br\
            NO_PURGE_DIFF NO_PURGE_NUMBER
        do
            if [ "$var" = 'br' ]; then
                echo >> "$_conf_path"
            else
                echo "$var='$(get_opt_or_var_value "$var")'" >> "$_conf_path"
            fi
        done
        _default_values_txt=" ($(__ "with default values"))"
    fi
    __ "Configuration '%s' created to '%s'%s" "$_name" "$_conf_path" "$_default_values_txt"
}

# list each savepoint configured
# TODO implement informations options
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $SAVEPOINTS_DIR  string  path of the savepoints directory (for the current configuration)
#
cmd_list_conf()
{
    _retention_text=
    for _unit in SESSION MINUTE HOUR DAY WEEK MONTH YEAR; do
        _retention_value="$(get_opt_or_var_value "KEEP_NB_${_unit}S")"
        [ "$_retention_value" != '' ] || _retention_value=0
        _unit_translated=
        case "$_unit" in
            SESSION) _unit_translated="$(__ 'SESSION')" ;;
            MINUTE)  _unit_translated="$(__ 'MINUTE')"  ;;
            HOUR)    _unit_translated="$(__ 'HOUR')"    ;;
            DAY)     _unit_translated="$(__ 'DAY')"     ;;
            WEEK)    _unit_translated="$(__ 'WEEK')"    ;;
            MONTH)   _unit_translated="$(__ 'MONTH')"   ;;
            YEAR)    _unit_translated="$(__ 'YEAR')"    ;;
        esac
        _retention_text="$_retention_text, "`
                        `"$_retention_value $(echo "$_unit_translated" | cut -c -3)"
    done
    _retention_text="$(echo "$_retention_text" | sed 's/^, *//g')"

    # define the subvolume path to use
    _subvol_ref="$SUBVOLUME"
    if [ "$opt_from_toplevel_subvol" != '' ] && [ "$SUBVOLUME_FROM_TOPLEVEL_SUBVOL" != '' ]; then
        _subvol_ref="$(path_join "$opt_from_toplevel_subvol" "$SUBVOLUME_FROM_TOPLEVEL_SUBVOL")"
    fi

    # format for the GUI
    if bool "$opt_format_gui"; then

        # display the config name, the subvolume and the retention strategy
        # and replace spaces by 'non-truncable' spaces
        echo "$NAME "`
             `"$(echo "$NAME: $_subvol_ref  <<<  $SAVEPOINTS_DIR  "`
             `"($(__ 'Retention'): $_retention_text)" \
                | sed 's/ / /g')"

    # standard output
    else

        # display the config name, the subvolume, the savepoints dir, and the retention strategy
        echo "$NAME: $_subvol_ref ==> $SAVEPOINTS_DIR ($_retention_text)"
    fi
}

# list the savepoints for a configuration
# TODO implement informations options
# TODO implement sorting options
# TODO implement filters options
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $SAVEPOINTS_DIR  string  path of the savepoints directory (for the current configuration)
# @env  $_is_last_config  bool   if 'true' means that we are listing the last config of the list
#
cmd_list()
{
    _indent=
    _line_break=false

    # if the configuration has not been specified
    if [ "$opt_config" = '' ]; then

        # print the name of the current config
        echo "$NAME"

        # and use indentation for savepoints
        _indent='   '

        # and if not the last config, use a line break after listing
        if ! bool "$_is_last_config"; then
            _line_break=true
        fi
    fi
    _ind="$_indent"

    # detect if we can do diffs between subvolumes
    _can_diff=false
    if [ "$BTRFS_DIFF_BIN" != '' ] && [ -x "$BTRFS_DIFF_BIN" ]; then
        _can_diff=true
        debug "${_ind}can do diff"
    fi

    # if the savepoints directory exists
    if [ -d "$SAVEPOINTS_DIR" ]; then
        _sp_prev=

        # get the list of backups, orderred by numbers (oldest first)
        _sp_list="$(find "$SAVEPOINTS_DIR" -maxdepth 1 \( -type d -o -type l \) \
                         -not -path "$SAVEPOINTS_DIR" | sort -rn)"

        # if the format is GUI and we can do diff and the list have more than one item
        if bool "$opt_format_gui" && bool "$_can_diff" && \
            [ "$(count_list "$_sp_list")" -gt 1 ]
        then
            debug "${_ind}the format is GUI and we can do diff and the list have more than one item"

            # get pop one item from the list, because the list is using the previous item to print
            _sp_prev="$(echo "$_sp_list" | head -n 1)"
            debug "${_ind}poped out item '%s' which will be the 'first previous one'" \
                "$(basename "$_sp_prev")"
            _sp_list="$(echo "$_sp_list" | tail -n +2)"
        fi

        # for each savepoints
        _sp_last="$(echo "$_sp_list" | tail -n 1)"
        IFS='
'
        for _sp_cur in $_sp_list; do
            IFS="$IFS_BAK"
            _sp_cur_name="$(basename "$_sp_cur")"
            _sp_prev_name="$(basename "$_sp_prev")"
            debug "${_ind} - %s (< %s)" "$_sp_cur_name" "$_sp_prev_name"
            _ind="$_indent   "

            # format for the GUI
            if bool "$opt_format_gui"; then
                debug "${_ind}format for the GUI"

                # we can do diffs between subvolumes, and the previous savepoint is not empty
                if bool "$_can_diff" && [ "$_sp_prev" != '' ]; then
                    debug "${_ind}can do diffs between subvolumes, and the previous savepoint is not empty"

                    # if the previous savepoint is a link
                    if [ -L "$_sp_prev" ]; then
                        debug "${_ind}previous savepoint is a link"
                        echo "${_indent}$_sp_prev_name         v        $_sp_prev_name"

                    # not a link
                    else
                        # get the amount of changes for that savepoint with the previous one
                        _ret=0
                        _sp_changes="$(btrfs_subvolumes_diff_short "$_sp_cur" "$_sp_prev")" || \
                            _ret="$?"
                        if [ "$_ret" -le 1 ]; then
                            debug "${_ind}got changes: '%s'" "$_sp_changes"
                            echo "${_indent}$_sp_prev_name "`
                                `"   $(echo "$_sp_changes" | sed 's/ / /g')   $_sp_prev_name"
                        else
                            debug "${_ind}issue"
                            echo "${_indent}$_sp_prev_name        ???       $_sp_prev_name"
                        fi
                    fi

                    # this is the last savepoint of the list
                    if [ "$_sp_cur" = "$_sp_last" ]; then
                        debug "${_ind}last savepoint"
                        if [ -L "$_sp_cur" ]; then
                            echo "${_indent}$_sp_cur_name         v        $_sp_cur_name"
                        else
                            echo "${_indent}$_sp_prev_name    ... ... ...   $_sp_prev_name"
                        fi
                    fi

                # can't do changes
                else
                    debug "${_ind}can't do changes"
                    _is_link="$(if [ -L "$_sp_cur" ]; then echo 'v'; else echo ' '; fi)"
                    echo "${_indent}$_sp_cur_name    $_is_link   $_sp_cur_name"
                fi

            # standard output
            else
                echo "${_indent}$_sp_cur_name"
            fi

            _sp_prev="$_sp_cur"
        done
    fi

    # line break ?
    if bool "$_line_break"; then
        echo
    fi
}

# get differences between two savepoints
#
# @param  $1  string  path to the reference savepoint
# @param  $2  string  path to the compared savepoint
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $opt_no_ignore_patterns  bool  option to ignore configured patterns
#
cmd_diff()
{
    debug ''

    # subvolumes are different or there whould (obviously) have no diff
    [ "$1" != "$2" ] || return 0

    if [ "$BTRFS_DIFF_BIN" = '' ] || [ ! -x "$BTRFS_DIFF_BIN" ]; then
        "$fun_fatal_error" "$(__ "Cannot produce a diff without '%s' binary (%s)" \
            'btrfs-diff' "$BTRFS_DIFF_BIN")"
    fi
    for _sp in "$1" "$2"; do
        if [ ! -e "$SAVEPOINTS_DIR/$_sp" ]; then
            "$fun_fatal_error" "The savepoint '%s' doesn't exist" "$_sp"
        fi
        if ! is_btrfs_subvolume "$SAVEPOINTS_DIR/$_sp"; then
            "$fun_fatal_error" "The path '%s' is not a subvolume" "$_sp"
        fi
    done

    _sp_ref="$(realpath "$SAVEPOINTS_DIR/$1")"
    _sp_cmp="$(realpath "$SAVEPOINTS_DIR/$2")"

    _ignore_patterns_opt="$(bool "$opt_no_ignore_patterns" || echo 'true')"

    _ret=0
    btrfs_subvolume_diff_extern "$_sp_ref" "$_sp_cmp" "$_ignore_patterns_opt" || _ret="$?"
    return "$_ret"
}

# get differences between the subvolume and the specified savepoint
#
# @param  $1  string  path to the savepoint
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $opt_no_ignore_patterns  bool  option to ignore configured patterns
#
cmd_subvol_diff()
{
    debug ''
    if [ "$BTRFS_DIFF_BIN" = '' ] || [ ! -x "$BTRFS_DIFF_BIN" ]; then
        "$fun_fatal_error" "$(__ "Cannot produce a diff without '%s' binary (%s)" \
            'btrfs-diff' "$BTRFS_DIFF_BIN")"
    fi
    if [ ! -e "$SAVEPOINTS_DIR/$1" ]; then
        "$fun_fatal_error" "The savepoint '%s' doesn't exist" "$1"
    fi
    if ! is_btrfs_subvolume "$SAVEPOINTS_DIR/$1"; then
        "$fun_fatal_error" "The path '%s' is not a subvolume" "$1"
    fi

    # define the subvolume path to use
    _subvol_ref="$SUBVOLUME"
    if [ "$opt_from_toplevel_subvol" != '' ] && [ "$SUBVOLUME_FROM_TOPLEVEL_SUBVOL" != '' ]; then
        _subvol_ref="$(path_join "$opt_from_toplevel_subvol" "$SUBVOLUME_FROM_TOPLEVEL_SUBVOL")"
    fi
    debug "${_ind}Will use the subvolume '%s'" "$_subvol_ref"

    # create a snapshot of the current folder
    _temp_snap_dir="$(mktemp -d "$(dirname "$SAVEPOINTS_DIR")/.$NAME.to_diff.XXXXXX")"
    _temp_snap_path="$_temp_snap_dir/$NAME"
    debug "${_ind}Temporary snapshot path will be '%s'" "$_temp_snap_path"

    debug "${_ind}Creating a snapshot of the subvolume '%s' to '%s' ..." \
        "$_subvol_ref" "$_temp_snap_path"
    if ! btrfs subvolume snapshot -r "$_subvol_ref" "$_temp_snap_path" >/dev/null; then
        "$fun_fatal_error" "$(__ "Failed to create snapshot (ro) from '%s' to '%s'" \
            "$_subvol_ref" "$_temp_snap_path")"
    fi
    debug "${_ind}Temporary snapshot created"

    _sp_cmp="$(realpath "$SAVEPOINTS_DIR/$1")"

    # do the diff
    _ignore_patterns_opt="$(bool "$opt_no_ignore_patterns" || echo 'true')"
    _ret=0
    btrfs_subvolume_diff_extern "$_temp_snap_path" "$_sp_cmp" "$_ignore_patterns_opt" || _ret="$?"

    # removing the temporary snapshot
    if [ -e "$_temp_snap_path" ]; then
        debug "${_ind}Removing the temporary snapshot '%s'" "$_temp_snap_path"
        btrfs subvolume delete --commit-after "$_temp_snap_path" >/dev/null || true
    fi
    [ ! -d "$_temp_snap_dir" ] || rmdir "$_temp_snap_dir"

    debug "${_ind}Return code is '%d'" "$_ret"
    return "$_ret"
}

# prune the savepoints (by diff or by number)
# @param  $1  bool  If 'diff', use the purge-diff algorithm,
#                   if 'number', use the number one,
#                   and if 'both', use both.
# same requirements as the functions purge_diff() and/or purge_number()
cmd_prune()
{
    if [ "$1" = '' ]; then
        log "[$NAME] CMD prune"
    fi
    if [ "$1" = 'diff' ] || [ "$1" = 'both' ]; then
        debug "   remove snapshot that have no differences and replace them by a symlink"
        purge_diff
    fi

    if [ "$1" = 'number' ] || [ "$1" = 'both' ]; then
        debug "   remove older backups to respect the maximum number allowed"
        if bool "$(get_opt_or_var_value 'purge_number_no_session')"; then
            purge_number_no_session
        else
            purge_number
        fi
    fi
}

# prune the savepoints (by diff)
# same requirements as the function cmd_prune()
cmd_purge_diff()
{
    log "[$NAME] CMD purge-diff"
    cmd_prune 'diff'
}

# prune the savepoints (by number)
# same requirements as the function cmd_prune()
cmd_purge_number()
{
    log "[$NAME] CMD purge-number"
    cmd_prune 'number'
}

# read the persistent log
#
# uses the following outside-defined variables
# @env  $PERSISTENT_LOG  string  path of the log file
#
cmd_log_read()
{
    cat "$PERSISTENT_LOG"
}

# write to the persistent log
#
# @param  $1  string  the line to write
#
cmd_log_write()
{
    log "$(echo "$1" | head -n 1)"
}

# return 0 if the configuration's name is valid
is_conf_name_valid()
{
    echo "$1" | grep -q '^[a-zA-Z0-9_@.-]\+$'
}

# get the list of configurations
#
# uses the following outside-defined variables
# @env  $CONFIGS_DIR  string  path of the configurations directory
#
get_config_list()
{
    find "$CONFIGS_DIR" -maxdepth 1 -type f -name '*.conf'
}

# get the value for an option, a savepoint variable, or a default variable
# according to that order priority
# @param  $1  string  the option's name
# @param  $2  string  (optional) the variable's name
#                     if not specifed, the option's name in uppercase will be used
get_opt_or_var_value()
{
    _var_name="opt_$1"
    eval "_var_value=\$$_var_name"
    # shellcheck disable=SC2154
    if [ "$_var_value" = '' ]; then
        _var_name="$(upper "$1")"
        if [ "$2" != '' ]; then
            _var_name="$2"
        fi
        eval "_var_value=\$$_var_name"
        if [ "$_var_value" = '' ]; then
            _var_name="SP_DEFAULT_$_var_name"
            eval "_var_value=\$$_var_name"
        fi
    fi
    echo "$_var_value"
}

# return 0 if the value specified match a boolean TRUE value
# (i.e.: yes|y|true|t|1|on - case insensitive)
bool()
{
    echo "$1" | grep -q -i '^\(yes\|y\|true\|t\|1\|on\)$'
}

# convert from lowercase to uppercase
upper()
{
    # Note: 'tr' with compatibility with the one in busybox
    # shellcheck disable=SC2021
    echo "$1" | tr '[a-z]' '[A-Z]'
}

# concatenate two path components and ensure there is no double '/' in it
# @param  $1  string  first path component
# @param  $2  string  second path component
path_join()
{
    if [ "$1" = '' ] && [ "$2" = '' ]; then
        true
    else
        echo "$1/$2" | sed 's|//*|/|g'
    fi
}

# return 0 if there is no differences between subvolumes, 1 else
#
# @param  $1  string  path to btrfs subvolume reference
# @param  $2  string  path to btrfs subvolume compared
#
# uses the following outside-defined variables
# @env  $BTRFS_DIFF_BIN  string  path to binary analysing the differences between btrfs subvolumes
#
btrfs_subvolumes_diff()
{
    # TODO implement ignoring some differences when they match DIFF_IGNORE_PATTERNS

    _ref="$(realpath "$1")"
    _cmp="$(realpath "$2")"
    debug "${_ind}analysing changes between '%s' and '%s'" "$_ref" "$_cmp"

    # subvolumes are different or there whould (obviously) have no diff
    [ "$_ref" != "$_cmp" ] || return 0

    # if an external tool is specified, use it
    if [ "$BTRFS_DIFF_BIN" != '' ] && [ -x "$BTRFS_DIFF_BIN" ]; then

        # run the external tool to analyze differences (and ignore configured patterns)
        _ret=0
        btrfs_subvolume_diff_extern "$_ref" "$_cmp" 'true' || _ret="$?"
        return "$_ret"

    # if no external tools are specified: do our own diff process (kind of a hack)
    else

        # need a temp file
        _tmp_file_send="$(mktemp)"

        # exporting the changes like we will send it somewhere
        if ! btrfs send --quiet --no-data -p "$_ref" "$_cmp" -f "$_tmp_file_send"; then
            rm -f "$_tmp_file_send"
            "$fun_fatal_error" "$(__ "failed to compare btrfs subvolumes '%s' to '%s' "`
                              `"('btrfs send' command has failed)" "$_ref" "$_cmp")"
        fi

        # need another temp file
        _tmp_file_receive="$(mktemp)"

        # receive the changes and dump them (instead of applying them)
        if ! btrfs receive --quiet --dump > "$_tmp_file_receive" < "$_tmp_file_send"; then
            rm -f "$_tmp_file_send" "$_tmp_file_receive"
            "$fun_fatal_error" "$(__ "failed to compare btrfs subvolumes '%s' to '%s' "`
                              `"('btrfs receive' command has failed)" "$_ref" "$_cmp")"
        fi
        rm -f "$_tmp_file_send"

        # if there is no differences between snapshots
        # there will only have one line in the dump
        # containing the snapshot informations (uuid, parent, etc.)
        _found_diff=false
        if ! head -n 1 "$_tmp_file_receive" | \
                grep -q "^snapshot \\+\\./$(basename "$_cmp") \\+uuid=[^ ]\\+ \\+transid=[^ ]\\+ \\+"`
                        `"parent_uuid=[^ ]\\+ \\+parent_transid=[^ ]\\+\$" \
                || [ "$(grep -c -v '^utimes' "$_tmp_file_receive" || true)" -gt 1 ]
        then
            #debug "          found differences between subvolumes '%s' and '%s'" "$_ref" "$_cmp"
            _found_diff=true
        fi

        # cleanup and return
        rm -f "$_tmp_file_receive"
        [ "$_found_diff" = 'false' ]
    fi
}

# get differences between two BTRFS snapshots
#
# @param  $1  string  path to the reference snapshot
# @param  $2  string  path to the compared snapshot
# @param  $3  bool    if 'true' it will ignore differences based on configured patterns
#
btrfs_subvolume_diff_extern()
{
    # subvolumes are different or there whould (obviously) have no diff
    [ "$1" != "$2" ] || return 0

    if [ "$BTRFS_DIFF_BIN" = '' ] || [ ! -x "$BTRFS_DIFF_BIN" ]; then
        "$fun_fatal_error" "$(__ "Cannot produce a diff without '%s' binary (%s)" \
            'btrfs-diff' "$BTRFS_DIFF_BIN")"
    fi
    for _sp in "$1" "$2"; do
        if [ ! -e "$_sp" ]; then
            "$fun_fatal_error" "$(__ "The BTRFS subvolume '%s' doesn't exist")" "$_sp"
        fi
        if ! is_btrfs_subvolume "$_sp"; then
            "$fun_fatal_error" "$("The path '%s' is not a subvolume")" "$_sp"
        fi
    done

    _sp_ref="$(realpath "$1")"
    _sp_cmp="$(realpath "$2")"

    debug "${_ind}Get the differences with: '%s' '%s' '%s'" "$BTRFS_DIFF_BIN" "$_sp_ref" "$_sp_cmp"
    _ret=0
    _out_tmp="$(mktemp)"
    "$BTRFS_DIFF_BIN" "$_sp_ref" "$_sp_cmp" > "$_out_tmp" || _ret="$?"
    debug "${_ind}Diff return code is '%d'" "$_ret"
    if [ "$_ret" -gt 1 ]; then
        rm -f "$_out_tmp"
        "$fun_fatal_error" \
        "$(__ "There was an error when producing the diff between BTRFS subvolumes '%s' and '%s'" \
              "$_sp_ref" "$_sp_cmp")"
    elif [ "$_ret" -eq 1 ]; then
        _diff_ign_pattern="$(get_opt_or_var_value 'DIFF_IGNORE_PATTERNS')"
        if bool "$3" && [ "$_diff_ign_pattern" != '' ]; then
            debug "${_ind}Ignoring patterns: '%s'" "$_diff_ign_pattern"
            grep -v "$_diff_ign_pattern" "$_out_tmp" || _ret=0
            debug "${_ind}After ignoring patterns return code is '%d'" "$_ret"
        else
            cat "$_out_tmp"
        fi
    fi
    rm -f "$_out_tmp"

    debug "${_ind}Return code is '%d'" "$_ret"
    return "$_ret"
}

# print out the differences between subvolumes, in a short format
# the format is the following: --- +++ ***
# where :
#   - minus sign represents deletions
#   + plus sign reprents additions
#   * multiply sign reprents modifications
# the more the signs, the more operations are (exponential)
# thresholds are the following :
#       no sign :  0        operation
#      one sign :  1 to 10  operations
#     two signs : 11 to 50  operations
#   three signs : 51+       operations
#
btrfs_subvolumes_diff_short()
{
    # do the normal diff
    _ret=0
    _diff_out="$(btrfs_subvolumes_diff "$1" "$2")" || _ret="$?"
    debug "${_ind}got diff:"
    debug '%s' "$(echo "$_diff_out" | sed "s/^/${_ind}/")"
    if [ "$_ret" -le 1 ]; then

        # transform the differences into the short format
        # (ignoring renames)
        _del_count="$(echo "$_diff_out" | grep -c "^ *$(__ 'added')" || true)"
        _add_count="$(echo "$_diff_out" | grep -c "^ *$(__ 'deleted')" || true)"
        _mod_count="$(echo "$_diff_out" | grep -c "^ *$(__ 'changed')" || true)"
        debug "${_ind}diff: - %d, + %d, * %d" "$_del_count" "$_add_count" "$_mod_count"
        _out=
        if [ "$_del_count" -ge  1 ]; then _out="${_out}-"; else _out="${_out}."; fi
        if [ "$_del_count" -gt 10 ]; then _out="${_out}-"; else _out="${_out}."; fi
        if [ "$_del_count" -gt 50 ]; then _out="${_out}-"; else _out="${_out}."; fi
        _out="${_out} "
        if [ "$_add_count" -ge  1 ]; then _out="${_out}+"; else _out="${_out}."; fi
        if [ "$_add_count" -gt 10 ]; then _out="${_out}+"; else _out="${_out}."; fi
        if [ "$_add_count" -gt 50 ]; then _out="${_out}+"; else _out="${_out}."; fi
        _out="${_out} "
        if [ "$_mod_count" -ge  1 ]; then _out="${_out}*"; else _out="${_out}."; fi
        if [ "$_mod_count" -gt 10 ]; then _out="${_out}*"; else _out="${_out}."; fi
        if [ "$_mod_count" -gt 50 ]; then _out="${_out}*"; else _out="${_out}."; fi
        echo "$_out"
    fi
    return "$_ret"
}

# do the pruning
#
# @param  $1  string  (optional)  name of a savepoint that stop the purge-diff process when reached
#
prune_savepoints()
{
    # remove the new snapshot and replace it by a symlink if there is no diff
    if ! bool "$(get_opt_or_var_value 'no_purge_diff')"; then
        debug "   remove the new snapshot and replace it by a symlink if there is no diff"
        purge_diff "$1" || "$fun_warning" "$(\
            __ "pruning savepoints using '%s' algorithm has failed" 'purge-diff')"
    fi

    # remove older backups to respect the maximum number allowed
    if ! bool "$(get_opt_or_var_value 'no_purge_number')"; then
        debug "   remove older backups to respect the maximum number allowed"
        if bool "$(get_opt_or_var_value 'purge_number_no_session')"; then
            purge_number_no_session || "$fun_warning" "$(\
            __ "pruning savepoints using '%s' algorithm has failed" 'purge-number-no-session')"
        else
            purge_number || "$fun_warning" "$(\
            __ "pruning savepoints using '%s' algorithm has failed" 'purge-number')"
        fi
    fi
}

# purge backups by removing those who makes no differences
#
# @param  $1  string  (optional)  name of a savepoint that stop the process when reached
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $IFS_BAK             string  backup value of the initial shell IFS
# @env  $SAVEPOINTS_DIR  string  path of the savepoints directory (for the current configuration)
#
# and indirectly all the required variables of the functions: btrfs_subvolumes_diff()
#
purge_diff()
{
    _ind='      '
    _stop_at_sp="$1"

    # if the savepoints directory doesn't exist, return
    [ -d "$SAVEPOINTS_DIR" ] || return 0

    # get the list of backups, orderred by numbers reversed (most recent first)
    _sp_list="$(find "$SAVEPOINTS_DIR" -maxdepth 1 -type d -not -path "$SAVEPOINTS_DIR" | sort -nr || true)"
    if [ "$_sp_list" = '' ]; then
        "$fun_fatal_error" "$(__ "failed to get the list of backups for directory '%s'" \
            "$SAVEPOINTS_DIR")"
    fi

    # count the items in the list
    _sp_count="$(count_list "$_sp_list")"

    debug "${_ind}list of %d backups (excluding symlinks)" "$_sp_count"
    debug '%s' "$(echo "$_sp_list" | sed -e 's/^/         /g' -e "s|$SAVEPOINTS_DIR/||g")"

    # if the list has more than one item
    if [ "$_sp_count" -gt 1 ]; then
        log "[$NAME] ALG purge-diff"

        # for each backup
        debug "${_ind}looping over each savepoint:"
        _newer_sp=
        _stop_next=false
        IFS='
'
        for _cur_sp in $_sp_list; do
            IFS="$IFS_BAK"
            _cur_sp_fn="$(basename "$_cur_sp")"

            debug "${_ind}- %s" "$_cur_sp_fn"
            _ind='          '

            # if we don't have any newer backup, we just skip to an older one
            # saving the current one as the newest
            if [ "$_newer_sp" = '' ]; then
                debug "${_ind}no newer backup, using this one"
                _newer_sp="$_cur_sp"

            # here we have a new backup and the current one is older
            else
                _newer_sp_fn="$(basename "$_newer_sp")"
                debug "${_ind}newer backup is: %s" "$_newer_sp_fn"

                # if there is no difference between the newer and current savepoints
                debug "${_ind}comparing '%s' and '%s' for differences" "$_cur_sp_fn" "$_newer_sp_fn"
                if btrfs_subvolumes_diff "$_cur_sp" "$_newer_sp" >/dev/null; then
                    debug "${_ind}no differences found"

                    # remove the newer backup
                    debug "${_ind}removing the new snapshot"
                    _ind='             '
                    if ! remove_savepoint "$_newer_sp"; then
                        "$fun_fatal_error" "$(__ "failed to delete new snapshot '%s'" "$_newer_sp")"
                    fi
                    _ind='          '

                    # convert it to a symlink
                    ln -s "$_cur_sp_fn" "$_newer_sp"
                    debug "${_ind}converted to a symlink to '%s'" "$_cur_sp_fn"

                    log "[$NAME] = %s -> %s" "$_newer_sp_fn" "$_cur_sp_fn"
                fi
            fi

            # if need to stop
            if bool "$_stop_next"; then
                debug "${_ind}stoping (as requested)"
                break

            # if we have reached the limit specified, stop the purge at then next item
            elif [ "$_stop_at_sp" = "$_cur_sp_fn" ]; then
                debug "${_ind}reached the specified limit savepoint '%s'. Stoping at next savepoint" \
                    "$_stop_at_sp"
                _stop_next=true
            fi
        done
    fi
}

# purge backups by removing enough to respect the maximum number allowed
#
# SESSION: between BOOT/RESUME and one of REBOOT/SHUTDOWN/HALT/SUSPEND
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $IFS_BAK          string  backup value of the initial shell IFS
# @env  $SAVEPOINTS_DIR   string  path of the savepoints directory (for the current configuration)
# @evn  KEEP_NB_SESSIONS    int   number fo sessions to keep (for the current configuration)
# @env  $opt_now          string  a datetime to indicate when is now
#
# and indirectly all the required variables of the functions: remove_savepoint() and purge_safe_savepoint()
#
purge_number()
{
    _ind='      '
    # if the savepoints directory doesn't exist, return
    [ -d "$SAVEPOINTS_DIR" ] || return 0

    # get the list of backups, orderred by numbers reversed (most recent first)
    _sp_list="$(\
        find "$SAVEPOINTS_DIR" -maxdepth 1 \( -type d -o -type l \) -not -path "$SAVEPOINTS_DIR" \
        | sort -nr || true)"
    if [ "$_sp_list" = '' ]; then
        "$fun_fatal_error" "$(__ "failed to get the list of backups for directory '%s'" \
            "$SAVEPOINTS_DIR")"
    fi

    debug "${_ind}list of %d backups (including symlinks)" "$(count_list "$_sp_list")"
    debug '%s' "$(echo "$_sp_list" | sed -e "s/^/${_ind}   /g" -e "s|$SAVEPOINTS_DIR/||g")"

    # how many sessions to keep
    _keep_sessions="$(get_opt_or_var_value "KEEP_NB_SESSIONS")"

    # store number of sessions found
    _count_sessions=0

    # store how many times a unit of time was changed
    # shellcheck disable=SC2034
    _count_changed_years=0
    # shellcheck disable=SC2034
    _count_changed_months=0
    # shellcheck disable=SC2034
    _count_changed_weeks=0
    # shellcheck disable=SC2034
    _count_changed_days=0
    # shellcheck disable=SC2034
    _count_changed_hours=0
    # shellcheck disable=SC2034
    _count_changed_minutes=0

    # current timestamp
    _cur_ts="$(date '+%s')"
    if [ "$opt_now" != '' ]; then
        _cur_ts="$(date -d "$opt_now" '+%s')"
    fi
    debug "${_ind}current ts: %s (%d)" "$(get_date_to_std "@$_cur_ts")" "$_cur_ts"

    # previous unit of time
    # shellcheck disable=SC2034
    _prev_sp_year=
    # shellcheck disable=SC2034
    _prev_sp_month=
    # shellcheck disable=SC2034
    _prev_sp_week=
    # shellcheck disable=SC2034
    _prev_sp_day=
    # shellcheck disable=SC2034
    _prev_sp_hours=
    # shellcheck disable=SC2034
    _prev_sp_minutes=

    log "[$NAME] ALG purge-number"

    # for each savepoint
    debug "${_ind}looping over each savepoint:"
    _first_sp=yes
    _last_sp="$(echo "$_sp_list" | tail -n 1)"
    _prev_sp=
    _in_a_session=no
    IFS='
'
    for _cur_sp in $_sp_list; do
        IFS="$IFS_BAK"
        _ind='      '

        # is it a real snapshot or a symlink
        _ts_type="$(if [ -L "$_cur_sp" ]; then echo 'link'; else echo 'snap'; fi)"

        debug "${_ind}- %s%s" "$(basename "$_cur_sp")" \
            "$(if [ "$_ts_type" = 'link' ]; then echo " (link)"; fi)"

        _ind='         '

        #  SESSION: between BOOT/RESUME and one of REBOOT/SHUTDOWN/HALT/SUSPEND

        # we were in a session
        if bool "$_in_a_session"; then
            debug "${_ind}in a session"

            # the current savepoint is the begining of a session (boot/resume)
            # or is the end of a session (reboot/shutdown/halt/suspend)
            if is_session_begining "$_cur_sp" || is_session_end "$_cur_sp"; then
                _state="$(if is_session_begining "$_cur_sp"; then echo 'begining'; else echo 'end'; fi)"
                debug "${_ind}savepoint is the $_state of a session"

                # stop the session flag
                _in_a_session=no
                debug "${_ind}stoped session"

                # increase the number of session
                _count_sessions="$((_count_sessions + 1))"
                debug "${_ind}session count is now: %d" "$_count_sessions"

                # if is is the end of a session, and if the maximum number of session is not yet reached
                if is_session_end "$_cur_sp" && [ "$_count_sessions" -lt "$_keep_sessions" ]; then

                    # start a new session
                    _in_a_session=yes
                    debug "${_ind}enf of a (new) session"
                fi

            # in a middle of a session : keep the savepoint
            else
                debug "${_ind}savepoint inside a session"
            fi

        # not in a session
        else
            debug "${_ind}not in a session"

            # if the maximum number of session is reached
            if [ "$_count_sessions" -ge "$_keep_sessions" ]; then
                debug "${_ind}maximum of sessions reached ($_count_sessions >= $_keep_sessions)"

                # the savepoint is not a safe one
                if ! is_safe_savepoint "$_cur_sp"; then
                    debug "${_ind}not a safe savepoint"

                    # remove the backup
                    debug "${_ind}removing savepoint '%s'" "$_cur_sp"
                    _ind='            '
                    remove_savepoint "$_cur_sp"
                    _ind='         '

                # safe savepoint
                else
                    debug "${_ind}safe savepoint"

                    # process the safe savepoint (may or may not be purged)
                    debug "${_ind}purging safe savepoint '%s' (may or may not be removed)" "$_cur_sp"
                    purge_safe_savepoint "$_cur_sp" \
                        "$(if [ "$_cur_sp" = "$_last_sp" ]; then echo 'true'; fi)"
                fi

            # not yet the maximum sessions
            else

                # not the beging of a session (end or middle)
                if ! is_session_begining "$_cur_sp"; then
                    _in_a_session=yes
                    _state="$(if is_session_end "$_cur_sp"; then echo 'end'; else echo 'middle'; fi)"
                    _crash="$(if ! is_session_end "$_cur_sp"; then echo ' (crash ?)'; fi)"
                    debug "${_ind}${_state}$_crash of a (new) session"

                # begining of a new session
                else

                    # if this the first savepoint
                    if bool "$_first_sp"; then
                        debug "${_ind}begining of a (new) session"

                    # not the first savepoint
                    # this can only happen with two consecutive boot events
                    # and they account for one session
                    else
                        debug "${_ind}begining (crash ?) of a (new) session"

                        # increase the number of session
                        _count_sessions="$((_count_sessions + 1))"
                        debug "${_ind}session count is now: %d" "$_count_sessions"
                    fi
                fi
            fi
        fi

        # not anymore the first savepoint
        if bool "$_first_sp"; then
            _first_sp=no
        fi
    done
}

# purge backups by removing enough to respect the maximum number allowed
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env  $IFS_BAK          string  backup value of the initial shell IFS
# @env  $SAVEPOINTS_DIR   string  path of the savepoints directory (for the current configuration)
# @env  $opt_now          string  a datetime to indicate when is now
# @env $KEEP_NB_YEARS      int    number of years of savepoints to keep
# @env $KEEP_NB_MONTHS     int    number of months of savepoints to keep
# @env $KEEP_NB_WEEKS      int    number of weeks of savepoints to keep
# @env $KEEP_NB_DAYS       int    number of days of savepoints to keep
# @env $KEEP_NB_HOURS      int    number of hours of savepoints to keep
# @env $KEEP_NB_MINUTES    int    number of minutes of savepoints to keep
#
# and indirectly all the required variables of the functions: remove_savepoint() and purge_safe_savepoint()
#
purge_number_no_session()
{
    _ind='      '
    # if the savepoints directory doesn't exist, return
    [ -d "$SAVEPOINTS_DIR" ] || return 0

    log "[$NAME] ALG purge-number-no-session"

    # for each unit of time
    debug "${_ind}looping over each unit of time:"
    for _unit in minute hour day week month year; do
        _ind='        '
        debug "${_ind}- %s" "$_unit"
        _ind='          '

        # initialise some variables per unit
        eval _sp_to_keep_${_unit}=
        _count_kept_unit=0
        _keep_unit="$(get_opt_or_var_value "KEEP_NB_${_unit}S")"
        [ "$_keep_unit" != '' ] || _keep_unit=0

        # get the list of savepoints, orderred by numbers reversed (most recent first)
        _sp_list="$(\
            find "$SAVEPOINTS_DIR" -maxdepth 1 \( -type d -o -type l \) -not -path "$SAVEPOINTS_DIR" \
            | sort -nr || true)"
        if [ "$_sp_list" = '' ]; then
            "$fun_fatal_error" "$(__ "failed to get the list of backups for directory '%s'" \
                "$SAVEPOINTS_DIR")"
        fi

        debug "${_ind}list of %d backups (including symlinks)" "$(count_list "$_sp_list")"
        debug '%s' "$(echo "$_sp_list" | sed -e "s/^/${_ind}   /g" -e "s|$SAVEPOINTS_DIR/||g")"

        # for each savepoint
        debug "${_ind}looping over each savepoint:"
        IFS='
'
        for _cur_sp in $_sp_list; do
            IFS="$IFS_BAK"
            _ind='            '
            _cur_sp_fn="$(basename "$_cur_sp")"

            # is it a real snapshot or a symlink
            _ts_type="$(if [ -L "$_cur_sp" ]; then echo 'link'; else echo 'snap'; fi)"

            debug "${_ind}- %s%s" "$(basename "$_cur_sp")" \
                "$(if [ "$_ts_type" = 'link' ]; then echo " (link)"; fi)"
            _ind='              '

            # the unit list of savepoints to keep is full
            if [ "$_count_kept_unit" -ge "$_keep_unit" ]; then
                debug "${_ind}the '%s' list of savepoints to keep is full" "$_unit"

                # move to the next unit of time
                debug "${_ind}move to the next unit of time"
                break
            fi

            # not existing anymore
            if [ ! -e "$_cur_sp" ]; then
                debug "${_ind}do not exist anymore"
                debug "${_ind}skipping it"
                continue
            fi

            # if the savepoint has already been flaged 'to keep' by a previous unit of time
            _cur_sp_already_flaged_to_keep_by=
            for __unit in minute hour day week month year; do
                eval '_sp_to_keep_unit="$_sp_to_keep_'"${__unit}"'"'
                # shellcheck disable=SC2154
                if echo "$_sp_to_keep_unit" | grep -q "^$_cur_sp_fn\$"; then
                    debug "${_ind}flaged to keep for unit '%s'" "$__unit"
                    _cur_sp_already_flaged_to_keep_by="$__unit"
                    break
                fi
            done
            _ind='              '
            if [ "$_cur_sp_already_flaged_to_keep_by" != '' ]; then

                # skip it
                debug "${_ind}skiping it (kept by '%s')" "$_cur_sp_already_flaged_to_keep_by"
                continue
            fi

            # here the savepoint has been kept by no one
            # and the unit hasen't its list of savepoints full

            # collect the other savepoints for that same unit of time
            _sp_same_unit=

            # get the date from the current savepoint
            _cur_sp_dt="$(echo "$_cur_sp_fn" | grep -o "$DATE_TEXT_REGEX" | head -n 1 || true)"
            if [ "$_cur_sp_dt" = ''  ]; then
                "$fun_fatal_error" "$(__ "failed to get the date from the savepoint '%s'" \
                    "$_cur_sp_fn")"
            fi
            #debug "${_ind}current savepoint date: '%s'" "$_cur_sp_dt"

            # build a list of days datetime to search for
            _cur_sp_same_unit_days_dt="$_cur_sp_dt"

            # special case for unit 'week'
            if [ "$_unit" = 'week' ]; then

                # get the days for the week of the current savepoint
                _cur_sp_dt_std="$(get_date_std_from_text "$_cur_sp_dt")"
                #debug "${_ind}datetime for day '%s': '%s'" "$_cur_sp_dt" "$_cur_sp_dt_std"
                _cur_sp_same_unit_days_dt="$(get_week_days "$_cur_sp_dt_std" \
                                            |sed 's/^\[[0-9]\+\] \(.*\)$/\1/g' || true)"
                if [ "$_cur_sp_same_unit_days_dt" = '' ]; then
                    "$fun_fatal_error" "$(__ "failed to get the week days for datetime '%s'" \
                        "$_cur_sp_dt_std")"
                fi
                #debug "${_ind}week days: '%s'" "$_cur_sp_same_unit_days_dt"
            fi

            # for each of those days
            IFS='
'
            for _day_dt in $_cur_sp_same_unit_days_dt
            do
                IFS="$IFS_BAK"

                # build a filename pattern from the date, according to the current unit of time
                _cur_sp_date_pattern=
                case "$_unit" in
                    minute) _cur_sp_date_pattern="$(echo "$_day_dt" | cut -c -17)" ;;
                    hour)   _cur_sp_date_pattern="$(echo "$_day_dt" | cut -c -14)" ;;
                    day)    _cur_sp_date_pattern="$(echo "$_day_dt" | cut -c -10)" ;;
                    month)  _cur_sp_date_pattern="$(echo "$_day_dt" | cut -c -7)"  ;;
                    year)   _cur_sp_date_pattern="$(echo "$_day_dt" | cut -c -4)"  ;;
                    week)   _cur_sp_date_pattern="$(echo "$_day_dt" | cut -c -10)" ;;
                esac
                debug "${_ind}filename search pattern: '%s'" "$_cur_sp_date_pattern"

                # get all the savepoints in the same unit of time than the current one
                #debug "${_ind}getting all the savepoints in the same '%s'" "$_unit"
                _cur_sp_same_unit_day_sp="$(\
                    find "$SAVEPOINTS_DIR" -maxdepth 1 \( -type d -o -type l \) \
                        -not -path "$SAVEPOINTS_DIR" \
                        -name "${_cur_sp_date_pattern}*" \
                        -exec basename '{}' \; \
                    || true)"

                if [ "$_cur_sp_same_unit_day_sp" != '' ]; then
                    add_to_list '_sp_same_unit' "$_cur_sp_same_unit_day_sp"
                fi
            done

            _sp_same_unit="$(echo "$_sp_same_unit" | sort -u | sort -nr | sed '/^$/d')"
            _sp_same_unit_count="$(count_list "$_sp_same_unit")"

            #debug "${_ind}list of %d savepoints with same '%s' (including symlinks)" \
            #    "$_sp_same_unit_count" "$_unit"
            #debug '%s' "$(echo "$_sp_same_unit" | sed -e "s/^/${_ind}   /g")"

            # there are other savepoints in the same unit of time
            _sp_same_unit_forward=
            if [ "$_sp_same_unit_count" -gt 1 ]; then
                #debug "${_ind}there are other savepoints in the same '%s'" "$_unit"

                # skip the list until the current savepoint is reached
                #debug "${_ind}skiping the list until the current savepoint is reached"
                _cur_sp_reached=false
                _sp_same_unit_forward="$(echo "$_sp_same_unit" | \
                    while read -r _sp_pipe; do
                        if [ "$_cur_sp_reached" = 'true' ]; then
                            echo "$_sp_pipe";
                        elif [ "$_sp_pipe" = "$_cur_sp_fn" ]; then
                            _cur_sp_reached=true;
                        fi;
                    done)"
            fi

            # there are other savepoints to consider for that unit of time
            _sp_chosen=
            if [ "$_sp_same_unit_forward" != '' ]; then
                debug "${_ind}list of %d savepoints (including symlinks) in the same '%s'" \
                    "$(count_list "$_sp_same_unit_forward")" "$_unit"
                debug '%s' "$(echo "$_sp_same_unit_forward" | sed -e "s/^/${_ind}   /g")"

                # we need to choose which savepoint to keep
                debug "${_ind}we need to choose which savepoint to keep"

                # get the safe savepoints from that list
                debug "${_ind}getting the safe savepoints from that list"
                _sp_same_unit_safe="$(echo "$_sp_same_unit_forward" | \
                    while read -r _sp_pipe; do
                        if is_safe_savepoint "$_sp_pipe"; then
                            echo "$_sp_pipe";
                        fi;
                    done)"

                debug "${_ind}list of %d safe savepoints (including symlinks)" \
                    "$(count_list "$_sp_same_unit_safe")"
                debug '%s' "$(echo "$_sp_same_unit_safe" | sed -e "s/^/${_ind}   /g")"

                # there are safe savepoint
                if [ "$_sp_same_unit_safe" != '' ]; then
                    debug "${_ind}there are safe savepoint"

                    # get the last safe savepoints
                    debug "${_ind}getting the last safe savepoints"
                    _sp_same_unit_safe_last="$(echo "$_sp_same_unit_safe" | tail -n 1)"
                    debug "${_ind}last safe savepoint: '%s'" "$_sp_same_unit_safe_last"

                    # add it to the list of kept savepoints
                    add_to_list '_sp_to_keep_'"${_unit}" "$_sp_same_unit_safe_last"
                    debug "${_ind}added it to the list of kept savepoints"

                    # update the counter left
                    _count_kept_unit="$((_count_kept_unit + 1))"
                    debug "${_ind}updated the counter left (to %d)" "$_count_kept_unit"

                    # remember we have a winner
                    _sp_chosen="$_sp_same_unit_safe_last"

                # there isn't safe savepoint but the current one is
                elif is_safe_savepoint "$_cur_sp"; then
                    debug "${_ind}the current savepoint is a safe savepoint"

                    # add it to the list
                    add_to_list '_sp_to_keep_'"${_unit}" "$_cur_sp_fn"
                    debug "${_ind}added it to the list of kept savepoints"

                    # update the counter left
                    _count_kept_unit="$((_count_kept_unit + 1))"
                    debug "${_ind}updated the counter left (to %d)" "$_count_kept_unit"

                    # remember we have a winner
                    _sp_chosen="$_cur_sp_fn"

                # there isn't safe savepoint and the current one isn't one
                else

                    # get the non-safe savepoints from that list
                    debug "${_ind}getting the non-safe savepoints from the list"
                    _sp_same_unit_unsafe="$(echo "$_sp_same_unit_forward" | \
                        while read -r _sp_pipe; do
                            if ! is_safe_savepoint "$_sp_pipe"; then
                                echo "$_sp_pipe";
                            fi;
                        done)"

                    debug "${_ind}list of %d non-safe savepoints (including symlinks)" \
                        "$(count_list "$_sp_same_unit_unsafe")"
                    debug '%s' "$(echo "$_sp_same_unit_unsafe" | sed -e "s/^/${_ind}   /g")"

                    # there are non-safe savepoints
                    if [ "$_sp_same_unit_unsafe" != '' ]; then
                        debug "${_ind}there are non-safe savepoints"

                        # get the last X
                        debug "${_ind}getting the last non-safe savepoints"
                        _sp_same_unit_unsafe_last="$(echo "$_sp_same_unit_unsafe" | tail -n 1)"
                        debug "${_ind}last non-safe savepoints: '%s'" "$_sp_same_unit_unsafe_last"

                        # add it to the list of kept savepoints
                        add_to_list '_sp_to_keep_'"${_unit}" "$_sp_same_unit_unsafe_last"
                        debug "${_ind}added it to the list of kept savepoints"

                        # update the counter left
                        _count_kept_unit="$((_count_kept_unit + 1))"
                        debug "${_ind}updated the counter left (to %d)" "$_count_kept_unit"

                        # remember we have a winner
                        _sp_chosen="$_sp_same_unit_unsafe_last"
                    fi
                fi
            fi
            _ind='              '

            # no winner yet
            if [ "$_sp_chosen" = '' ]; then
                debug "${_ind}the current savepoint is not kept yet"

                # add it to the list
                add_to_list '_sp_to_keep_'"${_unit}" "$_cur_sp_fn"
                debug "${_ind}added it to the list of kept savepoints"

                # update the counter left
                _count_kept_unit="$((_count_kept_unit + 1))"
                debug "${_ind}updated the counter left (to %d)" "$_count_kept_unit"
            fi

            # for all savepoints of the list that should not be kept
            debug "${_ind}getting all savepoints of the list that should not be kept"
            eval '_sp_to_keep_unit="$_sp_to_keep_'"${_unit}"'"'
            _sp_left_to_consider="$_cur_sp_fn"
            if [ "$_sp_same_unit_forward" != '' ]; then
                _sp_left_to_consider="$_sp_left_to_consider
$_sp_same_unit_forward"
            fi
            _sp_to_delete="$(echo "$_sp_left_to_consider" | \
                while read -r _sp_pipe; do
                    if ! echo "$_sp_to_keep_unit" | grep -q "^$_sp_pipe\$"; then
                        echo "$_sp_pipe";
                    fi;
                done;)"

            debug "${_ind}list of %d savepoints to delete (including symlinks)" \
                "$(count_list "$_sp_to_delete")"
            debug '%s' "$(echo "$_sp_to_delete" | sed -e "s/^/${_ind}   /g")"

            # if there are savepoints to delete
            if [ "$_sp_to_delete" != '' ]; then
                debug "${_ind}there are savepoints to delete"

                # delete them, starting by the oldest
                debug "${_ind}delete them, starting by the oldest"
                echo "$_sp_to_delete" | sort -n | while read -r _sp_del; do
                    _ind='                '
                    debug "${_ind}removing '%s'" "$_sp_del"
                    _ind='                   '
                    remove_savepoint "$SAVEPOINTS_DIR/$_sp_del"
                done
                _ind='              '
            fi

            # move to the next savepoint
            debug "${_ind}moving to the next savepoint"
        done

        # move to the next unit of time
        debug "${_ind}moving to the next unit of time"
    done
}

# purge a safe savepoint according to the configured numbers to keep (per unit of time)
#
# @param  $1  string  path of the current  safe savepoint
# @param  $2   bool   'true' if the current savepoint is the last one
#
# it uses (and modify) the following outside scoped variables :
# @env $_prev_sp               string  path of the previous safe savepoint
# @env $_count_changed_minutes   int   number of minutes   covered by savepoints (so far)
# @env $_count_changed_hours     int   number of hours   covered by savepoints (so far)
# @env $_count_changed_days      int   number of days   covered by savepoints (so far)
# @env $_count_changed_weeks     int   number of weeks  covered by savepoints (so far)
# @env $_count_changed_months    int   number of months covered by savepoints (so far)
# @env $_count_changed_years     int   number of years  covered by savepoints (so far)
#
# the configurations should have been loaded (global, local, and for that folder).
# the CLI arguments/options shoud have been parsed
#
# uses the following outside-defined variables
# @env $KEEP_NB_YEARS      int    number of years of savepoints to keep
# @env $KEEP_NB_MONTHS     int    number of months of savepoints to keep
# @env $KEEP_NB_WEEKS      int    number of weeks of savepoints to keep
# @env $KEEP_NB_DAYS       int    number of days of savepoints to keep
# @env $KEEP_NB_HOURS      int    number of hours of savepoints to keep
# @env $KEEP_NB_MINUTES    int    number of minutes of savepoints to keep
# @env $DATE_TEXT_FORMAT  string  a datetime format for date output
#
purge_safe_savepoint()
{
    _ind='            '
    _safe_sp="$1"
    _is_last_sp="$2"

    # skip symlinks
    if [ -L "$_safe_sp" ]; then
        debug "${_ind}skipping symlink of a safe savepoint"
        return
    fi

    # if this is the first safe savepoint (no previous) : keep it
    if [ "$_prev_sp" = '' ]; then
        debug "${_ind}keeping the first safe savepoint"
        _prev_sp="$_safe_sp"
        return
    fi

    # filename
    _safe_sp_fn="$(basename "$_safe_sp")"
    _prev_sp_fn="$(basename "$_prev_sp")"

    # get all unit of time for the current savepoint
    _sp_ts="$(get_savepoint_timestamp "$_safe_sp_fn")"
    debug "${_ind}ts: %d (%s)" "$_sp_ts" "$(get_date_to_text "@$_sp_ts")"
    # shellcheck disable=SC2034
    _sp_year="$(date -d "@$_sp_ts" '+%Y' | sed 's/^0\(.\)$/\1/')"
    _sp_year_full="$_sp_year"
    _sp_month="$(date -d "@$_sp_ts" '+%m' | sed 's/^0\(.\)$/\1/')"
    _sp_month_full="$_sp_year_full-$_sp_month"
    _sp_week="$(date -d "@$_sp_ts" '+%U' | sed 's/^0\(.\)$/\1/')"
    # shellcheck disable=SC2034
    _sp_week_full="$_sp_month_full-$_sp_week"
    _sp_day="$(date -d "@$_sp_ts" '+%d' | sed 's/^0\(.\)$/\1/')"
    _sp_day_full="$_sp_month_full-$_sp_day"
    _sp_hour="$(date -d "@$_sp_ts" '+%H' | sed 's/^0\(.\)$/\1/')"
    _sp_hour_full="$_sp_day_full $_sp_hour"
    _sp_minute="$(date -d "@$_sp_ts" '+%M' | sed 's/^0\(.\)$/\1/')"
    # shellcheck disable=SC2034
    _sp_minute_full="$_sp_hour_full:$_sp_minute"
    debug "${_ind}sp year: %d" "$_sp_year"
    debug "${_ind}sp month: %d" "$_sp_month"
    debug "${_ind}sp day: %d" "$_sp_day"
    debug "${_ind}sp hour: %d" "$_sp_hour"
    debug "${_ind}sp minute: %d" "$_sp_minute"
    debug "${_ind}sp week: %d" "$_sp_week"

    # get all unit of time for the previous savepoint
    _prev_sp_ts="$(get_savepoint_timestamp "$_prev_sp_fn")"
    debug "${_ind}ts: %d (%s)" "$_sp_ts" "$(get_date_to_text "@$_prev_sp_ts")"
    # shellcheck disable=SC2034
    _prev_sp_year="$(date -d "@$_prev_sp_ts" '+%Y' | sed 's/^0\(.\)$/\1/')"
    _prev_sp_year_full="$_prev_sp_year"
    _prev_sp_month="$(date -d "@$_prev_sp_ts" '+%m' | sed 's/^0\(.\)$/\1/')"
    _prev_sp_month_full="$_prev_sp_year_full-$_prev_sp_month"
    _prev_sp_week="$(date -d "@$_prev_sp_ts" '+%U' | sed 's/^0\(.\)$/\1/')"
    # shellcheck disable=SC2034
    _prev_sp_week_full="$_prev_sp_month_full-$_prev_sp_week"
    _prev_sp_day="$(date -d "@$_prev_sp_ts" '+%d' | sed 's/^0\(.\)$/\1/')"
    _prev_sp_day_full="$_prev_sp_month_full-$_prev_sp_day"
    _prev_sp_hour="$(date -d "@$_prev_sp_ts" '+%d' | sed 's/^0\(.\)$/\1/')"
    _prev_sp_hour_full="$_prev_sp_day_full $_prev_sp_hour"
    _prev_sp_minute="$(date -d "@$_prev_sp_ts" '+%d' | sed 's/^0\(.\)$/\1/')"
    # shellcheck disable=SC2034
    _prev_sp_minute_full="$_prev_sp_hour_full:$_prev_sp_minute"
    debug "${_ind}prev_sp year: %d" "$_prev_sp_year"
    debug "${_ind}prev_sp month: %d" "$_prev_sp_month"
    debug "${_ind}prev_sp day: %d" "$_prev_sp_day"
    debug "${_ind}prev_sp hour: %d" "$_prev_sp_hour"
    debug "${_ind}prev_sp minute: %d" "$_prev_sp_minute"
    debug "${_ind}prev_sp week: %d" "$_prev_sp_week"

    # flags for "removability" of the previous savepoint
    _minute_want_to_keep_it=no
    _hour_want_to_keep_it=no
    _day_want_to_keep_it=no
    _week_want_to_keep_it=no
    _month_want_to_keep_it=no
    _year_want_to_keep_it=no

    # flags for "removability" of the last savepoint
    if bool "$_is_last_sp"; then
        _minute_want_to_keep_last=no
        _hour_want_to_keep_last=no
        _day_want_to_keep_last=no
        _week_want_to_keep_last=no
        _month_want_to_keep_last=no
        _year_want_to_keep_last=no
    fi

    # for each unit of time
    debug "${_ind}looping over each unit of time:"
    for _unit in year month week day hour minute; do
        debug "${_ind}- %s" "$_unit"
        _ind='               '

        eval "_sp_unit=\$_sp_$_unit"
        eval "_sp_unit_full=\$_sp_${_unit}_full"
        eval "_prev_sp_unit=\$_prev_sp_$_unit"
        eval "_prev_sp_unit_full=\$_prev_sp_${_unit}_full"
        eval "_count_changed_unit=\$_count_changed_${_unit}s"
        _keep_unit="$(get_opt_or_var_value "KEEP_NB_${_unit}S")"
        [ "$_keep_unit" != '' ] || _keep_unit=0

        # shellcheck disable=SC2154
        debug "${_ind}_sp_$_unit: %d" "$_sp_unit"
        # shellcheck disable=SC2154
        debug "${_ind}_sp_${_unit}_full: %s" "$_sp_unit_full"
        # shellcheck disable=SC2154
        debug "${_ind}_prev_sp_$_unit: %d" "$_prev_sp_unit"
        # shellcheck disable=SC2154
        debug "${_ind}_prev_sp_${_unit}_full: %s" "$_prev_sp_unit_full"
        # shellcheck disable=SC2154
        debug "${_ind}_count_changed_${_unit}s: %d" "$_count_changed_unit"
        # shellcheck disable=SC2154
        debug "${_ind}_keep_${_unit}s: %d" "$_keep_unit"

        # if we don't have any previous unit value
        if [ "$_prev_sp_unit" = '' ]; then
            debug "${_ind}no previous unit value. This should not happen."
            debug "${_ind}keeping previous savepoint"
            eval "_${_unit}_want_to_keep_it=yes"

            # keeping also the last savepoint
            if bool "$_is_last_sp"; then
                debug "${_ind}keeping last savepoint"
                eval "_${_unit}_want_to_keep_last=yes"
            fi

        # else if we just changed minute/hour/day/week/month/year
        elif [ "$_sp_unit_full" != "$_prev_sp_unit_full" ]; then
            debug "${_ind}we just changed $_unit ($_sp_unit_full != $_prev_sp_unit_full)"

            # increasing the unit changes count
            eval "_count_changed_${_unit}s='$((_count_changed_unit + 1))'"
            eval "_count_changed_unit=\$_count_changed_""$_unit""s"
            debug "${_ind}updated '_count_changed_${_unit}s' to: %d" \
                "$_count_changed_unit"

            # if we have reach the limit for this unit
            if [ "$_count_changed_unit" -eq "$_keep_unit" ]; then
                debug "${_ind}the limit of $_unit is reached (%s)" \
                    "$_count_changed_unit = $_keep_unit"
                debug "${_ind}keep the previous savepoint"
                eval "_${_unit}_want_to_keep_it=yes"

                # if this is the last savepoint
                if bool "$_is_last_sp"; then
                    debug "${_ind}removing the last savepoint"
                fi

            # if we are over the limit for this unit
            elif [ "$_count_changed_unit" -gt "$_keep_unit" ]; then
                debug "${_ind}the limit of $_unit is over (%s)" \
                    "$_count_changed_unit > $_keep_unit"

                # so we want to remove the previous savepoint (for this unit of time)
                debug "${_ind}removing the previous savepoint"

                # if this is the last savepoint
                if bool "$_is_last_sp"; then
                    debug "${_ind}removing the last savepoint"
                fi

            # not yet the limit
            else
                debug "${_ind}not yet the limit"
                debug "${_ind}keep the previous savepoint"
                eval "_${_unit}_want_to_keep_it=yes"

                # keeping also the last savepoint
                if bool "$_is_last_sp"; then
                    debug "${_ind}keeping last savepoint"
                    eval "_${_unit}_want_to_keep_last=yes"
                fi
            fi

        # not changed unit
        else

            # this is not the last savepoint for this unit of time,
            # so we want to remove the previous savepoint (for this unit of time)
            debug "${_ind}not the last savepoint of $_unit"
            debug "${_ind}remove the previous savepoint"

            # keeping also the last savepoint
            if bool "$_is_last_sp"; then
                debug "${_ind}keeping last savepoint"
                eval "_${_unit}_want_to_keep_last=yes"
            fi
        fi
    done
    _ind='            '

    # if no unit of time wants to keep the previous savepoint
    if ! bool "$_minute_want_to_keep_it" && ! bool "$_hour_want_to_keep_it"  && \
            ! bool "$_day_want_to_keep_it" && ! bool "$_week_want_to_keep_it" && \
            ! bool "$_month_want_to_keep_it" && ! bool "$_year_want_to_keep_it"; then

        # remove the previous savepoint
        debug "${_ind}removing savepoint '%s'" "$_prev_sp"
        _ind='               '
        remove_savepoint "$_prev_sp"
        _ind='            '
    else
        debug "${_ind}finaly keeping previous savepoint"
    fi

    # if no unit of time wants to keep the last savepoint
    if bool "$_is_last_sp" && \
            ! bool "$_minute_want_to_keep_last" && ! bool "$_hour_want_to_keep_last" && \
            ! bool "$_day_want_to_keep_last" && ! bool "$_week_want_to_keep_last" && \
            ! bool "$_month_want_to_keep_last" && ! bool "$_year_want_to_keep_last"; then

        # remove the last savepoint
        _ind='               '
        remove_savepoint "$_safe_sp"
        _ind='            '

    # the last savepoint will be kept
    elif bool "$_is_last_sp"; then
        debug "${_ind}finaly keeping last savepoint"
    fi

    # the current savepoint become the previous one
    _prev_sp="$_safe_sp"
}

# get the savepoint timestamp from the datetime in its filename
get_savepoint_timestamp()
{
    _sp_fn_date="$(echo "$1" | grep -o "$DATE_TEXT_REGEX" | head -n 1 || true)"
    if [ "$_sp_fn_date" != '' ]; then
        date -d "$(echo "$_sp_fn_date" | sed -e 's/_/ /g' -e 's/[hm]/:/g')" '+%s'
    else
        "$fun_fatal_error" "$(__ "failed to get a date from filename '%s'" "$1")"
    fi
}

# return 0 if the savepoint match the begining of a session
is_session_begining()
{
    echo "$1" | grep -q '\(\.\|^\)\(boot\|resume\)\(\.\|$\)'
}

# return 0 if the savepoint match the end of a session
is_session_end()
{
    echo "$1" | grep -q '\(\.\|^\)\(reboot\|shutdown\|halt\|suspend\)\(\.\|$\)'
}

# remove a savepoint, and update/remove all the symlinks that points at it
#
# Note: By default, it may not be really removed, but instead just be renamed/moved up
#       if a newer symlink where pointing at it, it will just replace that symlink.
#       In order to really delete it and all the symlinks pointing at it (recursively),
#       the second parameter must be specified.
#
# @param  $1  string  the savepoint path
# @param  $2   bool   if 'true' will remove the savepoint and all the symlinks pointing at it recursively
#
# uses the following outside-defined variables
# @env  $NAME                string  name of the current configuration being processed
# @env  $SAVEPOINTS_DIR      string  path of the savepoints directory (for the current configuration)
# @env  $HOOK_BEFORE_DELETE  string  shell command to execute before the deletion
# @env  $HOOK_AFTER_DELETE   string  shell command to execute after the deletion
#
remove_savepoint()
{
    _sp_fn="$(basename "$1")"

    # flag to know if we need to remove the savepoint (if it has not been moved elsewhere)
    _to_remove=false

    # trigger hook before deletion
    _hook="$(get_opt_or_var_value 'HOOK_BEFORE_DELETE')"
    if [ "$_hook" ]; then
        _hook="$_hook '$1'"
        debug "${_ind}triggering the hook command '%s'" "$_hook"
        if ! sh -c "$_hook"; then
            "$fun_fatal_error" "the hook command '%s' has failed" "$_hook"
        fi
    fi

    # get the list of symlinks point at it
    debug "${_ind}get the list of symlinks point at '%s'" "$_sp_fn"
    _symlink_src="$(find "$SAVEPOINTS_DIR" -maxdepth 1 -type l | while read -r _lnk; do
                        if [ "$(readlink "$_lnk")" = "$_sp_fn" ]; then echo "$_lnk"; fi;
                    done || true)"

    # is the savepoint a symlink and what is its target
    _is_link=false
    _link_target=
    if [ -L "$1" ]; then
        _is_link=true
        _link_target="$(readlink "$1")"
    fi

    # if there is at least one symlink point at it
    if [ "$_symlink_src" != '' ]; then
        debug "${_ind}found %d symlinks" "$(count_list "$_symlink_src")"

        _new_symlink_ref=

        # the savepoint is not a symlink itself
        if ! bool "$_is_link"; then
            debug "${_ind}savepoint is not a symlink itself"

            # it was asked to delete the savepoint and all its symlinks
            if bool "$2"; then
                debug "${_ind}was asked to delete the savepoint and all its symlink"

                # delete it
                debug "${_ind}flaging it to be deleted"
                _to_remove=true

            # by default we just rename/move up the savepoint to the oldest symlink pointing at it
            else
                debug "${_ind}just renaming/moving up the savepoint "`
                      `"to the oldest symlink pointing at it"

                # get the last/oldest symlink
                _oldest_symlink="$(echo "$_symlink_src" | head -n 1)"
                _oldest_symlink_fn="$(basename "$_oldest_symlink")"
                debug "${_ind}last/oldest symlink: %s" "$_oldest_symlink_fn"

                # move it to the last/oldest symlink
                debug "${_ind}removing last/oldest symlink"
                rm -f "$_oldest_symlink"

                debug "${_ind}moving savepoint '%s' to replace symlink '%s'" \
                    "$_sp_fn" "$_oldest_symlink_fn"
                mv "$1" "$_oldest_symlink"

                log "[$NAME] - %s" "$_sp_fn"
                log "[$NAME] = %s <- %s" "$_oldest_symlink_fn" "$_sp_fn"

                # others symlink pointing at it will be the one replaced with the savepoint
                debug "${_ind}others symlinks point at the savepoint "`
                      `"will be updated to point to its new path"
                _new_symlink_ref="$_oldest_symlink"
            fi

        # it is a symlink
        else
            debug "${_ind}savepoint is a symlink itself"

            # others symlinks pointing at this one will be updated to point to its destination
            debug "${_ind}others symlinks point at it will be updated to point to its destination"
            _new_symlink_ref="$(readlink "$1")"

            # delete it
            debug "${_ind}flaging it to be deleted"
            _to_remove=true
        fi

        # update the symlinks reference
        if [ "$_new_symlink_ref" != '' ]; then
            _new_symlink_ref_fn="$(basename "$_new_symlink_ref")"
            debug "${_ind}replacing others symlinks with the new destination '%s'" \
                "$_new_symlink_ref_fn"
            find "$SAVEPOINTS_DIR" -maxdepth 1 -type l | while read -r _lnk; do
                if [ "$(readlink "$_lnk")" = "$_sp_fn" ]; then
                    _lnk_fn="$(basename "$_lnk")"
                    debug "${_ind}   removing symlink '%s'" "$_lnk_fn"
                    rm -f "$_lnk"

                    debug "${_ind}   recreating symlink '%s' pointing at '%s'" \
                        "$_lnk_fn" "$_new_symlink_ref_fn"
                    ln -s "$_new_symlink_ref_fn" "$_lnk"

                    log "[$NAME] = %s -> * %s" "$_lnk_fn" "$_new_symlink_ref_fn"
                fi
            done

        # or remove every symlinks connected to it
        else

            remove_symlinks_recursively "$1"
        fi

    # no symlinks
    else
        debug "${_ind}no symlink found"

        # delete it
        debug "${_ind}flaging the savepoint to be deleted"
        _to_remove=true
    fi

    # need to remove it for real
    if bool "$_to_remove"; then
        debug "${_ind}savepoint is flaged to be deleted"

        # it is just a symlink
        if bool "$_is_link"; then
            debug "${_ind}removing symlink '$_sp_fn'"
            rm -f "$1"

        # real snapshot
        else

            # remove the savepoint
            debug "${_ind}removing savepoint '$_sp_fn'"
            if ! btrfs subvolume delete --commit-after "$1" >/dev/null; then
                "$fun_fatal_error" "$(__ "failed to delete savepoint '%s'" "$_sp_fn")"
            fi
        fi

        log "[$NAME] - %s%s" "$_sp_fn" "$(if bool "$_is_link"; then echo "( -> $_link_target)"; fi)"
    fi

    # trigger hook after deletion
    _hook="$(get_opt_or_var_value 'HOOK_AFTER_DELETE')"
    if [ "$_hook" ]; then
        _hook="$_hook '$1'"
        debug "${_ind}triggering the hook command '%s'" "$_hook"
        if ! sh -c "$_hook"; then
            "$fun_fatal_error" "the hook command '%s' has failed" "$_hook"
        fi
    fi
}

# remove recursively all the symlink pointing at a file
# and the symlinks pointing at them (in the same directory)
# @param  $1  string  the symlink to remove
remove_symlinks_recursively()
{
    find "$(dirname "$1")"/ -maxdepth 1 -type l | while read -r _lnk; do
        _lnk_target="$(readlink "$_lnk")"
        if [ "$_lnk" != "$1" ] && [ "$_lnk_target" = "$(basename "$1")" ]; then
            remove_symlinks_recursively "$_lnk"
            rm -f "$_lnk"
            log "[$NAME] - %s ( -> %s)" "$(basename "$_lnk")" "$_lnk_target"
        fi
    done
}

# return 0 if the backup specified belongs to the safe type
# @param  string  path to the backup
is_safe_savepoint()
{
    echo "$1" | grep -v '\.\(before-restoring-from-\|after-restoration-is-equals-to-\)' \
        | grep -q '\(\.\|^\)safe\(\.\|$\)'
}

# return 0 if the path is a subvolume
# @from: https://stackoverflow.com/a/25908150
is_btrfs_subvolume()
{
    _st_file="$1"
    if [ -L "$_st_file" ]; then
        _st_file="$(realpath "$_st_file")"
    fi
    case "$(stat -f -c "%T" "$_st_file")" in
       btrfs|UNKNOWN) ;;
       *) return 1 ;;
    esac
    case "$(stat -c "%i" "$_st_file")" in
        2|256) return 0 ;;
        *) return 1 ;;
    esac
}

# get the mount point of a path
#
# Note: its using 'df' with compatibility and space proof
#
# @param  $1  string  path to get mount point from
#
get_mount_point_for_path()
{
    [ "$1" != '' ] || return 1

    # go up/backup one directory at a time, as long as 'df' is failing
    _ref_path="$1"
    while ! df "$_ref_path" >/dev/null 2>&1 && [ "$_ref_path" != '/' ]; do
        _ref_path="$(dirname "$_ref_path")"
    done
    if _df_out="$(LC_ALL=C df -P "$_ref_path")"; then
        echo "$_df_out" | tail -n +2 | \
            awk '{$1=""; $2=""; $3=""; $4=""; $5=""; print $0}' | \
            sed 's/^ \+//g;s/ \+$//g'
    else
        "$fun_warning" "$(__ "failed to get mount point for '%s'" "$1")"
        return 1
    fi
}

# get the amount of free space left (Gb) for the specified path
#
# Note: its using 'df' with compatibility and space proof
#
# @param  $1  string  path to check for free space
#
get_free_space_gb()
{
    [ "$1" != '' ] || return 1

    _ref_path="$(get_mount_point_for_path "$1")"
    if [ "$_ref_path" != "$1" ]; then
        debug "${_ind}using mount point '%s' for path '%s'" "$_ref_path" "$1"
    fi
    if _df_out="$(LC_ALL=C df -m -P "$_ref_path")"; then
        echo "$_df_out" | tail -n +2 | \
            LC_ALL=C awk '{printf "%.1f\n", ($4 / 1024)}'
    else
        "$fun_warning" "$(__ "failed to get avalable free space for '%s'" "$1")"
        return 1
    fi
}

# ensure that there is enough free space before proceeding,
# and in case not, do the specified action (var: NO_FREE_SPACE_ACTION)
#
# @param  $1  string  path to check for free space
#
ensure_enough_free_space()
{
    debug "   checking for available required free space"

    # get free space (in Gb)
    _free_space="$(get_free_space_gb "$1" || true)"
    if [ "$_free_space" = '' ]; then
        "$fun_fatal_error" "$(__ "failed to get avalable free space for '%s'" "$1")"
    fi
    debug "   path '%s' has '%.1f' Gb of free space" "$1" "$_free_space"
    debug "   free space limit is : '%.1f' Gb" "$ENSURE_FREE_SPACE_GB"

    if [ "$(echo "$_free_space" "$ENSURE_FREE_SPACE_GB" | LC_ALL=C awk '{print ($1 >= $2)}')" = '0' ]
    then

        _msg="$(__ "not enough free space for path '%s'" "$1") "`
             `"$(__ "(available: %.1f Gb, limit: %.1f Gb)" "$_free_space" "$ENSURE_FREE_SPACE_GB")"

        case "$NO_FREE_SPACE_ACTION" in
            fail)
                log "[$NAME] ERR %s" "$_msg"
                "$fun_fatal_error" "$_msg" ;;
            warn)
                log "[$NAME] WRN %s" "$_msg"
                "$fun_warning" "$_msg" ;;
            prune)
                log "[$NAME] WRN %s" "$_msg"
                prune_savepoints || "$fun_warning" "$(__ 'pruning savepoints have failed')"
                NO_FREE_SPACE_ACTION=fail ensure_enough_free_space "$1"
                NO_FREE_SPACE_ACTION=prune
                ;;
            shell:*)
                log "[$NAME] WRN %s" "$_msg"
                _shell_script="$(echo "$NO_FREE_SPACE_ACTION" | sed 's|^shell:||')"
                debug "   running the specified shell script: '%s'" "$_shell_script"
                if [ ! -r "$_shell_script" ]; then
                    log "[$NAME] ERR shell script '%s' doesn't exist" "$_shell_script"
                    "$fun_fatal_error" "$(__ "shell script '%s' doesn't exist" "$_shell_script")"
                fi
                if ! sh "$_shell_script" \
                        "$1" "$_free_space" "$ENSURE_FREE_SPACE_GB"
                then
                    _shell_script_args="'$1' '$_free_space' "`
                                       `"'$ENSURE_FREE_SPACE_GB'"
                    log "[$NAME] ERR shell script '%s' failed (arguments: %s)" \
                        "$_shell_script" "$_shell_script_args"
                    "$fun_fatal_error" "$(__ "shell script '%s' has failed (arguments: %s)" \
                        "$_shell_script" "$_shell_script_args")"
                fi
                NO_FREE_SPACE_ACTION=fail ensure_enough_free_space "$1"
                NO_FREE_SPACE_ACTION="shell:$_shell_script"
                ;;
        esac
    fi
}

# return a date to the format : Y-m-d_HhMmS
# @param  $1  string  the datetime/timestamp to convert from
get_date_to_text()
{
    date -d "$1" "+$DATE_TEXT_FORMAT"
}

# return a date with the format: Y-m-d H:M:S
# @param  $1  string  the datetime/timestamp to convert from
get_date_to_std()
{
    date -d "$1" "+$DATE_STD_FORMAT"
}

# return a date with the format: Y-m-d H:M:S
# from a date with the format  : Y-m-d_HhMmS
# @param  $1  string  the date to convert from
get_date_std_from_text()
{
    get_date_to_std "$(echo "$1" | sed -e 's/_/ /g' -e 's/[hm]/:/g')"
}

# return a list of days dates that represents the current week
#
# @param  $1  string  the date to use as the reference (format: Y-m-d H:M:S)
#
get_week_days()
{
    # get current week day
    _cur_week_day="$(date -d "$1" '+%u' || true)"
    if [ "$_cur_week_day" = '' ]; then
        "$fun_fatal_error" "$(__ "failed to get week day of datetime '%s'" "$1")"
    fi

    # get current datetime in ISO format
    _cur_dt_iso="$(date -d "$1" -Iseconds)"

    # get previous week days (including the current one)
    for _d in $(seq 1 "$_cur_week_day"); do
        date -d "$_cur_dt_iso - $((_cur_week_day - _d)) days" "+[%u] $DATE_TEXT_FORMAT"
    done

    # get next days
    for _d in $(seq 1 "$((7 - _cur_week_day))"); do
        date -d "$_cur_dt_iso + $_d days" "+[%u] $DATE_TEXT_FORMAT"
    done
}

# trigger a fatal error if the value is not a positive number
# @param  $1  string  the value to check
# @param  $2  string  name of the variable
ensure_positive_number()
{
    echo "$1" | grep -q '^[0-9]\+$' || \
        "$fun_fatal_error" "$(__ "invalid positive number value '%s' (variable: '%s')" "$1" "$2")"
}

# trigger a fatal error if the value is not a decimal number
# @param  $1  string  the value to check
# @param  $2  string  name of the variable
ensure_decimal_number()
{
    echo "$1" | grep -q '^[0-9]\+\(\.[0-9]\+\)\?$' || \
        "$fun_fatal_error" "$(__ "invalid decimal number value '%s' (variable: '%s')" "$1" "$2")"
}

# trigger a fatal error if the value is not a valid boolean
# @param  $1  string  the value to check
# @param  $2  string  name of the variable
ensure_boolean()
{
    echo "$1" | grep -q -i '^\(yes\|y\|true\|t\|1\|on\|no\|n\|false\|f\|0\|off\)$' || \
        "$fun_fatal_error" "$( __ "invalid boolean value '%s' (variable: '%s')" "$1" "$2")"
}

# count the number of item in a list of line separated values
#
# @param  $1  string  the list to count
# @param  $2  string  if '--not-empty', only counts for not empty lines
#
count_list()
{
    if [  "$1" = '' ]; then
        echo 0
    elif [ "$2" = '--not-empty' ]; then
        echo "$1" | sed '/^$/d' | wc -l
    else
        echo "$1" | wc -l
    fi
}

# add an item to a list of line separated values
#
# @param  $1  string  the list name
# @param  $2  string  the new item to add
#
add_to_list()
{
    if [ "$(eval echo '$'"$1")" = '' ]; then
        eval "$1"'="'"$2"'"'
    else
        eval "$1"'="$'"$1"'
'"$2"'"'
    fi
}

# write to log file, prefix by the date
#
# @param  $1  string  the line to write
#
# uses the following outside-defined variables
# @env  $PERSISTENT_LOG  string  path of the log file
#
log()
{
    msg_ln "$@" | prefix_line_ts >> "$PERSISTENT_LOG" || true
}

# prefix each line with a timestamp
prefix_line_ts()
{
    if [ "$MSG_DATETIME_FORMAT" != '' ]; then
        sed "s/^/$(date "+$MSG_DATETIME_FORMAT")/g"
    fi
}

# display a message with a line break to STDERR
msg_ln()
{
    _fmt="%s\\n"
    if [ "$#" -gt 1 ]; then
        _fmt="$1\\n"
        shift
    fi
    # shellcheck disable=SC2059
    printf "$_fmt" "$@"
}

# display a message with a prefix
msg_prefix()
{
    if [ "$#" -gt 0 ]; then
        _prefix="$1"
        shift
        # TODO add safety for sed replacement part
        msg_ln "$@" | sed "s/^/$_prefix/g" | prefix_line_ts
    else
        msg_ln "$@" | prefix_line_ts
    fi
}

# display an error message and exit with code status 1
fatal_error()
{
    msg_prefix "$(__ 'Fatal error'): " "$@" >&2
    exit 1
}

# display a "$fun_warning" message
warning()
{
    msg_prefix "$(__ 'Warning'): " "$@" >&2
}

# display a success message
success()
{
    msg_prefix "$(__ 'Success'): " "$@" >&2
}

# display begin message
begin_msg()
{
    msg_prefix 'Started: ' "$@" >&2
}

# display end message
end_msg()
{
    msg_prefix 'Finished: ' "$@" >&2
}

# display a debug message (if debuging is enabled)
debug()
{
    if [ "$DEBUG" = "$PROGRAM_NAME" ]; then
        msg_prefix '[DEBUG] ' "$@" >&2
    fi
}

# fatal error function for systemd LSB
# because none exists
systemd_panic()
{
    log_failure_msg "$@"
    exit 1
}

# end message function for systemd
# because it can only handle a return integer, not a message
systemd_end_msg()
{
    log_end_msg 0
}

# ensure required binaries exists and are in the correct version
ensure_required_bin()
{
    # ensure required binaries exist
    for bin in find sed grep mount btrfs date df; do
        if ! command -v $bin >/dev/null 2>&1; then
            "$fun_fatal_error" "$(__ "binary '%s' not found" "$bin")"
        fi
    done

    # GNU binaries (date)
    #
    # 'date' binary must be GNU because the function get_week_days()
    # use ISO date as input and operations like '- X days'
    #
    # shellcheck disable=SC2043
    for bin in date; do
        if ! "$bin" --version | head -n 1 | grep -q "^$bin (GNU coreutils).*\$"; then
            "$fun_fatal_error" "$(__ "the version '%s' is required for the binary '%s'" \
                "$bin" 'GNU coreutils')"
        fi
    done
}

# ensure global configuration variables are valid/sane
ensure_valid_global_config()
{

    # free space variable have to be defined
    if [ "$ENSURE_FREE_SPACE_GB" = '' ]; then
        ENSURE_FREE_SPACE_GB="$DEFAULT_ENSURE_FREE_SPACE_GB"
    fi
    if [ "$NO_FREE_SPACE_ACTION" = '' ]; then
        NO_FREE_SPACE_ACTION="$DEFAULT_NO_FREE_SPACE_ACTION"
    fi

    # print and checks global variables
    debug ""
    debug "Global configuration variables :"
    for var in PERSISTENT_LOG CONFIGS_DIR \
            ENSURE_FREE_SPACE_GB NO_FREE_SPACE_ACTION \
            PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL CONFIGS_DIR_FROM_TOPLEVEL_SUBVOL \
            SP_DEFAULT_SAVEPOINTS_DIR_BASE SP_DEFAULT_BACKUP_BOOT SP_DEFAULT_BACKUP_REBOOT \
            SP_DEFAULT_BACKUP_SHUTDOWN SP_DEFAULT_BACKUP_HALT SP_DEFAULT_BACKUP_SUSPEND \
            SP_DEFAULT_BACKUP_RESUME SP_DEFAULT_SUFFIX_BOOT SP_DEFAULT_SUFFIX_REBOOT \
            SP_DEFAULT_SUFFIX_SHUTDOWN SP_DEFAULT_SUFFIX_HALT SP_DEFAULT_SUFFIX_SUSPEND \
            SP_DEFAULT_SUFFIX_RESUME SP_DEFAULT_SAFE_BACKUP SP_DEFAULT_KEEP_NB_SESSIONS \
            SP_DEFAULT_KEEP_NB_MINUTES SP_DEFAULT_KEEP_NB_HOURS SP_DEFAULT_KEEP_NB_DAYS \
            SP_DEFAULT_KEEP_NB_WEEKS SP_DEFAULT_KEEP_NB_MONTHS \
            SP_DEFAULT_KEEP_NB_YEARS SP_DEFAULT_DIFF_IGNORE_PATTERNS SP_DEFAULT_HOOK_BEFORE_BACKUP \
            SP_DEFAULT_HOOK_AFTER_BACKUP SP_DEFAULT_HOOK_BEFORE_RESTORE \
            SP_DEFAULT_HOOK_AFTER_RESTORE SP_DEFAULT_HOOK_BEFORE_DELETE \
            SP_DEFAULT_HOOK_AFTER_DELETE SP_DEFAULT_NO_PURGE_DIFF SP_DEFAULT_NO_PURGE_NUMBER \
            SP_DEFAULT_PURGE_NUMBER_NO_SESSION
    do
        eval _var_value="\$$var"
        if [ "$_var_value" != '' ]; then
            debug "  %s: '%s'" "$var" "$_var_value"
            case "$var" in
                ENSURE_FREE_SPACE_GB) ensure_decimal_number "$_var_value" "$var";;
                SP_DEFAULT_KEEP_NB_*) ensure_positive_number "$_var_value" "$var";;
                SP_DEFAULT_BACKUP_*|SP_DEFAULT_NO_PURGE_*|SP_DEFAULT_PURGE$) \
                    ensure_boolean "$_var_value" "$var" ;;
                NO_FREE_SPACE_ACTION)
                    echo "$_var_value" | grep -q '^\(fail\|warn\|prune\|shell:.*\)$' || \
                    "$fun_fatal_error" "$(__ "invalid value for global variable '%s' (%s)" \
                                        "$var" "$_var_value")" ;;
            esac
        fi
    done
    debug ""
}

# main program
main()
{
    # sets all required defautls variable
    set_default_vars

    # setup language and translations
    setup_language

    # # export language settings
    # export TEXTDOMAIN
    # export TEXTDOMAINDIR
    # export LANG
    # export LANGUAGE

    # dump the CLI used
    debug ""
    debug "CLI: '%s'" "$0 $*"

    # options  (requires GNU getopt)
    if ! TEMP="$(getopt \
        -o 'c:d:fg:ihkm:n:su:r:v' \
        -l 'config:,date:,force-deletion,format-gui,from-toplevel-subvol:,'`
            `'global-config:,help,help-conf,no-ignore-patterns,keep-mounted,moment:,no-purge-diff,'`
            `'name:,safe,suffix:,now:,no-purge-diff,no-purge-number,'`
            `'no-defaults-copy,skip-free-space,initramfs,systemd,version' \
        -n "$THIS_SCRIPT_NAME" -- "$@")"
    then
        "$fun_fatal_error" "$(__ "invalid option")"
    fi
    eval set -- "$TEMP"

    opt_config=
    opt_date=
    opt_force_deletion=false
    opt_format_gui=false
    opt_from_toplevel_subvol=
    opt_global_config=
    opt_help=false
    opt_help_conf=false
    opt_no_ignore_patterns=false
    opt_initramfs=false
    opt_keep_mounted=false
    opt_moment=
    opt_no_purge_diff=false
    opt_no_purge_number=false
    opt_now=
    opt_safe=false
    opt_skip_free_space=false
    opt_suffix=
    opt_systemd=false
    opt_version=false
    while true; do
        # shellcheck disable=SC2034
        case "$1" in
            -c | --config               ) opt_config="$2"               ; shift 2 ;;
            -d | --date                 ) opt_date="$2"                 ; shift 2 ;;
            -f | --force-deletion       ) opt_force_deletion=true       ; shift   ;;
            -g | --global-config        ) opt_global_config="$2"        ; shift 2 ;;
            -h | --help                 ) opt_help=true                 ; shift   ;;
            -i | --skip-free-space      ) opt_skip_free_space=true      ; shift   ;;
            -k | --keep-mounted         ) opt_keep_mounted=true         ; shift   ;;
            -m | --moment               ) opt_moment="$2"               ; shift 2 ;;
            -r | --from-toplevel-subvol ) opt_from_toplevel_subvol="$2" ; shift 2 ;;
            -s | --safe                 ) opt_safe=true                 ; shift   ;;
            -u | --suffix               ) opt_suffix="$2"               ; shift 2 ;;
            -v | --version              ) opt_version=true              ; shift   ;;
            --help-conf                 ) opt_help_conf=true            ; shift   ;;
            --no-ignore-patterns        ) opt_no_ignore_patterns=true   ; shift   ;;
            --now                       ) opt_now="$2"                  ; shift 2 ;;
            --no-purge-diff             ) opt_no_purge_diff=true        ; shift   ;;
            --no-purge-number           ) opt_no_purge_number=true      ; shift   ;;
            --no-defaults-copy          ) opt_no_defaults_copy=true     ; shift   ;;
            --initramfs                 ) opt_initramfs=true            ; shift   ;;
            --systemd                   ) opt_systemd=true              ; shift   ;;
            --format-gui                ) opt_format_gui=true           ; shift   ;;
            -- ) shift; break ;;
            *  ) break ;;
        esac
    done

    # display help about configuration
    if bool "$opt_help_conf"; then
        help_conf
        exit 0
    fi

    # display help
    if bool "$opt_help" || [ "$1" = '' ] || [ "$1" = 'help' ]; then
        usage
        exit 0
    fi

    # display version
    if bool "$opt_version"; then
        usage_version
        exit 0
    fi

    # ensure --initramfs and --systemd are not specified simultaneously
    if bool "$opt_initramfs" && bool "$opt_systemd"; then
        "$fun_fatal_error" "$(__ "options '%s' and '%s' can not be specified simultaneously" \
                            '--initramfs' '--systemd')"
    fi

    # arguments
    arg_command="$1"
    [ "$#" -le 0 ] || shift

    debug ""
    debug "Command: '%s'" "$arg_command"
    debug ""
    debug "Options:"
    for opt in global_config config date force_deletion help moment keep_mounted \
            no_purge_diff no_purge_number safe now suffix from_toplevel_subvol \
            no_defaults_copy skip_free_space
    do
        _cli_opt="--$(echo "$opt" | sed 's/_/-/g')"
        _var_name="\$opt_$opt"
        _var_value="$(eval echo "$_var_name")"
        if [ "$_var_value" != '' ] && [ "$_var_value" != 'false' ]; then
            debug "  %s: '%s'" "$_cli_opt" "$_var_value"
        fi
    done
    debug ""

    # check options
    if [ "$opt_date" != '' ] && ! echo "$opt_date" | grep -q "^${DATE_STD_REGEX}$"; then
        "$fun_fatal_error" "$(__ "invalid value '%s' for option %s" "$opt_date" '--date')"
    fi
    if [ "$opt_moment" != '' ] && ! echo "$opt_moment" | \
        grep -q '^\(boot\|suspend\|resume\|reboot\|shutdown\|halt\)$'
    then
        "$fun_fatal_error" "$(__ "invalid value '%s' for option %s" "$opt_moment" '--moment')"
    fi
    if [ "$opt_now" != '' ] && ! echo "$opt_now" | grep -q "^${DATE_STD_REGEX}$"; then
        "$fun_fatal_error" "$(__ "invalid value '%s' for option %s" "$opt_now" '--now')"
    fi
    if [ "$opt_suffix" != '' ] && ! echo "$opt_suffix" | grep -q '^[a-zA-Z0-9_@.-]\+$'; then
        "$fun_fatal_error" "$(__ "invalid value '%s' for option %s" "$opt_suffix" '--suffix')"
    fi
    if ! echo "$arg_command" | grep -q '^\(rm\|del\|remove\|delete\)$'; then
        opt_force_deletion=false
    fi

    # initramfs context and helper functions script is readable
    if bool "$opt_initramfs" && [ -r "$INITRAMFS_HELPER_SCRIPT" ]; then
        debug "Sourcing helper function from '$INITRAMFS_HELPER_SCRIPT'"
        # shellcheck disable=SC1090
        . "$INITRAMFS_HELPER_SCRIPT"

        # update functions references to use those from the helper script
        fun_fatal_error='panic'
        fun_warning='log_warning_msg'
        debug ""
    fi

    # systemd context and helper functions script is readable
    if bool "$opt_systemd" && [ -r "$SYSTEMD_HELPER_SCRIPT" ]; then
        debug "Sourcing helper function from '$SYSTEMD_HELPER_SCRIPT'"
        # shellcheck disable=SC1090
        . "$SYSTEMD_HELPER_SCRIPT"

        # update functions references to use those from the helper script
        fun_fatal_error='systemd_panic'
        fun_warning='log_warning_msg'
        debug ""
    fi

    # ensure required binaries are ok
    ensure_required_bin

    # loading configuration
    CONFIG_GLOBAL="$DEFAULT_CONFIG_GLOBAL"
    if [ "$opt_global_config" != '' ]; then
        CONFIG_GLOBAL="$opt_global_config"
    fi
    if [ ! -r "$CONFIG_GLOBAL" ]; then
        "$fun_fatal_error" "$(__ "configuration file '%s' doesn't exist or isn't readable" "$CONFIG_GLOBAL")"
    fi
    debug "Global configuration: '%s'" "$CONFIG_GLOBAL"
    # shellcheck disable=SC1090
    . "$CONFIG_GLOBAL"


    # local configuration overrides
    if [ "$LOCAL_CONF" = '' ]; then
        LOCAL_CONF="$DEFAULT_CONFIG_LOCAL"
    fi
    if [ "$LOCAL_CONF" != '' ]; then
        if [ "$opt_from_toplevel_subvol" != '' ] && [ "$LOCAL_CONF_FROM_TOPLEVEL_SUBVOL" != '' ]; then
            debug "Option '%s' given and LOCAL_CONF from toplevel subvolume is '%s'" \
                '--from-toplevel-subvol' "$LOCAL_CONF_FROM_TOPLEVEL_SUBVOL"
            LOCAL_CONF="$(path_join "$opt_from_toplevel_subvol" "$LOCAL_CONF_FROM_TOPLEVEL_SUBVOL")"
        fi
        if [ -r "$LOCAL_CONF" ]; then
            debug "Local configuration '%s'" "$LOCAL_CONF"
            # shellcheck disable=SC1090
            . "$LOCAL_CONF"
        fi
    fi

    # ensure global configuration variables are valid/sane
    ensure_valid_global_config

    # configurations directory
    if [ "$CONFIGS_DIR" = '' ]; then
        CONFIGS_DIR="$DEFAULT_CONFIGS_DIR"
    fi
    if [ "$opt_from_toplevel_subvol" != '' ] && [ "$CONFIGS_DIR_FROM_TOPLEVEL_SUBVOL" != '' ]; then
        debug "Option '%s' given and CONFIGS_DIR from toplevel subvolume is '%s'" \
            '--from-toplevel-subvol' "$CONFIGS_DIR_FROM_TOPLEVEL_SUBVOL"
        CONFIGS_DIR="$(path_join "$opt_from_toplevel_subvol" "$CONFIGS_DIR_FROM_TOPLEVEL_SUBVOL")"
    elif [ "$opt_from_toplevel_subvol" != '' ]; then
        "$fun_fatal_error" "$(__ "configurations directory is not defined (use variable '%s')" \
            'CONFIGS_DIR_FROM_TOPLEVEL_SUBVOL')"
    fi
    debug "Configurations directory: '%s'" "$CONFIGS_DIR"
    debug ''

    # ensure the configurations directory exists (for the commands that require it)
    if [ ! -d "$CONFIGS_DIR" ]; then
        if ! echo "$arg_command" | grep -q '^\(list|ls\).*$|'; then
            debug "Creating configurations directory"
            # shellcheck disable=SC2174
            mkdir -m "$MODE_DIR_CREATED" -p "$CONFIGS_DIR"
        else
            "$fun_warning" "$(__ "no configurations directory at '%s'" "$CONFIGS_DIR")"
            exit 0
        fi
    fi

    # get the function name to call
    func_name=
    case "$arg_command" in
        backup|create|save|add|bak|new)       func_name=cmd_backup       ;;
        restore|rest|rollback|roll)           func_name=cmd_restore      ;;
        delete|del|remove|rm)                 func_name=cmd_delete       ;;
        new-conf|create-conf|add-conf)        func_name=cmd_add_conf     ;;
        ls-conf|list-conf)                    func_name=cmd_list_conf    ;;
        ls|list|list-savepoints|list-backups) func_name=cmd_list         ;;
        prune|rotate|rot|purge)               func_name=cmd_prune        ;;
        replace-diff|purge-diff)              func_name=cmd_purge_diff   ;;
        rotate-number|purge-number)           func_name=cmd_purge_number ;;
        log|log-print|log-read)               func_name=cmd_log_read     ;;
        log-add|log-write)                    func_name=cmd_log_write    ;;
        diff)                                 func_name=cmd_diff         ;;
        subvol-diff|subvolume-diff|sub-diff)  func_name=cmd_subvol_diff  ;;
        *) "$fun_fatal_error" "$(__ "invalid command '%s'" "$arg_command")" ;;
    esac

    # for commands that requires the persistent log to be available
    case "$func_name" in
        cmd_list_conf|cmd_add_conf|cmd_diff|cmd_subvol_diff) ;;
        *)

            # ensure persistent log file is defined and exists
            if [ "$opt_from_toplevel_subvol" != '' ] && \
                    [ "$PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL" != '' ]; then
                debug "Option '%s' given and PERSISTENT_LOG from toplevel subvolume is '%s'" \
                    '--from-toplevel-subvol' "$PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL"
                PERSISTENT_LOG="$(path_join "$opt_from_toplevel_subvol" \
                                            "$PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL")"
            elif [ "$opt_from_toplevel_subvol" != '' ]; then
                "$fun_fatal_error" "$(__ "persistent log is not defined (use variable '%s')" \
                    'PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL')"
            fi
            if [ -e "$PERSISTENT_LOG" ]; then
                log_dir="$(dirname "$PERSISTENT_LOG")"
                if [ ! -d "$log_dir" ]; then
                    debug "Creating persistent log parent dir '%s'" "$log_dir"
                    # shellcheck disable=SC2174
                    mkdir -m "$MODE_DIR_CREATED" -p "$log_dir"
                fi
                debug "Creating persistent log file '%s'" "$PERSISTENT_LOG"
                touch "$PERSISTENT_LOG"
            fi
        ;;
    esac

    # for commands that might have a specific configuration to process
    conf_selected="$opt_config"
    case "$func_name" in
        cmd_restore|cmd_delete|cmd_diff|cmd_subvol_diff)

            # if a configuration has been specified, store it
            if [ "$1" != '' ]; then
                conf_selected="$1"
                debug "Selected configuration '%s' for command '%s'" \
                    "$conf_selected" "$func_name"
                shift
                debug '%s' ''

            # no configuration provided
            else
                "$fun_fatal_error" "$(__ "The command '%s' requires a configuration" \
                    "$arg_command")"
            fi
        ;;
    esac
    if [ "$conf_selected" != '' ]; then
        conf_selected="$CONFIGS_DIR"/${conf_selected}.conf
    fi

    case "$func_name" in

        # for commands that don't depends on individual configuration
        cmd_add_conf|cmd_log_read|cmd_log_write)

            # process the config according to command
            "$func_name" "$@"
            ;;

        # for commands that will iterate over each configuration
        *)

        # get the list of configs to process
        conf_list="$conf_selected"
        if [ "$conf_list" = '' ]; then
            conf_list="$(get_config_list || true)"
            if [ "$conf_list" = '' ]; then
                "$fun_warning" \
                    "$(__ "no configuration yet.") "`
                    `"$(__ "You might want to create one with command '%s'" 'create-conf')"
                exit 0
            fi
        fi

        # flag the last config of the list
        _is_last_config=false
        _last_config_item="$(echo "$conf_list" | tail -n 1)"

        # for each configs
        echo "$conf_list" | while read -r conf_path; do

            # if the configuration do not exist
            if [ ! -r "$conf_path" ]; then
                "$fun_fatal_error" "$(__ "configuration not found ('%s' doesn't exist)" \
                    "$conf_path")"
            fi

            # last config item ?
            if [ "$conf_path" = "$_last_config_item" ]; then
                _is_last_config=true
            fi

            # set the configuration name
            NAME="$(basename "$conf_path" '.conf')"
            debug ""
            debug " - %s (%s)" "$NAME" "$conf_path"

            # ensure configuration's name is valid
            if ! is_conf_name_valid "$NAME"; then
                "$fun_fatal_error" "$(__ "invalid configuration's name '%s'" "$NAME")"
            fi

            # use a subshell to not retain configuration of savepoint from one to the next
            (
                # load the configuration
                # shellcheck disable=SC1090
                . "$conf_path"

                # ensure configuration variables are valid/sane
                debug ""
                debug "   configuration variables :"
                for var in SUBVOLUME SUBVOLUME_FROM_TOPLEVEL_SUBVOL \
                        SAVEPOINTS_DIR_BASE SAVEPOINTS_DIR_BASE_FROM_TOPLEVEL_SUBVOL \
                        BACKUP_BOOT BACKUP_REBOOT BACKUP_SHUTDOWN BACKUP_HALT \
                        BACKUP_SUSPEND BACKUP_RESUME SUFFIX_BOOT SUFFIX_REBOOT SUFFIX_SHUTDOWN \
                        SUFFIX_HALT SUFFIX_SUSPEND SUFFIX_RESUME SAFE_BACKUP KEEP_NB_SESSIONS \
                        KEEP_NB_MINUTES KEEP_NB_HOURS KEEP_NB_DAYS KEEP_NB_WEEKS KEEP_NB_MONTHS \
                        KEEP_NB_YEARS DIFF_IGNORE_PATTERNS HOOK_BEFORE_BACKUP HOOK_AFTER_BACKUP \
                        HOOK_BEFORE_RESTORE HOOK_AFTER_RESTORE HOOK_BEFORE_DELETE HOOK_AFTER_DELETE \
                        NO_PURGE_DIFF NO_PURGE_NUMBER PURGE_NUMBER_NO_SESSION
                do
                    eval _var_value="\$$var"
                    if [ "$_var_value" != '' ]; then
                        debug "     %s: '%s'" "$var" "$_var_value"
                        case "$var" in
                            KEEP_NB_*) ensure_positive_number "$_var_value" "$var" ;;
                            BACKUP_*|NO_PURGE_*|PURGE_NUM*) ensure_boolean "$_var_value" "$var" ;;
                        esac
                    elif [ "$var" = 'SUBVOLUME' ] || [ "$var" = 'SUBVOLUME_FROM_TOPLEVEL_SUBVOL' ]
                    then
                        "$fun_fatal_error" "$(__ "Configuration variables '%s' must be defined." \
                            "$var")"
                    fi
                done
                debug ""

                _ind='   '
                sp_base_dir="$(get_opt_or_var_value 'SAVEPOINTS_DIR_BASE')"
                if [ "$opt_from_toplevel_subvol" != '' ]; then
                    sp_base_dir="$(get_opt_or_var_value 'SAVEPOINTS_DIR_BASE_FROM_TOPLEVEL_SUBVOL')"
                    if [ "$sp_base_dir" != '' ]; then
                        debug "${_ind}Option '%s' given and SAVEPOINTS_DIR from toplevel subvolume is '%s'" \
                            '--from-toplevel-subvol' "$sp_base_dir"
                        sp_base_dir="$(path_join "$opt_from_toplevel_subvol" \
                                                "$sp_base_dir")"
                    else
                        "$fun_fatal_error" "$(__ "savepoints dir is not defined (use variable '%s')" \
                            'SAVEPOINTS_DIR_BASE_FROM_TOPLEVEL_SUBVOL')"
                    fi
                elif [ "$sp_base_dir" = '' ]; then
                    "$fun_fatal_error" "$(__ "savepoints dir is not defined (use variable '%s')" \
                        'SAVEPOINTS_DIR_BASE')"
                fi

                SAVEPOINTS_DIR="$(path_join "$sp_base_dir" "$NAME")"
                debug "${_ind}savepoints dir: '%s'" "$SAVEPOINTS_DIR"

                # process the config according to command
                "$func_name" "$@"
            )
        done
        ;;
    esac
    debug ""
}


# if called like a binary (without NO_MAIN=true)
if ! bool "$NO_MAIN"; then

    # run the main process
    main "$@"
fi

# vim: set ts=4 sw=4 et mouse=
