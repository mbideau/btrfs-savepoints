# file meant to be included by other tests script

if [ "$BTRFSSP" = '' ]; then
    if ! BTRFSSP="$(command -v btrfs-sp 2>/dev/null)"; then
        if [ -e "$THIS_DIR/btrfs_sp.sh" ]; then
            BTRFSSP="$THIS_DIR/btrfs_sp.sh"
        fi
    fi
fi
if [ "$BTRFSSP" = '' ]; then
    echo "Fatal error: failed to find binary 'btrfs-sp'" >&2
    exit 1
elif [ ! -e "$BTRFSSP" ]; then
    echo "Fatal error: '$BTRFSSP' doesn't exist" >&2
    exit 1
elif [ ! -x "$BTRFSSP" ]; then
    echo "Fatal error: '$BTRFSSP' is not executable" >&2
    exit 1
fi

if [ "$SHUNIT2" = '' ]; then
    if ! SHUNIT2="$(command -v shunit2 2>/dev/null)"; then
        if [ -r "$(dirname "$THIS_DIR")/shunit2/shunit2" ]; then
            SHUNIT2="$(dirname "$THIS_DIR")/shunit2/shunit2"
        fi
    fi
fi
if [ "$SHUNIT2" = '' ]; then
    echo "Fatal error: failed to find shell script 'shunit2'" >&2
    exit 1
elif [ ! -e "$SHUNIT2" ]; then
    echo "Fatal error: '$SHUNIT2' doesn't exist" >&2
    exit 1
fi

# configuration of the test environment
if [ "$TMPDIR" = '' ]; then
    TMPDIR="$THIS_DIR"/.tmp
fi
remove_test_dir=false
if [ "$TEST_DIR" = '' ]; then
    TEST_DIR="$THIS_DIR"/testdir
fi

use_sudo=
if [ "$(id -u)" != '0' ]; then
    echo "Using sudo"
    use_sudo=sudo
fi

echo "Tmp directory: '$TMPDIR'"
[ ! -d "$TMPDIR" ] && mkdir -p "$TMPDIR"
$use_sudo chown "$USER" "$TMPDIR"
$use_sudo chmod u=rwx "$TMPDIR"

# conf
TEST_CONF_GLOBAL="$TEST_DIR"/test.conf
TEST_LOCAL_CONF="$TEST_DIR"/local.conf
TEST_CONFS_DIRS="$TEST_DIR"/conf.d
# shellcheck disable=SC2034
TEST_CONF_DATA="$TEST_CONFS_DIRS"/data.conf
TEST_PERSISTENT_LOG="$TEST_DIR"/test.log

TEST_SUBVOL_DIR_DATA="$TEST_DIR"/data
TEST_SUBVOL_DIR_BACKUPS="$TEST_DIR"/backups

# shellcheck disable=SC2034
TEST_DEFAULT_RETENTION_STRATEGY='4 3 4 12 2'
# shellcheck disable=SC2034
TEST_DEFAULT_RETENTION_STRATEGY_TEXT='4 SES, 0 MIN, 0 HOU, 3 DAY, 4 WEE, 12 MON, 2 YEA'


# helper functions

__debug()
{
    if [ "$DEBUG_TEST" = 'true' ]; then
        # shellcheck disable=SC2059
        printf "$@" | sed 's/^/[TEST DEBUG] /g' >&2
    fi
}

# return a random number
__get_random()
{
    # shellcheck disable=SC2039
    _rand="$RANDOM"
    if [ "$_rand" = '' ] && command -v shuf >/dev/null; then
        _rand="$(shuf --head-count=1 --input-range=0-999)"
    elif command -v od >/dev/null && [ -e /dev/random ]; then
        _rand="$(od -An -N1 -i /dev/random | sed 's/^\s\+//g')"
    fi
    echo "$_rand"
}

# concatenate two path components and ensure there is no double '/' in it
# @param  $1  string  first path component
# @param  $2  string  second path component
__path_join()
{
    if [ "$1" = '' ] && [ "$2" = '' ]; then
        true
    else
        echo "$1/$2" | sed 's|//*|/|g'
    fi
}

# create a global configuration
# @param  $1  int  retention for sessions
# @param  $2  int  retention for days
# @param  $3  int  retention for weeks
# @param  $4  int  retention for months
# @param  $5  int  retention for years
__create_global_conf()
{
    __debug "Creating a global configuration\n"
    cat > "$TEST_CONF_GLOBAL" <<ENDCAT
# test configuration for 'btrfs-sp'

# paths
LOCAL_CONF='$TEST_LOCAL_CONF'
CONFIGS_DIR='$TEST_CONFS_DIRS'
PERSISTENT_LOG='$TEST_PERSISTENT_LOG'
SP_DEFAULT_SAVEPOINTS_DIR_BASE='$TEST_SUBVOL_DIR_BACKUPS'

# free space requirements
ENSURE_FREE_SPACE_GB=0.0

# when it should be backuped
SP_DEFAULT_BACKUP_BOOT=yes
SP_DEFAULT_BACKUP_REBOOT=yes
SP_DEFAULT_BACKUP_SHUTDOWN=yes
SP_DEFAULT_BACKUP_HALT=no
SP_DEFAULT_BACKUP_SUSPEND=yes
SP_DEFAULT_BACKUP_RESUME=yes

# with what prefix/suffix
SP_DEFAULT_SUFFIX_BOOT=
SP_DEFAULT_SUFFIX_REBOOT=.reboot
SP_DEFAULT_SUFFIX_SHUTDOWN=.shutdown
SP_DEFAULT_SUFFIX_HALT=.halt
SP_DEFAULT_SUFFIX_SUSPEND=.suspend
SP_DEFAULT_SUFFIX_RESUME=.resume

# when it is considered a safe backup
SP_DEFAULT_SAFE_BACKUP=reboot,shutdown

# how much backup to keep
SP_DEFAULT_KEEP_NB_SESSIONS=$1
SP_DEFAULT_KEEP_NB_DAYS=$2
SP_DEFAULT_KEEP_NB_WEEKS=$3
SP_DEFAULT_KEEP_NB_MONTHS=$4
SP_DEFAULT_KEEP_NB_YEARS=$5
ENDCAT
}

# set configuration variable
#
# @param  $1  string  path of the configuration file
# @param  $2  string  variable name
# @param  $3  string  value
#
__set_config_var()
{
    if grep -q "^$2=" "$1"; then
        sed "s|$2=.*|$2='$3'|g" -i "$1"
    else
        echo "$2='$3'" >> "$1"
    fi
}

# create a change in the data (adding a file with a random name)
__change_data()
{
    echo "random content $(__get_random)" > "$TEST_SUBVOL_DIR_DATA/$(__get_random).txt"
}

# get the mount point of a path
#
# Note: its using 'df' with compatibility with the buged 'busybox' one
#
# @param  $1  string  path to get mount point from
#
__get_mount_point_for_path()
{
    [ "$1" != '' ] || return 1

    # go up/backup one directory at a time, as long as 'df' is failing
    _ref_path="$1"
    while ! df "$_ref_path" >/dev/null 2>&1 && [ "$_ref_path" != '/' ]; do
        _ref_path="$(dirname "$_ref_path")"
    done
    _df_out="$(LC_ALL=C df -P "$_ref_path" || true)"
    if [ "$_df_out" != '' ]; then
        _capacity_col_start="$(
            echo "$_df_out" | head -n 1 \
            |sed 's/^\(Filesystem \+.* \+Available\) \+Capacity .*/\1/' | wc -c)"
        echo "$_df_out" | tail -n +2 | cut -c "$_capacity_col_start"- \
            | sed -e 's/^ *[0-9.]\+% *//g' -e 's/^ *//g;s/ *$//g'
    else
        printf "Warning: failed to get mount point for '%s'\n" "$1" >&2
        return 1
    fi
}

# get the relative path to the mount point for the specified path
#
# @param  $1  string  path to get relative path from
# @param  $2  string  path to the matching mount point
#
__get_relative_path_from_mount_point()
{
    echo "$1" | sed -e "s|^$2||" -e 's|^//*|/|g'
}

# get mount point subvolume path
#
# @param  $1  string  path to a directory in the mounted subvolume from which you want the name
#
__get_mount_point_subvol()
{
    # get the mount point of the directory passed as second argument
    _mnt_point="$(__get_mount_point_for_path "$1" || true)"
    if [ "$_mnt_point" = '' ]; then
        printf "Error: failed to find the mount point of directory '%s'\n" "$1" >&2
        return 1
    fi
    __debug "Mount point of directory '%s' is: '%s'\n" "$1" "$_mnt_point"

    # for that mount point get the mount line (with devices and options)
    _mnt_line="$(LC_ALL=C mount | grep "^.* on $_mnt_point " || true)"
    if [ "$_mnt_line" = '' ]; then
        printf "Error: failed to find the mount line of mount point '%s'\n" "$_mnt_point" >&2
        return 1
    fi
    __debug "Mount line of mount point '%s' is: '%s'\n" "$_mnt_point" "$_mnt_line"

    # ensure the filesystem of the mount point is BTRFS
    if ! echo "$_mnt_line" | grep -q "^.* on $_mnt_point type btrfs"; then
        printf "Error: mount point '%s' is not a BTRFS filesystem\n" "$_mnt_point" >&2
        return 1
    fi
    __debug "Filesystem of mount point '%s' is: '%s'\n" "$_mnt_point" 'btrfs'

    # get the mount options
    _mnt_opts="$(echo "$_mnt_line" \
                |sed "s#^.* on $_mnt_point type btrfs (\\([^)]\+\\))\$#\\1#g")"
    if [ "$_mnt_opts" = '' ]; then
        printf "Error: failed to get the mount options of mount point '%s'\n" "$_mnt_point" >&2
        return 1
    fi
    __debug "Mount options of mount point '%s' are: '%s'\n" "$_mnt_point" "$_mnt_opts"

    # ensure mount options have the 'subvol' parameter
    if ! echo "$_mnt_opts" | grep -q '\(^\|,\)subvol='; then
        printf "Error: mount options of mount point '%s' "`
                `"do not have parameter 'subvol'\n" "$_mnt_point" >&2
        return 1
    fi

    # get the subvolume path
    echo "$_mnt_opts" | sed 's/.*\(^\|,\)subvol=\([^,]\+\).*$/\2/g'
}

# mounting BTRFS top level subvolume
#
# @param  $1  string  path where to mount the BTRFS top level subvolume
# @param  $2  string  path of a directory in a mounted subvolume that will allow
#                     to extract mount parameters to mount its toplevel subvolume
#
__mount_toplevel_subvol()
{
    # if the BTRFS top level subvolume is not already mounted
    if ! LC_ALL=C.UTF-8 mount | grep -q " on $1 "; then
        __debug "BTRFS top level subvolume is not already mounted\n"

        # get the mount point of the directory passed as second argument
        _mnt_point="$(__get_mount_point_for_path "$2" | head -n 1 || true)"
        if [ "$_mnt_point" = '' ]; then
            printf "Error: failed to find the mount point of directory '%s'\n" "$2" >&2
            return 1
        fi
        __debug "Mount point of directory '%s' is: '%s'\n" "$2" "$_mnt_point"

        # for that mount point get the mount line (with devices and options)
        _mnt_line="$(LC_ALL=C mount | grep "^.* on $_mnt_point " || true)"
        if [ "$_mnt_line" = '' ]; then
            printf "Error: failed to find the mount line of mount point '%s'\n" "$_mnt_point" >&2
            return 1
        fi
        __debug "Mount line of mount point '%s' is: '%s'\n" "$_mnt_point" "$_mnt_line"

        # ensure the filesystem of the mount point is BTRFS
        if ! echo "$_mnt_line" | grep -q "^.* on $_mnt_point type btrfs"; then
            printf "Error: mount point '%s' is not a BTRFS filesystem\n" "$_mnt_point" >&2
            return 1
        fi
        __debug "Filesystem of mount point '%s' is: '%s'\n" "$_mnt_point" 'btrfs'

        # get the mount options
        _mnt_opts="$(echo "$_mnt_line" \
                    |sed "s#^.* on $_mnt_point type btrfs (\\([^)]\+\\))\$#\\1#g")"
        if [ "$_mnt_opts" = '' ]; then
            printf "Error: failed to get the mount options of mount point '%s'\n" "$_mnt_point" >&2
            return 1
        fi
        __debug "Mount options of mount point '%s' are: '%s'\n" "$_mnt_point" "$_mnt_opts"

        # ensure mount options have the 'subvol' or 'subvolid' parameter
        if ! echo "$_mnt_opts" | grep -q '\(^\|,\)subvol\(id\)\?='; then
            printf "Error: mount options of mount point '%s' "`
                   `"do not have parameter 'subvol' or 'subvolid'\n" "$_mnt_point" >&2
            return 1
        fi

        # replace the 'subvol' value option with '/' and 'subvolid' with '5'
        _mnt_opts="$(echo "$_mnt_opts" \
                    |sed 's/\(^\|,\)subvol=[^,]\+\(,\|$\)/\1subvol=\/\2/g' \
                    |sed 's/\(^\|,\)subvolid=[^,]\+\(,\|$\)/\1subvolid=5\2/g')"
        __debug "Mount options of the BTRFS top level subvolume will be : '%s'\n" "$_mnt_opts"

        # get the mount device mappers
        _mnt_dm="$(echo "$_mnt_line" \
                  |sed "s#^\\(.*\\) on $_mnt_point type btrfs .*#\\1#g")"
        if [ "$_mnt_dm" = '' ]; then
            printf "Error: failed to get the mount devices of mount point '%s'\n" "$_mnt_point" >&2
            return 1
        fi
        __debug "Mount devices of mount point '%s' are: '%s'\n" "$_mnt_point" "$_mnt_dm"

        # ensure mount point exists
        if [ ! -d "$1" ]; then
            __debug "Creating directory '%s'\n" "$1"
            # shellcheck disable=SC2174
            mkdir -m 0770 -p "$1"
        fi

        # setup a trap to umount BTRFS top level filesystem when exiting
        __debug "Setup a trap to umount BTRFS top level filesystem when exiting\n"
        # shellcheck disable=SC2064
        trap "__unmount_toplevel_subvol '$1'" INT QUIT ABRT TERM EXIT

        # mount the BTRFS top level subvolume
        __debug "Mounting the BTRFS top level subvolume to '%s'\n" "$1"
        if ! mount -t btrfs -o "$_mnt_opts" "$_mnt_dm" "$1"; then
            printf "Error: failed to mount the BTRFS top level subvolume to '%s'\n" "$1">&2
            return 1
        fi
    else
        __debug "Top level BTRFS filesystem is already mounted at '%s'\n" "$1"
    fi
}

# unmounting BTRFS top level subvolume
#
# @param  $1  string  path where is mounted the BTRFS top level subvolume
#
__unmount_toplevel_subvol()
{
    if LC_ALL=C.UTF-8 mount | grep -q " on $1 "; then
        __debug "Unmounting top level BTRFS filesystem from '%s'\n" "$1"
        umount "$1"
    else
        __debug "Top level BTRFS filesystem is already unmounted from '%s'\n" "$1"
    fi
}



# shunit2 functions

__warn()
{
    # shellcheck disable=SC2154
    ${__SHUNIT_CMD_ECHO_ESC} "${__shunit_ansi_yellow}WARN${__shunit_ansi_none} $*" >&2
}

# initial setup
__oneTimeSetUp()
{
    # create the test directory
    if [ ! -d "$TEST_DIR" ]; then
        __debug "Creating directory: '$TEST_DIR'\n"
        mkdir "$TEST_DIR"
        remove_test_dir=true
    fi
    $use_sudo chown "$USER" "$TEST_DIR"
    $use_sudo chmod u=rwx "$TEST_DIR"

    # define the relatives paths from TEST_DIR mount point

    __debug "Getting mountpoint for TEST_DIR '%s'\n" "$TEST_DIR"
    _TEST_DIR_mnt="$(__get_mount_point_for_path "$TEST_DIR" || true)"
    if [ "$_TEST_DIR_mnt" = '' ]; then
        fail "getting the mount point of TEST_DIR '$TEST_DIR'"
        return 1
    fi
    __debug "TEST_DIR mount point: '%s'\n" "$_TEST_DIR_mnt"

    __debug "Getting subvolume mountpoint for TEST_DIR '%s'\n" "$TEST_DIR"
    if ! _TEST_DIR_subvol="$(__get_mount_point_subvol "$TEST_DIR")"
    then
        fail "getting path of TEST_DIR subvolume '$TEST_DIR'"
        return 1
    fi
    __debug "TEST_DIR subvolume path: '%s'\n" "$_TEST_DIR_subvol"

    # shellcheck disable=SC2034
    _rel_TEST_LOCAL_CONF="$(__path_join "$_TEST_DIR_subvol" \
        "$(__get_relative_path_from_mount_point "$TEST_LOCAL_CONF" "$_TEST_DIR_mnt")")"
    # shellcheck disable=SC2034
    _rel_TEST_CONFS_DIRS="$(__path_join "$_TEST_DIR_subvol" \
        "$(__get_relative_path_from_mount_point "$TEST_CONFS_DIRS" "$_TEST_DIR_mnt")")"
    # shellcheck disable=SC2034
    _rel_TEST_PERSISTENT_LOG="$(__path_join "$_TEST_DIR_subvol" \
        "$(__get_relative_path_from_mount_point "$TEST_PERSISTENT_LOG" "$_TEST_DIR_mnt")")"
    # shellcheck disable=SC2034
    _rel_TEST_SUBVOL_DIR_DATA="$(__path_join "$_TEST_DIR_subvol" \
        "$(__get_relative_path_from_mount_point "$TEST_SUBVOL_DIR_DATA" "$_TEST_DIR_mnt")")"
    # shellcheck disable=SC2034
    _rel_TEST_SUBVOL_DIR_BACKUPS="$(__path_join "$_TEST_DIR_subvol" \
        "$(__get_relative_path_from_mount_point "$TEST_SUBVOL_DIR_BACKUPS" "$_TEST_DIR_mnt")")"
}

# final tear down / cleanup
__oneTimeTearDown()
{
    # remove the tests dir
    if [ -d "$TEST_DIR" ] && [ "$remove_test_dir" = 'true' ]; then
        __debug "Removing directory: '%s'\\n" "$TEST_DIR"
        rmdir "$TEST_DIR"
    fi
}

# reset conf data and savepoints
__setUp()
{
    # create a subvolume dir for data
    __debug "   creating a subvolume for 'data'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_DATA" >/dev/null

    # put some files in it
    __debug "   initialising data\n"
    echo 'content1' > "$TEST_SUBVOL_DIR_DATA"/file1.txt
    echo 'content2' > "$TEST_SUBVOL_DIR_DATA"/file2.txt
    mkdir "$TEST_SUBVOL_DIR_DATA"/dir1
    echo 'content1.1' > "$TEST_SUBVOL_DIR_DATA"/dir1/file1.1.txt
    mkdir "$TEST_SUBVOL_DIR_DATA"/dir2
    echo 'content2.1' > "$TEST_SUBVOL_DIR_DATA"/dir2/file2.1.txt
}

__tearDown()
{
    # remove all the existing/previous savepoints
    if [ -d "$TEST_SUBVOL_DIR_BACKUPS" ]; then
        __debug "   removing all the existing/previous savepoints\n"
        if [ -d "$TEST_SUBVOL_DIR_BACKUPS"/data ]; then
            __debug "      using find command to delete symlinks and subvolumes\n"
            find "$TEST_SUBVOL_DIR_BACKUPS"/data -maxdepth 1 -type l \
                -not -path "$TEST_SUBVOL_DIR_BACKUPS"/data -exec rm -f '{}' \;
            find "$TEST_SUBVOL_DIR_BACKUPS"/data -maxdepth 1 -type d \
                -not -path "$TEST_SUBVOL_DIR_BACKUPS"/data \
                -exec btrfs subvolume delete --commit-after '{}' \; >/dev/null
            __debug "      removing the 'data' backup dir\n"
            rmdir "$TEST_SUBVOL_DIR_BACKUPS"/data
        fi
        __debug "      removing the 'backups' subvolume\n"
        btrfs subvolume delete --commit-after "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null
    fi

    # remove all the existing/previous data
    if [ -d "$TEST_SUBVOL_DIR_DATA" ]; then
        __debug "   removing the 'data' subvolume\n"
        btrfs subvolume delete --commit-after "$TEST_SUBVOL_DIR_DATA" >/dev/null
    fi

    # remove all the existing/previous configuration
    if [ -d "$TEST_CONFS_DIRS" ]; then
        __debug "   removing all the existing/previous configuration\n"
        rm -fr "$TEST_CONFS_DIRS"
    fi

    # remove the log file
    if [ -e "$TEST_PERSISTENT_LOG" ]; then
        __debug "   removing the log file '$TEST_PERSISTENT_LOG'\n"
        rm -f "$TEST_PERSISTENT_LOG"
    fi

    # remove the global configuration file
    if [ -e "$TEST_CONF_GLOBAL" ]; then
        __debug "   removing the global configuration file '$TEST_CONF_GLOBAL'\n"
        rm -f "$TEST_CONF_GLOBAL"
    fi

    # remove any temp file
    # shellcheck disable=SC2154
    if [ "$_tmp" != '' ] && [ -e "$_tmp" ]; then
        rm -f "$_tmp"
    fi
}
