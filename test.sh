#!/bin/sh

set -e

THIS_DIR="$(dirname "$(realpath "$0")")"

# create the tests directory
DIR_TEST="$THIS_DIR/tests"

# conf
TEST_CONF_GLOBAL="$DIR_TEST"/test.conf
TEST_CONFS_DIRS="$DIR_TEST"/conf.d
TEST_CONF_DATA="$TEST_CONFS_DIRS"/data.conf

TEST_SUBVOL_DIR_DATA="$DIR_TEST"/data
TEST_SUBVOL_DIR_BACKUPS="$DIR_TEST"/backups

TREE_VIEW_DATA_EXPECTED=/tmp/data_expected
TREE_VIEW_DATA_PRODUCED=/tmp/data_produced
TREE_VIEW_BACKUPS_EXPECTED=/tmp/backups_expected
TREE_VIEW_BACKUPS_PRODUCED=/tmp/backups_produced

DATE_TEXT_FORMAT='+%Y-%m-%d_%Hh%Mm%S'
DATE_STD_FORMAT='+%Y-%m-%d %H:%M:%S'

debug()
{
    if [ "$DEBUG_TEST" = 'true' ]; then
        # shellcheck disable=SC2059
        printf "$@" | sed 's/^/[TEST DEBUG] /g' >&2
    fi
}

# return a date to the format : Y-m-d_HhMmS
get_date_to_text()
{
    date -d "$1" "$DATE_TEXT_FORMAT"
}

# return a date with the format: Y-m-d H:M:S
# from a date with the format  : Y-m-d_HhMmS
# @param  $1  string  the date to convert from
get_date_from_text()
{
    date -d "$(echo "$1" | sed -e 's/_/ /g' -e 's/[hm]/:/g')" "$DATE_STD_FORMAT"
}

# return a date from the initial date plus X hours
get_initial_date_plus_hours()
{
    get_date_plus_hours "$INITIAL_DATE" "$1"
}

# return a date from the initial date plus X days
get_initial_date_plus_days()
{
    if [ "$1" -gt 29 ]; then
        echo "Fatal error: you can add up to 29 days, not '$1' (to initial date)" >&2
        exit 1
    fi
    get_date_from_text "$(echo "$INITIAL_DATE_TEXT" | sed "s/-01_/-$(echo "$(($1 + 1))" | sed 's/^\([0-9]\)$/0\1/')_/")"
}

# return a date from the initial date minus X years
get_initial_date_minus_years()
{
    get_date_minus_years "$INITIAL_DATE_TEXT" "$1"
}

# return a date from the specified date plus X hours
get_date_plus_hours()
{
    if [ "$2" -gt 23 ]; then
        echo "Fatal error: you can add up to 23 hours, not '$2" >&2
        exit 1
    fi
    get_date_from_text "$(echo "$1" | sed "s/ [0-9]\{2\}:/ $(echo "$2" | sed 's/^\([0-9]\)$/0\1/'):/")"
}

# return a date from the specified date minus X years
get_date_minus_years()
{
    get_date_from_text "$(echo "$1" | sed "s/^[0-9]\{4\}-/$(($(echo "$1" | sed 's/^\([0-9]\{4\}\)-.*$/\1/') - $2))-/")"
}

# change retention strategy
# @param  $1  int  retention for sessions
# @param  $2  int  retention for days
# @param  $3  int  retention for weeks
# @param  $4  int  retention for months
# @param  $5  int  retention for years
change_retention()
{
    sed -i "$TEST_CONF_DATA" \
        -e "s/\\(KEEP_NB_SESSIONS\\)=.*/\1=$1/g" \
        -e "s/\\(KEEP_NB_DAYS\\)=.*/\1=$2/g" \
        -e "s/\\(KEEP_NB_WEEKS\\)=.*/\1=$3/g" \
        -e "s/\\(KEEP_NB_MONTHS\\)=.*/\1=$4/g" \
        -e "s/\\(KEEP_NB_YEARS\\)=.*/\1=$5/g"
}

# produce tree views for data/backups and compare them to the one provided
# @param  $1  string  name of the test (to display FAIL or PASS message)
# @param  $2  string  if '--compare-data-too' also compare data
produce_tree_and_check_it()
{
    debug "comparing results (trees) for test: $1\n"
    trees_matches=true

    # compare data (only if asked explicitly)
    if [ "$2" = '--compare-data-too' ]; then
        tree -L 2 -n --noreport "$TEST_SUBVOL_DIR_DATA" >"$TREE_VIEW_DATA_PRODUCED"
        if ! diff -q "$TREE_VIEW_DATA_EXPECTED" "$TREE_VIEW_DATA_PRODUCED" >/dev/null; then
            trees_matches=false
            echo "FAIL: $1 (data tree differs)"
            debug "EXPECTED\n"
            debug '%s\n' "$(cat "$TREE_VIEW_DATA_EXPECTED")"
            debug "PRODUCED\n"
            debug '%s\n' "$(cat "$TREE_VIEW_DATA_PRODUCED")"
        fi
    fi

    # compare savepoints
    tree -L 2 -n -r --noreport "$TEST_SUBVOL_DIR_BACKUPS" >"$TREE_VIEW_BACKUPS_PRODUCED"
    if ! diff -q "$TREE_VIEW_BACKUPS_EXPECTED" "$TREE_VIEW_BACKUPS_PRODUCED" >/dev/null; then
        trees_matches=false
        echo "FAIL: $1 (backups tree differs)"
        debug "EXPECTED\n"
        debug '%s\n' "$(cat "$TREE_VIEW_BACKUPS_EXPECTED")"
        debug "PRODUCED\n"
        debug '%s\n' "$(cat "$TREE_VIEW_BACKUPS_PRODUCED")"
    fi

    # result
    if [ "$trees_matches" = 'true' ]; then
        echo "PASS: $1"
    fi
}

# @param  $1  string  datetime that represent 'now'
# @param  $2  string  datetime for the savepoint
# @param  $3  string  moment
# @param  $4  string  suffix
# @env  $THIS_DIR  string  path to the current directory
# @env  $DIR_TEST  string  path to the test directory
do_backup()
{
    sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" backup \
        --now "$1" --date "$2" --moment "$3" --suffix "$4" --skip-free-space
}

# simulate one day of activity
#
# @param  $1  string  the date of the day (format: Y-m-d)
# @param  $2  string  restore the specified savepoints before booting
#
# # @param  $2  string  if 'resume' starts with 'resume' instead of 'boot'
# # @param  $3  string  if 'suspend' ends with 'suspend' instead of  'shutdown'
# # @param  $4  string  if 'no_am' don't do some work in the morning
# # @param  $5  string  if 'no_pm' don't do some work in the afternoon
# # @param  $6  string  if 'no_lunch' don't do a suspend/resume in the middle of the day
# # @param  $7  string  if 'lazy_am' don't do any modification when working in the morning
# # @param  $8  string  if 'lazy_pm' don't do any modification when working in the afternoon
# 
# @env  $_prev_end_moment  string   the previous session ending
# @env  $_bad_feeling      int      probability of a crash at random place/moment
# @env  $_random_end       bool     if 'rand_end' will terminate with suspend or shutdown randomly
simulate_session_for_a_day()
{
    _day_dir="$TEST_SUBVOL_DIR_DATA/day_$1"

    # restore a savepoint
    if [ "$2" != '' ]; then
        _now="$(get_date_plus_hours "$1 00:00:00" 8)"
        sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" restore data "$2" \
            --now "$_now" --date "$_now" --skip-free-space
    fi

    # boot/resume the computer
    _begin_moment=boot
    if [ "$2" = 'resume' ] || [ "$_prev_end_moment" = 'suspend' ]; then
        _begin_moment=resume
    fi
    _now="$(get_date_plus_hours "$1 00:00:00" 9)"
    do_backup "$_now" "$_now" "$_begin_moment"

    # do some work
    if [ "$4" != 'no_am' ]; then
        may_crash "$_bad_feeling" || return 1
        _now="$(get_date_plus_hours "$1 00:00:00" 10)"
        if [ "$7" != 'lazy_am' ]; then
            mkdir "$_day_dir"
            echo "wakeup content ($_now)" > "$_day_dir"/0_wakeup_work
        fi
        may_crash "$_bad_feeling" || return 1
        _now="$(get_date_plus_hours "$1 00:00:00" 11)"
        do_backup "$_now" "$_now" '' '.middle_morning_work'
        may_crash "$_bad_feeling" || return 1
        if [ "$7" != 'lazy_am' ]; then
            [ -d "$_day_dir" ] || mkdir "$_day_dir"
            _now="$(get_date_plus_hours "$1 00:30:00" 11)"
            echo "morning content ($_now)" > "$_day_dir"/1_morning_work
        fi
    fi

    # suspend/resume
    if [ "$6" != 'no_lunch' ]; then
        may_crash "$_bad_feeling" || return 1
        _now="$(get_date_plus_hours "$1 00:00:00" 12)"
        do_backup "$_now" "$_now" 'suspend'
        may_crash "$_bad_feeling" || return 1
        _now="$(get_date_plus_hours "$1 00:00:00" 14)"
        do_backup "$_now" "$_now" 'resume'
    fi

    # do some other work
    if [ "$5" != 'no_pm' ]; then
        may_crash "$_bad_feeling" || return 1
        if [ "$8" != 'lazy_pm' ]; then
            [ -d "$_day_dir" ] || mkdir "$_day_dir"
            _now="$(get_date_plus_hours "$1 00:15:00" 14)"
            echo "afternoon content ($_now)" > "$_day_dir"/2_afternoon_work
        fi
        may_crash "$_bad_feeling" || return 1
        _now="$(get_date_plus_hours "$1 00:00:00" 15)"
        do_backup "$_now" "$_now" '' '.middle_afternoon_work'
        may_crash "$_bad_feeling" || return 1
        if [ "$8" != 'lazy_pm' ]; then
            echo "endday content ($_now)" > "$_day_dir"/4_endday_work
        fi
    fi

    # shutdown/suspend again
    may_crash "$_bad_feeling" || return 1
    _now="$(get_date_plus_hours "$1 00:00:00" 17)"
    _end_moment=shutdown
    # shellcheck disable=SC2154
    if [ "$3" = 'suspend' ]; then
        _end_moment=suspend
    elif [ "$_random_end" = 'true' ] && [ "$(($(get_random) % 3))" -eq 0 ]; then
        _end_moment=suspend
    fi
    do_backup "$_now" "$_now" "$_end_moment"
    _prev_end_moment="$_end_moment"
}

# return 1 in case of a "crash"
# @param  $1  int   probability of a crash (the closer to 1 the more probable it is)
may_crash()
{
    if [ "$1" != '' ] && [ "$(($(get_random) % $1))" -eq 0 ]; then
        _prev_end_moment=shutdown
        return 1
    fi
}

# return a random number
get_random()
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


# reset conf data and savepoints
reset_conf_data_and_savepoints()
{
    # remove all the existing/previous savepoints
    if [ -d "$TEST_SUBVOL_DIR_BACKUPS" ]; then
        debug "   removing all the existing/previous savepoints\n"
        if [ -d "$TEST_SUBVOL_DIR_BACKUPS"/data ]; then
            if [ -e "$TEST_CONF_DATA" ]; then
                debug "      getting all the savepoints\n"
                _sp_list="$(sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" --config data ls)"
                if [ "$_sp_list" != '' ]; then
                    debug "      passing them to the script to let him delete the savepoints\n"
                    # shellcheck disable=SC2086
                    sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" rm data $_sp_list
                fi
            else
                debug "      no 'data' configuration yet. Using find command to delete symlinks and subvolumes\n"
                find "$TEST_SUBVOL_DIR_BACKUPS"/data -maxdepth 1 -type l -not -path "$TEST_SUBVOL_DIR_BACKUPS"/data -delete
                find "$TEST_SUBVOL_DIR_BACKUPS"/data -maxdepth 1 -type d -not -path "$TEST_SUBVOL_DIR_BACKUPS"/data -exec btrfs subvolume delete --commit-after '{}' \; >/dev/null
            fi
            debug "      removing the 'data' backup dir\n"
            rmdir "$TEST_SUBVOL_DIR_BACKUPS"/data
        fi

        debug "      removing the 'backups' subvolume\n"
        btrfs subvolume delete --commit-after "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null
    fi

    # create a subvolume dir for backups
    debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    # create a subvolume dir for data
    if [ -d "$TEST_SUBVOL_DIR_DATA" ]; then
        debug "   removing the 'data' subvolume\n"
        btrfs subvolume delete --commit-after "$TEST_SUBVOL_DIR_DATA" >/dev/null
    fi
    debug "   creating a subvolume for 'data'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_DATA" >/dev/null

    # put some files in it
    debug "   initialising data\n"
    echo 'content1' > "$TEST_SUBVOL_DIR_DATA"/file1.txt
    echo 'content2' > "$TEST_SUBVOL_DIR_DATA"/file2.txt
    mkdir "$TEST_SUBVOL_DIR_DATA"/dir1
    echo 'content1.1' > "$TEST_SUBVOL_DIR_DATA"/dir1/file1.1.txt
    mkdir "$TEST_SUBVOL_DIR_DATA"/dir2
    echo 'content2.1' > "$TEST_SUBVOL_DIR_DATA"/dir2/file2.1.txt

    # remove all the existing/previous configuration
    debug "   removing all the existing/previous configuration\n"
    if [ -d "$TEST_CONFS_DIRS" ]; then
        rm -fr "$TEST_CONFS_DIRS"
    fi

    # remove the log file
    if [ -e "$DIR_TEST"/btrfs-sp.log ]; then
        debug "   removing the log file '$DIR_TEST/btrfs-sp.log'\n"
        rm -f "$DIR_TEST"/btrfs-sp.log
    fi

    # create configuration for a savepoint
    debug "   creating configuration for a savepoint, named 'data'\n"
    sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" create-conf data "$TEST_SUBVOL_DIR_DATA"
}


# create a global configuration
create_global_conf()
{
    debug "Creating a global configuration\n"
    cat > "$TEST_CONF_GLOBAL" <<ENDCAT
LOCAL_CONF='$DIR_TEST/local.conf'
CONFIGS_DIR='$TEST_CONFS_DIRS'
BTRFS_TOPLEVEL_MNT=/
PERSISTENT_LOG='$DIR_TEST/btrfs-sp.log'

# where to backup
SP_DEFAULT_SAVEPOINTS_DIR_BASE='$TEST_SUBVOL_DIR_BACKUPS'

# when it should be backuped
SP_DEFAULT_BACKUP_BOOT=yes
SP_DEFAULT_BACKUP_REBOOT=yes
SP_DEFAULT_BACKUP_SHUTDOWN=yes
SP_DEFAULT_BACKUP_SUSPEND=yes
SP_DEFAULT_BACKUP_RESUME=yes

# with what prefix/suffix
SP_DEFAULT_SUFFIX_BOOT=.boot
SP_DEFAULT_SUFFIX_REBOOT=.reboot
SP_DEFAULT_SUFFIX_SHUTDOWN=.shutdown
SP_DEFAULT_SUFFIX_SUSPEND=.suspend
SP_DEFAULT_SUFFIX_RESUME=.resume

# when it is considered a safe backup
SP_DEFAULT_SAFE_BACKUP=reboot,shutdown

# how much backup to keep
#  SESSION: between BOOT and one of REBOOT/SHUTDOWN.SUSPEND or
#           between RESUME and one of REBOOT/SHUTDOWN.SUSPEND
SP_DEFAULT_KEEP_NB_SESSIONS=4
SP_DEFAULT_KEEP_NB_DAYS=3
SP_DEFAULT_KEEP_NB_WEEKS=4
SP_DEFAULT_KEEP_NB_MONTHS=12
SP_DEFAULT_KEEP_NB_YEARS=2

# what patterns to ignores when comparing savepoints
SP_DEFAULT_DIFF_IGNORE_PATTERNS='*.bak|*.swap|*.tmp|~*'

ENDCAT
}

# initial setup
if [ ! -d "$DIR_TEST" ]; then
    debug "Creating directory: '$DIR_TEST'\n"
    mkdir "$DIR_TEST"
fi
debug "Creating the global configuration\n"
create_global_conf
debug "Resting configuration, data, and savepoints\n"
reset_conf_data_and_savepoints

# ensure there is no savepoints left
if [ "$(find "$TEST_SUBVOL_DIR_BACKUPS"/data \
    -maxdepth 1 \( -type d -o -type l \) \
    -not -path "$TEST_SUBVOL_DIR_BACKUPS"/data 2>/dev/null || true)" != '' ]; then
    echo "Error: all the savepoints have not been removed (see in: '$TEST_SUBVOL_DIR_BACKUPS/data')" >&2
    exit 1
fi


# then run tests cases
echo "Start running tests cases ..."


# TEST: changing retentation strategy (more a test of 'test function')

# ensure the retention strategy is 4 3 4 12 2
current_retention='4 3 4 12 2'
_ret_strat="$(LC_ALL=C sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" ls-conf)"
if ! echo "$_ret_strat" | grep -q "^data: $TEST_SUBVOL_DIR_DATA ==> $TEST_SUBVOL_DIR_BACKUPS/data (S:4 D:3 W:4 M:12 Y:2)$"; then
    echo "FAIL: initial retention strategy is not the same"
    echo "expected: $current_retention"
    echo "produced: $(echo "$_ret_strat" | grep '^data: ' | sed -e 's/^.*(//g' -e 's/[^0-9 ]//g')"
    echo "raw: $_ret_strat"
    exit 1
fi

# change retention
current_retention='4 3 4 6 2'
# shellcheck disable=SC2086
change_retention $current_retention

# ensure the retention strategy is 4 3 4 6 2
_ret_strat="$(LC_ALL=C sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" ls-conf)"
if ! echo "$_ret_strat" | grep -q "^data: $TEST_SUBVOL_DIR_DATA ==> $TEST_SUBVOL_DIR_BACKUPS/data (S:4 D:3 W:4 M:6 Y:2)$"; then
    echo "FAIL: changed retention strategy is not the same"
    echo "expected: $current_retention"
    echo "produced: $(echo "$_ret_strat" | grep '^data: ' | sed -e 's/^.*(//g' -e 's/[^0-9 ]//g')"
    echo "raw: $_ret_strat"
    exit 1
fi
echo "PASS: retention strategy change"

# restore retention
current_retention='6 3 4 12 2'
# shellcheck disable=SC2086
change_retention $current_retention


# TEST: one week of fake activity with restoration

# simulate the fake activity
_prev_end_moment=
_bad_feeling=
restore=
year=2020
month=01
true > "$TREE_VIEW_BACKUPS_PRODUCED"
for day in $(seq 1 7); do
    day="$(echo "$day" | sed 's/^\([0-9]\)$/0\1/')"
    debug "Simulating day '$year-$month-$day'\n" 
    restore=
    if [ "$day" -eq 3 ]; then
        restore="$year-$month-01_17h00m00.shutdown.safe"
    elif [ "$day" -eq 6 ]; then
        restore="$year-$month-04_17h00m00.shutdown.safe"
    fi
    if ! simulate_session_for_a_day "$year-$month-$day" "$restore"; then
        debug "day '$year-$month-$day' have a crashed session\n"
    fi
    #cp "$TREE_VIEW_BACKUPS_PRODUCED" "$TREE_VIEW_BACKUPS_PRODUCED.before"
    #tree -L 2 -n -r --noreport "$TEST_SUBVOL_DIR_BACKUPS" >"$TREE_VIEW_BACKUPS_PRODUCED"
    #cat "$TREE_VIEW_BACKUPS_PRODUCED"
    #diff --color=always "$TREE_VIEW_BACKUPS_PRODUCED.before" "$TREE_VIEW_BACKUPS_PRODUCED" || true
done

# compare to this one
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── 2020-01-07_17h00m00.shutdown.safe
    ├── 2020-01-07_15h00m00.middle_afternoon_work
    ├── 2020-01-07_14h00m00.resume -> 2020-01-07_12h00m00.suspend
    ├── 2020-01-07_12h00m00.suspend
    ├── 2020-01-07_11h00m00.middle_morning_work
    ├── 2020-01-07_09h00m00.boot -> 2020-01-06_17h00m00.shutdown.safe
    ├── 2020-01-06_17h00m00.shutdown.safe
    ├── 2020-01-06_15h00m00.middle_afternoon_work
    ├── 2020-01-06_14h00m00.resume -> 2020-01-06_12h00m00.suspend
    ├── 2020-01-06_12h00m00.suspend
    ├── 2020-01-06_11h00m00.middle_morning_work
    ├── 2020-01-06_09h00m00.boot -> 2020-01-06_08h00m00.1.after-restoration-is-equals-to-2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-06_08h00m00.1.after-restoration-is-equals-to-2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-06_08h00m00.0.before-restoring-from-2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-05_17h00m00.shutdown.safe
    ├── 2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-03_17h00m00.shutdown.safe
    ├── 2020-01-02_17h00m00.shutdown.safe
    └── 2020-01-01_17h00m00.shutdown.safe
ENDCAT
produce_tree_and_check_it "one week of fake everyday activity (+restorations) with retention: $current_retention"

debug "Resting configuration, data, and savepoints\n"
reset_conf_data_and_savepoints

# restore retention
current_retention='6 3 4 12 2'
# shellcheck disable=SC2086
change_retention $current_retention


# # TEST: simulate two years of fake everyday activity
# 
# # restore retention
# current_retention='4 3 4 12 2'
# # shellcheck disable=SC2086
# change_retention $current_retention
# 
# # simulate the fake activity
# _prev_end_moment=
# _bad_feeling=
# restore=
# true > "$TREE_VIEW_BACKUPS_PRODUCED"
# for year in 2018 2019; do
#     for month in $(seq 1 12); do
#         _month_days=30
#         case "$month" in
#             2) _month_days=28 ;;
#             1|3|5|7|8|10|12) _month_days=31 ;;
#         esac
#         month="$(echo "$month" | sed 's/^\([0-9]\)$/0\1/')"
#         for day in $(seq 1 $_month_days); do
#             #[ "$day" -lt 8 ] || break 3
#             day="$(echo "$day" | sed 's/^\([0-9]\)$/0\1/')"
#             debug "Simulating day '$year-$month-$day'\n" 
#             if ! simulate_session_for_a_day "$year-$month-$day"; then
#                 debug "day '$year-$month-$day' have a crashed session\n"
#             fi
#             #cp "$TREE_VIEW_BACKUPS_PRODUCED" "$TREE_VIEW_BACKUPS_PRODUCED.before"
#             #tree -L 2 -n -r --noreport "$TEST_SUBVOL_DIR_BACKUPS" >"$TREE_VIEW_BACKUPS_PRODUCED"
#             #cat "$TREE_VIEW_BACKUPS_PRODUCED"
#             #diff --color=always "$TREE_VIEW_BACKUPS_PRODUCED.before" "$TREE_VIEW_BACKUPS_PRODUCED" || true
#         done
#     done
# done
# 
# # compare to this one
# cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
# $TEST_SUBVOL_DIR_BACKUPS
# └── data
#     ├── 2019-12-31_17h00m00.shutdown.safe
#     ├── 2019-12-31_15h00m00.middle_afternoon_work
#     ├── 2019-12-31_14h00m00.resume -> 2019-12-31_12h00m00.suspend
#     ├── 2019-12-31_12h00m00.suspend
#     ├── 2019-12-31_11h00m00.middle_morning_work
#     ├── 2019-12-31_09h00m00.boot -> 2019-12-30_17h00m00.shutdown.safe
#     ├── 2019-12-30_17h00m00.shutdown.safe
#     ├── 2019-12-30_15h00m00.middle_afternoon_work
#     ├── 2019-12-30_14h00m00.resume -> 2019-12-30_12h00m00.suspend
#     ├── 2019-12-30_12h00m00.suspend
#     ├── 2019-12-30_11h00m00.middle_morning_work
#     ├── 2019-12-30_09h00m00.boot -> 2019-12-29_17h00m00.shutdown.safe
#     ├── 2019-12-29_17h00m00.shutdown.safe
#     ├── 2019-12-28_17h00m00.shutdown.safe
#     ├── 2019-12-27_17h00m00.shutdown.safe
#     ├── 2019-12-22_17h00m00.shutdown.safe
#     ├── 2019-12-15_17h00m00.shutdown.safe
#     ├── 2019-12-08_17h00m00.shutdown.safe
#     ├── 2019-12-01_17h00m00.shutdown.safe
#     ├── 2019-11-01_17h00m00.shutdown.safe
#     ├── 2019-10-01_17h00m00.shutdown.safe
#     ├── 2019-09-01_17h00m00.shutdown.safe
#     ├── 2019-08-01_17h00m00.shutdown.safe
#     ├── 2019-07-01_17h00m00.shutdown.safe
#     ├── 2019-06-01_17h00m00.shutdown.safe
#     ├── 2019-05-01_17h00m00.shutdown.safe
#     ├── 2019-04-01_17h00m00.shutdown.safe
#     ├── 2019-03-01_17h00m00.shutdown.safe
#     ├── 2019-02-01_17h00m00.shutdown.safe
#     ├── 2019-01-01_17h00m00.shutdown.safe
#     └── 2018-01-01_17h00m00.shutdown.safe
# ENDCAT
# produce_tree_and_check_it "two years of fake everyday activity with retention: $current_retention"
# 
# debug "Resting configuration, data, and savepoints\n"
# reset_conf_data_and_savepoints

# restore retention
current_retention='6 3 4 12 2'
# shellcheck disable=SC2086
change_retention $current_retention


# implement deletion test (with --force-deletion)

# add a savepoint, then artificially create multiple level deep symlinks
# then delete the savepoint with -f and ensure there is no symlinks left of
_prev_end_moment=
_bad_feeling=
restore=
true > "$TREE_VIEW_BACKUPS_PRODUCED"
debug "Simulating day '2020-02-01'\n" 
debug "Simulating day '2020-02-03'\n" 
simulate_session_for_a_day "2020-02-01"
simulate_session_for_a_day "2020-02-03"
debug "Faking savepoint with no diff at '2020-02-04_13h00m00.afternoon' targeting '2020-02-03_15h00m00.middle_afternoon_work'\n" 
ln -s 2020-02-03_15h00m00.middle_afternoon_work "$TEST_SUBVOL_DIR_BACKUPS"/data/2020-02-04_13h00m00.afternoon
debug "Faking savepoint with no diff at '2020-02-05_09h12m00.morning' targeting '2020-02-04_13h00m00.afternoon'\n" 
ln -s 2020-02-04_13h00m00.afternoon "$TEST_SUBVOL_DIR_BACKUPS"/data/2020-02-05_09h12m00.morning
debug "Faking savepoint with no diff at '2020-02-02_16h00m00.afternoon' targeting '2020-02-01_17h00m00.shutdown.safe'\n" 
ln -s 2020-02-01_17h00m00.shutdown.safe "$TEST_SUBVOL_DIR_BACKUPS"/data/2020-02-02_16h00m00.afternoon
debug "Faking savepoint with no diff at '2020-02-05_22h11m00.morning.safe' targeting '2020-02-02_16h00m00.afternoon'\n" 
ln -s 2020-02-02_16h00m00.afternoon "$TEST_SUBVOL_DIR_BACKUPS"/data/2020-02-05_22h11m00.morning.safe
debug "Deleting (with --force-deletion) savepoint '2020-02-03_11h00m00.middle_morning_work'\n" 
sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" remove data 2020-02-03_11h00m00.middle_morning_work \
    --now "$_now" --force-deletion --skip-free-space
debug "Deleting (with --force-deletion) savepoint '2020-02-01_17h00m00.shutdown.safe'\n" 
sh "$THIS_DIR"/btrfs_sp.sh --global-config "$TEST_CONF_GLOBAL" remove data 2020-02-01_17h00m00.shutdown.safe \
    --now "$_now" --force-deletion --skip-free-space
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── 2020-02-05_09h12m00.morning -> 2020-02-04_13h00m00.afternoon
    ├── 2020-02-04_13h00m00.afternoon -> 2020-02-03_15h00m00.middle_afternoon_work
    ├── 2020-02-03_17h00m00.shutdown.safe
    ├── 2020-02-03_15h00m00.middle_afternoon_work
    ├── 2020-02-03_14h00m00.resume -> 2020-02-03_12h00m00.suspend
    ├── 2020-02-03_12h00m00.suspend
    ├── 2020-02-01_15h00m00.middle_afternoon_work
    ├── 2020-02-01_14h00m00.resume -> 2020-02-01_12h00m00.suspend
    ├── 2020-02-01_12h00m00.suspend
    ├── 2020-02-01_11h00m00.middle_morning_work
    └── 2020-02-01_09h00m00.boot
ENDCAT
produce_tree_and_check_it "few days of fake everyday activity (+symlinks and remove savepoint with --force-deletion) with retention: $current_retention"

debug "Resting configuration, data, and savepoints\n"
reset_conf_data_and_savepoints

# TODO implement test of every error (at least the importante ones)

# TODO implement more restoration tests

# TODO implement test of fake activity with session crashs

# TODO implement pruning tests

# TODO implement free space action

# TODO implement tests of the option --from-toplevel-subvol

exit 0


INITIAL_DATE_TEXT='2019-01-01_00h00m00'
INITIAL_DATE="$(get_date_from_text "$INITIAL_DATE_TEXT")"


# Add multiple years back
MINUS_3Y_DATE="$(get_initial_date_minus_years 3)"
MINUS_3Y_DATE_TEXT="$(get_date_to_text "$MINUS_3Y_DATE")"
NOW="$MINUS_3Y_DATE"
MINUS_3Y_MOMENT=shutdown
MINUS_3Y_SP=$MINUS_3Y_DATE_TEXT.$MINUS_3Y_MOMENT.safe
echo "* New backup with diff (-3 year)"
mkdir "$TEST_SUBVOL_DIR_DATA"/dir3
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$MINUS_3Y_DATE" -m "$MINUS_3Y_MOMENT"
MINUS_2Y_DATE="$(get_initial_date_minus_years 2)"
MINUS_2Y_DATE_TEXT="$(get_date_to_text "$MINUS_2Y_DATE")"
NOW="$MINUS_2Y_DATE"
MINUS_2Y_MOMENT=shutdown
MINUS_2Y_SP=$MINUS_2Y_DATE_TEXT.$MINUS_2Y_MOMENT.safe
echo "* New backup with diff (-2 year)"
echo 'content3.1 old' > "$TEST_SUBVOL_DIR_DATA"/dir3/file3.1.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$MINUS_2Y_DATE" -m "$MINUS_2Y_MOMENT"
MINUS_1Y_DATE="$(get_initial_date_minus_years 1)"
MINUS_1Y_DATE_TEXT="$(get_date_to_text "$MINUS_1Y_DATE")"
NOW="$MINUS_1Y_DATE"
MINUS_1Y_MOMENT=shutdown
MINUS_1Y_SP=$MINUS_1Y_DATE_TEXT.$MINUS_1Y_MOMENT.safe
echo "* New backup with diff (-1 year)"
echo 'content3.2 old' > "$TEST_SUBVOL_DIR_DATA"/dir3/file3.2.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$MINUS_1Y_DATE" -m "$MINUS_1Y_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   ├── file3.1.txt
│   └── file3.2.txt
├── file1.txt
└── file2.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $MINUS_1Y_SP
    ├── $MINUS_2Y_SP
    └── $MINUS_3Y_SP
ENDCAT
produce_tree_and_check_it


# do an initial backup
NOW="$INITIAL_DATE"
INITIAL_MOMENT=reboot
INITIAL_SP=$INITIAL_DATE_TEXT.$INITIAL_MOMENT.safe
echo "* Initial backup ($INITIAL_MOMENT)"
echo 'content1 init' > "$TEST_SUBVOL_DIR_DATA"/dir1/file1.1.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$INITIAL_DATE" -m "$INITIAL_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   ├── file3.1.txt
│   └── file3.2.txt
├── file1.txt
└── file2.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $INITIAL_SP
    ├── $MINUS_1Y_SP
    └── $MINUS_2Y_SP
ENDCAT
produce_tree_and_check_it


exit 0


# New backup with no diff (shoud be replaced by a symlink)
PLUS_1H_DATE="$(get_initial_date_plus_hours 1)"
PLUS_1H_DATE_TEXT="$(get_date_to_text "$PLUS_1H_DATE")"
NOW="$PLUS_1H_DATE"
PLUS_1H_MOMENT=boot
PLUS_1H_SP=$PLUS_1H_DATE_TEXT.$PLUS_1H_MOMENT
echo "* New backup with no diff (should be replaced by a symlink)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_1H_DATE" -m "$PLUS_1H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── file1.txt
└── file2.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with diff
PLUS_2H_DATE="$(get_initial_date_plus_hours 2)"
PLUS_2H_DATE_TEXT="$(get_date_to_text "$PLUS_2H_DATE")"
NOW="$PLUS_2H_DATE"
PLUS_2H_SP=$PLUS_2H_DATE_TEXT.apt_pre
echo "* New backup with diff"
echo 'content3' > "$TEST_SUBVOL_DIR_DATA"/file3.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_2H_DATE" -s ".apt_pre"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# Second backup with no diff (shoud be replaced by a symlink)
PLUS_3H_DATE="$(get_initial_date_plus_hours 3)"
PLUS_3H_DATE_TEXT="$(get_date_to_text "$PLUS_3H_DATE")"
NOW="$PLUS_3H_DATE"
PLUS_3H_SP=$PLUS_3H_DATE_TEXT.apt_post_cancelled
echo "* Second backup with no diff (should be replaced by a symlink)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_3H_DATE" -s ".apt_post_cancelled"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_3H_SP -> $PLUS_2H_SP
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# First backup with no diff but kept in place (no purge_diff())
PLUS_4H_DATE="$(get_initial_date_plus_hours 4)"
PLUS_4H_DATE_TEXT="$(get_date_to_text "$PLUS_4H_DATE")"
NOW="$PLUS_4H_DATE"
PLUS_4H_MOMENT=suspend
PLUS_4H_SP=$PLUS_4H_DATE_TEXT.diff.skiped.$PLUS_4H_MOMENT
echo "* First backup with no diff but kept in place (no purge_diff())"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_4H_DATE" -m "$PLUS_4H_MOMENT" -s '.diff.skiped' --no-purge-diff

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_4H_SP
    ├── $PLUS_3H_SP -> $PLUS_2H_SP
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it

# purge_diff() only "check" the last backup when backuping (even when multiple could be replaced by symlinks)

# Multiple backups with no purge diff and no diff, then one with it

# Second backup with no diff but kept in place (no purge_diff())
PLUS_5H_DATE="$(get_initial_date_plus_hours 5)"
PLUS_5H_DATE_TEXT="$(get_date_to_text "$PLUS_5H_DATE")"
NOW="$PLUS_5H_DATE"
PLUS_5H_MOMENT=resume
PLUS_5H_SP=$PLUS_5H_DATE_TEXT.diff.skiped.$PLUS_5H_MOMENT
echo "* Second backup with no diff but kept in place (no purge_diff())"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_5H_DATE" -m "$PLUS_5H_MOMENT" -s '.diff.skiped' --no-purge-diff

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_5H_SP
    ├── $PLUS_4H_SP
    ├── $PLUS_3H_SP -> $PLUS_2H_SP
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# Third backup with no diff (shoud be replaced by a symlink)
PLUS_6H_DATE="$(get_initial_date_plus_hours 6)"
PLUS_6H_DATE_TEXT="$(get_date_to_text "$PLUS_6H_DATE")"
NOW="$PLUS_6H_DATE"
PLUS_6H_SP=$PLUS_6H_DATE_TEXT.flatpak_pre
echo "* Third backup with no diff (should be replaced by a symlink)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_6H_DATE" -s '.flatpak_pre'

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_6H_SP -> $PLUS_5H_SP
    ├── $PLUS_5H_SP
    ├── $PLUS_4H_SP
    ├── $PLUS_3H_SP -> $PLUS_2H_SP
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it




# New backup with diff
PLUS_7H_DATE="$(get_initial_date_plus_hours 7)"
PLUS_7H_DATE_TEXT="$(get_date_to_text "$PLUS_7H_DATE")"
NOW="$PLUS_7H_DATE"
PLUS_7H_SP=$PLUS_7H_DATE_TEXT.flatpak_post
echo "* New backup with diff (flatpak_post)"
mkdir "$TEST_SUBVOL_DIR_DATA"/dir3
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_7H_DATE" -s '.flatpak_post'

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_7H_SP
    ├── $PLUS_6H_SP -> $PLUS_5H_SP
    ├── $PLUS_5H_SP
    ├── $PLUS_4H_SP
    ├── $PLUS_3H_SP -> $PLUS_2H_SP
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New safe backup with diff
PLUS_8H_DATE="$(get_initial_date_plus_hours 8)"
PLUS_8H_DATE_TEXT="$(get_date_to_text "$PLUS_8H_DATE")"
NOW="$PLUS_8H_DATE"
PLUS_8H_HOURS_MOMENT=shutdown
PLUS_8H_SP=$PLUS_8H_DATE_TEXT.$PLUS_8H_HOURS_MOMENT.safe
echo "* New safe backup with diff ($PLUS_8H_HOURS_MOMENT)"
echo 'content3.1' > "$TEST_SUBVOL_DIR_DATA"/dir3/file3.1.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_8H_DATE" -m "$PLUS_8H_HOURS_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_8H_SP
    ├── $PLUS_7H_SP
    ├── $PLUS_6H_SP -> $PLUS_5H_SP
    ├── $PLUS_5H_SP
    ├── $PLUS_4H_SP
    ├── $PLUS_3H_SP -> $PLUS_2H_SP
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with no diff
PLUS_1D_DATE="$(get_initial_date_plus_days 1)"
PLUS_1D_DATE_TEXT="$(get_date_to_text "$PLUS_1D_DATE")"
PLUS_1D5H_DATE="$(get_date_plus_hours "$PLUS_1D_DATE" 5)"
PLUS_1D5H_DATE_TEXT="$(get_date_to_text "$PLUS_1D5H_DATE")"
NOW="$PLUS_1D5H_DATE"
PLUS_1D5H_MOMENT=boot
PLUS_1D5H_SP=$PLUS_1D5H_DATE_TEXT.$PLUS_1D5H_MOMENT
echo "* New backup with no diff ($PLUS_1D5H_MOMENT)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_1D5H_DATE" -m "$PLUS_1D5H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_1D5H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    ├── $PLUS_7H_SP
    ├── $PLUS_6H_SP -> $PLUS_5H_SP
    ├── $PLUS_5H_SP
    ├── $PLUS_4H_SP
    ├── $PLUS_3H_SP -> $PLUS_2H_SP
    ├── $PLUS_2H_SP
    ├── $PLUS_1H_SP -> $INITIAL_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with no diff
PLUS_1D7H_DATE="$(get_date_plus_hours "$PLUS_1D_DATE" 7)"
PLUS_1D7H_DATE_TEXT="$(get_date_to_text "$PLUS_1D7H_DATE")"
NOW="$PLUS_1D7H_DATE"
PLUS_1D7H_MOMENT=shutdown
PLUS_1D7H_SP=$PLUS_1D7H_DATE_TEXT.$PLUS_1D7H_MOMENT.safe
echo "* New backup with no diff ($PLUS_1D7H_MOMENT)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_1D7H_DATE" -m "$PLUS_1D7H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_1D5H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    ├── $PLUS_7H_SP
    ├── $PLUS_6H_SP -> $PLUS_5H_SP
    ├── $PLUS_5H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with diff
PLUS_2D_DATE="$(get_initial_date_plus_days 2)"
PLUS_2D_DATE_TEXT="$(get_date_to_text "$PLUS_2D_DATE")"
PLUS_2D14H_DATE="$(get_date_plus_hours "$PLUS_2D_DATE" 14)"
PLUS_2D14H_DATE_TEXT="$(get_date_to_text "$PLUS_2D14H_DATE")"
NOW="$PLUS_2D14H_DATE"
PLUS_2D14H_MOMENT=boot
PLUS_2D14H_SP=$PLUS_2D14H_DATE_TEXT.$PLUS_2D14H_MOMENT
echo "* New backup with diff ($PLUS_2D14H_MOMENT)"
echo 'content3.1 bit rot' > "$TEST_SUBVOL_DIR_DATA"/dir3/file3.1.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_2D14H_DATE" -m "$PLUS_2D14H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_2D14H_SP
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_1D5H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    ├── $PLUS_7H_SP
    ├── $PLUS_6H_SP -> $PLUS_5H_SP
    ├── $PLUS_5H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with no diff
PLUS_2D16H_DATE="$(get_date_plus_hours "$PLUS_2D_DATE" 16)"
PLUS_2D16H_DATE_TEXT="$(get_date_to_text "$PLUS_2D16H_DATE")"
NOW="$PLUS_2D16H_DATE"
PLUS_2D16H_MOMENT=shutdown
PLUS_2D16H_SP=$PLUS_2D16H_DATE_TEXT.$PLUS_2D16H_MOMENT.safe
echo "* New backup with no diff ($PLUS_2D16H_MOMENT)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_2D16H_DATE" -m "$PLUS_2D16H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_2D16H_SP -> $PLUS_2D14H_SP
    ├── $PLUS_2D14H_SP
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_1D5H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with diff
PLUS_3D_DATE="$(get_initial_date_plus_days 3)"
PLUS_3D_DATE_TEXT="$(get_date_to_text "$PLUS_3D_DATE")"
PLUS_3D6H_DATE="$(get_date_plus_hours "$PLUS_3D_DATE" 6)"
PLUS_3D6H_DATE_TEXT="$(get_date_to_text "$PLUS_3D6H_DATE")"
NOW="$PLUS_3D6H_DATE"
PLUS_3D6H_MOMENT=boot
PLUS_3D6H_SP=$PLUS_3D6H_DATE_TEXT.$PLUS_3D6H_MOMENT
echo "* New backup with diff ($PLUS_3D6H_MOMENT)"
echo 'content2.1 bit rot' > "$TEST_SUBVOL_DIR_DATA"/dir2/file2.1.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_3D6H_DATE" -m "$PLUS_3D6H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_3D6H_SP
    ├── $PLUS_2D16H_SP -> $PLUS_2D14H_SP
    ├── $PLUS_2D14H_SP
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_1D5H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with no diff
PLUS_3D10H_DATE="$(get_date_plus_hours "$PLUS_3D_DATE" 10)"
PLUS_3D10H_DATE_TEXT="$(get_date_to_text "$PLUS_3D10H_DATE")"
NOW="$PLUS_3D10H_DATE"
PLUS_3D10H_MOMENT=shutdown
PLUS_3D10H_SP=$PLUS_3D10H_DATE_TEXT.$PLUS_3D10H_MOMENT.safe
echo "* New backup with no diff ($PLUS_3D10H_MOMENT)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_3D10H_DATE" -m "$PLUS_3D10H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_3D10H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D6H_SP
    ├── $PLUS_2D16H_SP -> $PLUS_2D14H_SP
    ├── $PLUS_2D14H_SP
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it

# TODO add a lot of days to fill up until more than one year (2 per months)

# New backup with no diff
PLUS_4D_DATE="$(get_initial_date_plus_days 4)"
PLUS_4D_DATE_TEXT="$(get_date_to_text "$PLUS_4D_DATE")"
PLUS_4D11H_DATE="$(get_date_plus_hours "$PLUS_4D_DATE" 11)"
PLUS_4D11H_DATE_TEXT="$(get_date_to_text "$PLUS_4D11H_DATE")"
NOW="$PLUS_4D11H_DATE"
PLUS_4D11H_MOMENT=boot
PLUS_4D11H_SP=$PLUS_4D11H_DATE_TEXT.$PLUS_4D11H_MOMENT
echo "* New backup with no diff ($PLUS_4D11H_MOMENT)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_4D11H_DATE" -m "$PLUS_4D11H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_4D11H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D10H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D6H_SP
    ├── $PLUS_2D16H_SP -> $PLUS_2D14H_SP
    ├── $PLUS_2D14H_SP
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with diff
PLUS_4D15H_DATE="$(get_date_plus_hours "$PLUS_4D_DATE" 15)"
PLUS_4D15H_DATE_TEXT="$(get_date_to_text "$PLUS_4D15H_DATE")"
NOW="$PLUS_4D15H_DATE"
PLUS_4D15H_MOMENT=shutdown
PLUS_4D15H_SP=$PLUS_4D15H_DATE_TEXT.$PLUS_4D15H_MOMENT.safe
echo "* New backup with diff ($PLUS_4D15H_MOMENT)"
echo 'content1.1 bit rot' > "$TEST_SUBVOL_DIR_DATA"/dir1/file1.1.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_4D15H_DATE" -m "$PLUS_4D15H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_4D15H_SP
    ├── $PLUS_4D11H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D10H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D6H_SP
    ├── $PLUS_2D16H_SP -> $PLUS_2D14H_SP
    ├── $PLUS_2D14H_SP
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with no diff
PLUS_10D_DATE="$(get_initial_date_plus_days 10)"
PLUS_10D_DATE_TEXT="$(get_date_to_text "$PLUS_10D_DATE")"
PLUS_10D8H_DATE="$(get_date_plus_hours "$PLUS_10D_DATE" 8)"
PLUS_10D8H_DATE_TEXT="$(get_date_to_text "$PLUS_10D8H_DATE")"
NOW="$PLUS_10D8H_DATE"
PLUS_10D8H_MOMENT=boot
PLUS_10D8H_SP=$PLUS_10D8H_DATE_TEXT.$PLUS_10D8H_MOMENT
echo "* New backup with no diff ($PLUS_10D8H_MOMENT)"
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_10D8H_DATE" -m "$PLUS_10D8H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_10D8H_SP -> $PLUS_4D15H_SP
    ├── $PLUS_4D15H_SP
    ├── $PLUS_4D11H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D10H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D6H_SP
    ├── $PLUS_2D16H_SP -> $PLUS_2D14H_SP
    ├── $PLUS_2D14H_SP
    ├── $PLUS_1D7H_SP -> $PLUS_8H_SP
    ├── $PLUS_8H_SP
    └── $INITIAL_SP
ENDCAT
produce_tree_and_check_it


# New backup with diff
PLUS_10D12H_DATE="$(get_date_plus_hours "$PLUS_10D_DATE" 12)"
PLUS_10D12H_DATE_TEXT="$(get_date_to_text "$PLUS_10D12H_DATE")"
NOW="$PLUS_10D12H_DATE"
PLUS_10D12H_MOMENT=shutdown
PLUS_10D12H_SP=$PLUS_10D12H_DATE_TEXT.$PLUS_10D12H_MOMENT.safe
echo "* New backup with diff ($PLUS_10D12H_MOMENT)"
echo 'content1.1 bit rot' > "$TEST_SUBVOL_DIR_DATA"/dir1/file1.1.txt
sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_10D12H_DATE" -m "$PLUS_10D12H_MOMENT"

# check the trees
cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_DATA
├── dir1
│   └── file1.1.txt
├── dir2
│   └── file2.1.txt
├── dir3
│   └── file3.1.txt
├── file1.txt
├── file2.txt
└── file3.txt
ENDCAT
cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── $PLUS_10D12H_SP
    ├── $PLUS_10D8H_SP -> $PLUS_4D15H_SP
    ├── $PLUS_4D15H_SP
    ├── $PLUS_4D11H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D10H_SP -> $PLUS_3D6H_SP
    ├── $PLUS_3D6H_SP
    ├── $PLUS_2D16H_SP -> $PLUS_2D14H_SP
    └── $PLUS_2D14H_SP
ENDCAT
produce_tree_and_check_it


# # Multiple backup with no purge number
# echo "* Multiple backup with no purge number"
# DEBUG_BAK="$DEBUG"
# DEBUG=false
# PLUS_7H_DATE="$(get_initial_date_plus_hours 7)"
# PLUS_7H_DATE_TEXT="$(get_date_to_text "$PLUS_7H_DATE")"
# mkdir "$TEST_SUBVOL_DIR_DATA"/dir3
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_7H_DATE" -s '.2nd-diff' --no-purge-number
# PLUS_8H_DATE="$(get_initial_date_plus_hours 8)"
# PLUS_8H_DATE_TEXT="$(get_date_to_text "$PLUS_8H_DATE")"
# echo 'content3.1' > "$TEST_SUBVOL_DIR_DATA"/dir3/file3.1.txt
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_8H_DATE" -s '.3rd-diff' --no-purge-number
# PLUS_9H_DATE="$(get_initial_date_plus_hours 9)"
# PLUS_9H_DATE_TEXT="$(get_date_to_text "$PLUS_9H_DATE")"
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_9H_DATE" -s '.4th-no-diff' --no-purge-number
# PLUS_10H_DATE="$(get_initial_date_plus_hours 10)"
# PLUS_10H_DATE_TEXT="$(get_date_to_text "$PLUS_10H_DATE")"
# echo 'content3.2' > "$TEST_SUBVOL_DIR_DATA"/dir3/file3.2.txt
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_10H_DATE" -s '.4th-diff.safe' --no-purge-number
# PLUS_11H_DATE="$(get_initial_date_plus_hours 11)"
# PLUS_11H_DATE_TEXT="$(get_date_to_text "$PLUS_11H_DATE")"
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_11H_DATE" -s '.5th-no-diff' --no-purge-number
# PLUS_12H_DATE="$(get_initial_date_plus_hours 12)"
# PLUS_12H_DATE_TEXT="$(get_date_to_text "$PLUS_12H_DATE")"
# rm "$TEST_SUBVOL_DIR_DATA"/dir3/file3.2.txt
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_12H_DATE" -s '.5th-diff' --no-purge-number
# PLUS_13H_DATE="$(get_initial_date_plus_hours 13)"
# PLUS_13H_DATE_TEXT="$(get_date_to_text "$PLUS_13H_DATE")"
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_13H_DATE" -s '.6th-no-diff' --no-purge-number
# PLUS_14H_DATE="$(get_initial_date_plus_hours 14)"
# PLUS_14H_DATE_TEXT="$(get_date_to_text "$PLUS_14H_DATE")"
# echo 'content3.2' > "$TEST_SUBVOL_DIR_DATA"/dir3/file3.2.txt
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_14H_DATE" -s '.6th-diff' --no-purge-number
# PLUS_15H_DATE="$(get_initial_date_plus_hours 15)"
# PLUS_15H_DATE_TEXT="$(get_date_to_text "$PLUS_15H_DATE")"
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_15H_DATE" -s '.7th-no-diff.safe' --no-purge-number
# PLUS_16H_DATE="$(get_initial_date_plus_hours 16)"
# PLUS_16H_DATE_TEXT="$(get_date_to_text "$PLUS_16H_DATE")"
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_16H_DATE" -s '.8th-no-diff' --no-purge-number
# PLUS_17H_DATE="$(get_initial_date_plus_hours 17)"
# PLUS_17H_DATE_TEXT="$(get_date_to_text "$PLUS_17H_DATE")"
# rm -fr "$TEST_SUBVOL_DIR_DATA"/dir3
# sh "$THIS_DIR"/btrfs_sp.sh -c "$DIR_TEST"/test.conf backup -t "$NOW" -d "$PLUS_17H_DATE" -s '.7th-diff' --no-purge-number
# DEBUG="$DEBUG_BAK"
# 
# cat > "$TREE_VIEW_DATA_EXPECTED" <<ENDCAT
# $TEST_SUBVOL_DIR_DATA
# ├── dir1
# │   └── file1.1.txt
# ├── dir2
# │   └── file2.1.txt
# ├── file1.txt
# ├── file2.txt
# └── file3.txt
# ENDCAT
# cat > "$TREE_VIEW_BACKUPS_EXPECTED" <<ENDCAT
# $TEST_SUBVOL_DIR_BACKUPS
# └── data
#     ├── $INITIAL_DATE_TEXT.initial
#     ├── $PLUS_1H_DATE_TEXT.1st-no-diff -> $INITIAL_DATE_TEXT.initial
#     ├── $PLUS_2H_DATE_TEXT.1st-diff
#     ├── $PLUS_3H_DATE_TEXT.2nd-no-diff -> $PLUS_2H_DATE_TEXT.1st-diff
#     ├── $PLUS_4H_DATE_TEXT.1st-no-diff.skiped -> $PLUS_2H_DATE_TEXT.1st-diff
#     ├── $PLUS_5H_DATE_TEXT.2nd-no-diff.skiped -> $PLUS_4H_DATE_TEXT.1st-no-diff.skiped
#     ├── $PLUS_6H_DATE_TEXT.3rd-no-diff.safe -> $PLUS_5H_DATE_TEXT.2nd-no-diff.skiped
#     ├── $PLUS_7H_DATE_TEXT.2nd-diff
#     ├── $PLUS_8H_DATE_TEXT.3rd-diff
#     ├── $PLUS_9H_DATE_TEXT.4th-no-diff -> $PLUS_8H_DATE_TEXT.3rd-diff
#     ├── $PLUS_10H_DATE_TEXT.4th-diff.safe
#     ├── $PLUS_11H_DATE_TEXT.5th-no-diff -> $PLUS_10H_DATE_TEXT.4th-diff.safe
#     ├── $PLUS_12H_DATE_TEXT.5th-diff
#     ├── $PLUS_13H_DATE_TEXT.6th-no-diff -> $PLUS_12H_DATE_TEXT.5th-diff
#     ├── $PLUS_14H_DATE_TEXT.6th-diff
#     ├── $PLUS_15H_DATE_TEXT.7th-no-diff.safe -> $PLUS_14H_DATE_TEXT.6th-diff
#     ├── $PLUS_16H_DATE_TEXT.8th-no-diff -> $PLUS_14H_DATE_TEXT.6th-diff
#     └── $PLUS_17H_DATE_TEXT.7th-diff
# ENDCAT
# produce_tree_and_check_it
