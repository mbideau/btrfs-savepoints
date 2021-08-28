#!/bin/sh
#
# systemd script that use btrfs-sp to create a savepoint at shutdown|reboot|halt
#
# Standards in this script:
#   POSIX compliance:
#      - http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#      - https://www.gnu.org/software/autoconf/manual/autoconf.html#Portable-Shell
#   CLI standards:
#      - https://www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces
#
# Source code, documentation and support:
#   https://github.com/mbideau/btrfs-sp
#
# Copyright (C) 2020 Michael Bideau [France]
#
# This file is part of btrfs-sp.
#
# btrfs-sp is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# btrfs-sp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with btrfs-sp. If not, see <https://www.gnu.org/licenses/>.
#

# install it to: '/lib/systemd/system-shutdown/btrfs-sp.shutdown'
# then reload the systemd daemon with: 'systemctl daemon-reload'
# after reboot: check that 'btrfs-sp ls' is showing a new savepoint


# halt on first error
set -e

# systemd LSB helper function
SYSTEMD_HELPER_SCRIPT=/lib/lsb/init-functions

# configuration
BTRFS_SP_CONFIG_PATH=/etc/btrfs-sp/systemd-shutdown.conf

# technical vars
MSG_DATETIME_FORMAT='%Y-%m-%d %H:%M:%S '
THIS_SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# program name
PROGRAM_NAME=btrfs-sp-systemd-script


# functions

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

# display a message to STDERR
msg()
{
    if [ "$#" -gt 0 ]; then
        _dt=
        if [ -n "$MSG_DATETIME_FORMAT" ]; then
            _dt="$(date "+$MSG_DATETIME_FORMAT")"
        fi
        if [ "$#" -gt 1 ]; then
            _fmt="$1"
            shift
        else
            _fmt='%s'
        fi
        # shellcheck disable=SC2059
        printf "%s$_fmt\n" "$_dt" "$@" >&2
    fi
}

# display a debug message to STDERR (if debuging is enabled)
debug()
{
    if [ "$DEBUG" = 'true' ] || [ "$DEBUG" = 'btrfs-sp' ]; then
        msg "$@" 2>&1 | sed 's/^/[DEBUG] /g' >&2
    fi
}

# fatal error function for systemd LSB
# because none exists
systemd_panic()
{
    # shellcheck disable=SC2059
    _msg="$(printf "$@")"
    echo "$_msg" >&2
    log_failure_msg "$_msg"
    exit 1
}

# mounting BTRFS top level subvolume
#
# @param  $1  string  path where to mount the BTRFS top level subvolume
# @param  $2  string  path of a directory in a mounted subvolume that will allow
#                     to extract mount parameters to mount its toplevel subvolume
#
mount_toplevel_subvol()
{
    # if the BTRFS top level subvolume is not already mounted
    if ! LC_ALL=C mount | grep -q " on $1 "; then
        debug "BTRFS top level subvolume is not already mounted"

        # ensure rootfs is mounted
        _mnt_line="$(LC_ALL=C mount | grep "^.* on / " || true)"
        debug "Mount line of rootfs '%s' is: '%s'" '/' "$_mnt_line"
        if [ "$_mnt_line" = '' ]; then
            systemd_panic "Fatal error: failed to get mount line for rootfs '%s'" '/'
        fi

        # ensure the filesystem of the rootfs is BTRFS
        if ! echo "$_mnt_line" | grep -q "^.* on / type btrfs"; then
            systemd_panic "*Fatal error: rootfs '%s' is not a BTRFS filesystem\n" '/'
        fi
        debug "Filesystem of rootfs '%s' is: '%s'" '/' 'btrfs'

        # get the mount options
        _mnt_opts="$(echo "$_mnt_line" \
                    |sed "s#^.* on / type btrfs (\\([^)]\+\\))\$#\\1#g")"
        if [ "$_mnt_opts" = '' ]; then
            systemd_panic "Fatal error: failed to get the mount options of rootfs '%s'\n" '/'
        fi
        debug "Mount options of rootfs '%s' are: '%s'" '/' "$_mnt_opts"

        # ensure mount options have the 'subvol' or 'subvolid' parameter
        if ! echo "$_mnt_opts" | grep -q '\(^\|,\)subvol\(id\)\?='; then
            systemd_panic "Fatal error: mount options of rootfs '%s' "`
                          `"do not have parameter 'subvol' or 'subvolid'\n" '/'
        fi

        # replace the 'subvol' value option with '/' and 'subvolid' with '5', and delete 'ro'
        _mnt_opts="$(echo "$_mnt_opts" \
                    |sed 's/\(^\|,\)ro\(,\|$\)//' \
                    |sed 's/\(^\|,\)subvol=[^,]\+\(,\|$\)/\1subvol=\/\2/g' \
                    |sed 's/\(^\|,\)subvolid=[^,]\+\(,\|$\)/\1subvolid=5\2/g')"
        debug "Mount options of the BTRFS top level subvolume will be : '%s'" "$_mnt_opts"

        # get the mount device mappers
        _mnt_dm="$(echo "$_mnt_line" \
                  |sed "s#^\\(.*\\) on / type btrfs .*#\\1#g")"
        if [ "$_mnt_dm" = '' ]; then
            systemd_panic "Fatal error: failed to get the mount devices of rootfs '%s'\n" '/'
        fi
        debug "Mount devices of rootfs '%s' are: '%s'" '/' "$_mnt_dm"

        # ensure rootfs exists
        if [ ! -d "$1" ]; then
            debug "Creating directory '%s'" "$1"
            # shellcheck disable=SC2174
            mkdir -m 0770 -p "$1"
        fi

        # mount the BTRFS top level subvolume
        debug "Mounting the BTRFS top level subvolume to '%s'" "$1"
        if ! mount -t btrfs -o "$_mnt_opts" "$_mnt_dm" "$1"; then
            systemd_panic "Fatal error: failed to mount the BTRFS top level subvolume to '%s'\n" \
                "$1"
        fi
    else
        debug "Top level BTRFS filesystem is already mounted at '%s'" "$1"
    fi
}

# write the log to persistent storage
log_write_to_persistent_storage()
{
    # write the log file to root fs (if asked)
    if [ "$LOG_FILE_DEST_REL" != '' ]; then
        debug "User asked to write log file to permanent fs" 2>>"$LOG_FILE_TMP"

        # BTRFS top level is mounted
        if LC_ALL=C mount | grep -q " on $TOPLEVEL_SUBVOL_MNT "
        then
            debug "BTRFS top level '$TOPLEVEL_SUBVOL_MNT' is mounted" 2>>"$LOG_FILE_TMP"

            # create the log dir
            _log_path="$TOPLEVEL_SUBVOL_MNT/$(echo "$LOG_FILE_DEST_REL" | sed 's/^\/*//g')"
            _log_dir="$(dirname "$_log_path")"
            if [ ! -d "$_log_dir" ]; then
                debug "Creating directory '$_log_dir'" 2>>"$LOG_FILE_TMP"
                # shellcheck disable=SC2174
                mkdir -m "0770" -p "$_log_dir"
            fi

            # append the current log to the log file on root fs
            debug "Appending content of log file '$LOG_FILE_TMP' to the permanent fs one "`
                `"'$_log_path'" 2>>"$LOG_FILE_TMP"
            echo >> "$_log_path"
            cat "$LOG_FILE_TMP" >> "$_log_path"

        else
            debug "not moving log file to permanent fs because BTRFS top level is not mounted "`
                    `"(to '$TOPLEVEL_SUBVOL_MNT')" 2>>"$LOG_FILE_TMP"
        fi
    fi
}

# unmount BTRFS top level subvolume
unmount_toplevel_subvol()
{
    # unmount the BTRFS top level (mounted by 'btrfs-sp create')
    # shellcheck disable=SC1090
    if LC_ALL=C mount | grep -q " on $TOPLEVEL_SUBVOL_MNT "; then
        debug "Unmouting BTRFS top level mounted at '$TOPLEVEL_SUBVOL_MNT'" 2>>"$LOG_FILE_TMP"
        umount "$TOPLEVEL_SUBVOL_MNT"
    else
        debug "BTRFS top level is not mounted at '$TOPLEVEL_SUBVOL_MNT'" 2>>"$LOG_FILE_TMP"
    fi
}

# clean stop this program
do_clean_stop()
{
    # write the log to persistent storage
    log_write_to_persistent_storage

    # unmount BTRFS top level subvolume
    unmount_toplevel_subvol

    # unmount temporary /tmp
    if [ "$mounted_tmp" = 'true' ]; then
        umount /tmp
    fi
}


# including the systemd LSB helper functions
if [ -r "$SYSTEMD_HELPER_SCRIPT" ]; then
    # shellcheck disable=SC1090
    . "$SYSTEMD_HELPER_SCRIPT"
fi


# main program

# first and single argument is the name of the action (halt|poweroff|reboot|kexec)
# @see: https://www.freedesktop.org/software/systemd/man/systemd-halt.service.html
action="$1"

# setup a trap to umount BTRFS top level filesystem when exiting
# shellcheck disable=SC2064
trap "do_clean_stop" INT QUIT ABRT TERM EXIT

# mount a temporary filesystem in RAM on /tmp, to be able to save our log file
mounted_tmp=false
if ! mount | grep ' on /tmp '; then
    # see: https://unix.stackexchange.com/a/55776
    mount -o mode=1777,nosuid,nodev -t tmpfs tmpfs /tmp >/dev/null
    mounted_tmp=true
fi

# sourcing the configuration
if [ -r "$BTRFS_SP_CONFIG_PATH" ]; then
    # shellcheck disable=SC1090
    . "$BTRFS_SP_CONFIG_PATH"
fi

# set rootfs mount point
if [ "$TOPLEVEL_SUBVOL_MNT" = '' ]; then
    TOPLEVEL_SUBVOL_MNT='/tmp/btrfs_toplevel_subvol'
fi

# use a subshell to capture output to a log file
LOG_FILE_TMP="$(mktemp "/tmp/$(basename "$0").log.XXXXXXXXXX")"
{
    # if the action is not kexec nor halt
    if [ "$action" != 'kexec' ]; then

        # if the binary is found
        if command -v btrfs-sp >/dev/null; then

            # setup language
            setup_language
            debug "Language: LANGUAGE='%s', LC_ALL='%s', LANG='%s', TEXTDOMAINDIR='%s'" \
                "$LANGUAGE" "$LC_ALL" "$LANG" "$TEXTDOMAINDIR"

            # mount the BTRFS top level subvolume
            mount_toplevel_subvol "$TOPLEVEL_SUBVOL_MNT"

            # create a savepoint (backup)
            msg "Creating a new savepoint (snapshoting the system state) ..."
            moment=halt
            safe_opt=
            case $action in
                reboot)   moment=reboot  ; safe_opt='--safe' ;;
                poweroff) moment=shutdown; safe_opt='--safe' ;;
            esac
            if _out="$(btrfs-sp create \
                --from-toplevel-subvol "$TOPLEVEL_SUBVOL_MNT" \
                --moment "$moment" \
                $safe_opt \
                --systemd)"
            then
                debug "Savepoint created"
                if command -v plymouth >/dev/null 2>&1 && plymouth --ping >/dev/null; then
                    _ply_msg="$(__ "BTRFS SavePoint created")
$(echo "$_out" | tr '\n' ' ')"
                    debug "Sending a message to plymouth"
                    plymouth display-message --text="$_ply_msg" || true
                    # let some time for the user to see the plymouth message, before shutdown
                    sleep 3
                fi
            else
                debug "Failed to create savepoint"
                if command -v plymouth >/dev/null 2>&1 && plymouth --ping >/dev/null; then
                    _ply_msg="$(__ "               BTRFS SavePoint creation failed")"
                    if [ "$LOG_FILE_DEST_REL" != '' ]; then
                        _ply_msg="$_ply_msg

$(__ "               See log at : %s" "/$LOG_FILE_DEST_REL")"
                    fi
                    debug "Sending a message to plymouth"
                    plymouth display-message --text="$_ply_msg" || true
                fi
            fi
        else
            debug "binary 'btrfs-sp' not found"
        fi
    else
        debug "skip, when action is '$action'"
    fi
} 2>>"$LOG_FILE_TMP" || true
