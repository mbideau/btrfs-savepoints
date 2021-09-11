#!/bin/sh

set -e


DATE_STD_REGEX='[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}'

# shunit2 functions

oneTimeSetUp()    { __oneTimeSetUp; }
oneTimeTearDown() { __oneTimeTearDown; }

# reset conf data and savepoints
setUp()
{
    __setUp

    # reset some variables
    _prev_end_moment=
    _start="$(date '+%s')"
}

tearDown()
{
    # generate a small report about statistics
    if [ "$NO_REPORT" != 'true' ] && [ "$_start" != '' ]; then
        report_test_stats "$(($(date +%s) - _start))"
        _start=
    fi

    __tearDown
}


# helper functions

# @param  $1  string  datetime that represent 'now'
# @param  $2  string  datetime for the savepoint
# @param  $3  string  moment
# @param  $4  string  suffix
# @env  $THIS_DIR  string  path to the current directory
# @env  $DIR_TEST  string  path to the test directory
do_backup()
{
    __debug "   new savepoint at '%s'\n" "$2"
    "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$1" --date "$2" --moment "$3" --suffix "$4" --skip-free-space >/dev/null
    if [ "$DEBUG_TEST" != 'true' ]; then
        printf '%s' '.'
    fi
}

# simulate one day of activity
#
# @param  $1  string  the date of the day (format: Y-m-d)
# @param  $2  string  restore the specified savepoints before booting
#
# @env  $_prev_end_moment  string   the previous session ending
# @env  $_random_end       bool     if 'rand_end' will terminate with suspend or shutdown randomly
#
simulate_session_for_a_day()
{
    _day_dir="$TEST_SUBVOL_DIR_DATA/day_$1"

    # restore a savepoint
    if [ "$2" != '' ]; then
        _now="$1 08:00:00"
        __debug "   restoring on day '%s' from '%s' ...\n" "$1" "$2"
        "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" restore data "$2" \
            --now "$_now" --date "$_now" --skip-free-space
    fi

    # boot/resume the computer
    _begin_moment=boot
    if [ "$2" = 'resume' ] || [ "$_prev_end_moment" = 'suspend' ]; then
        _begin_moment=resume
    fi
    _now="$1 09:00:00"
    do_backup "$_now" "$_now" "$_begin_moment"

    # hours and minutes backups
    for _t in 09:15:00 09:30:00 09:45:00; do
        _now="$1 $_t"
        [ -d "$_day_dir" ] || mkdir "$_day_dir"
        echo "wakeup content ($_now)" > "$_day_dir"/0_wakeup_work
        do_backup "$_now" "$_now" '' '.wakeup_work'
    done

    # fake a morning install
    _now="$1 10:00:00"
    do_backup "$_now" "$_now" '' '.morning_install_before'
    _now="$1 10:01:00"
    [ -d "$_day_dir" ] || mkdir "$_day_dir"
    echo "morning install ($_now)" > "$_day_dir"/1_morning_install
    do_backup "$_now" "$_now" '' '.morning_install_after'

    # hours and minutes backups
    for _h in 10 11; do
        for _t in $_h:15:00 $_h:30:00 $_h:45:00; do
            _now="$1 $_t"
            [ -d "$_day_dir" ] || mkdir "$_day_dir"
            echo "morning content ($_now)" > "$_day_dir"/2_morning_work
            do_backup "$_now" "$_now" '' '.morning_work'
        done
    done

    # suspend
    _now="$1 12:00:00"
    do_backup "$_now" "$_now" 'suspend'

    # resume
    _now="$1 14:00:00"
    do_backup "$_now" "$_now" 'resume'

    # hours and minutes backups
    for _h in 14 15; do
        for _t in $_h:15:00 $_h:30:00 $_h:45:00; do
            _now="$1 $_t"
            [ -d "$_day_dir" ] || mkdir "$_day_dir"
            echo "afternoon content ($_now)" > "$_day_dir"/3_afternoon_work
            do_backup "$_now" "$_now" '' '.morning_work'
        done
    done

    # fake an afternoon install
    _now="$1 16:00:00"
    do_backup "$_now" "$_now" '' '.afternoon_install_before'
    _now="$1 16:01:00"
    [ -d "$_day_dir" ] || mkdir "$_day_dir"
    echo "afternoon install ($_now)" > "$_day_dir"/4_afternoon_install
    do_backup "$_now" "$_now" '' '.afternoon_install_after'

    # hours and minutes backups
    for _t in 16:15:00 16:30:00 16:45:00; do
        _now="$1 $_t"
        [ -d "$_day_dir" ] || mkdir "$_day_dir"
        echo "evening content ($_now)" > "$_day_dir"/5_evening_work
        do_backup "$_now" "$_now" '' '.evening_work'
    done

    # shutdown/suspend again
    _now="$1 17:00:00"
    _end_moment=shutdown
    # shellcheck disable=SC2154
    if [ "$3" = 'suspend' ]; then
        _end_moment=suspend
    elif [ "$_random_end" = 'true' ] && [ "$(($(get_random) % 3))" -eq 0 ]; then
        _end_moment=suspend
    fi
    do_backup "$_now" "$_now" "$_end_moment"
    _prev_end_moment="$_end_moment"
    if [ "$DEBUG_TEST" != 'true' ]; then
        echo
    fi
}

# simulate one day of server activity
#
# @param  $1  string  the date of the day (format: Y-m-d)
#
simulate_server_for_a_day()
{
    _day_dir="$TEST_SUBVOL_DIR_DATA/day_$1"

    # hours and minutes backups
    for _h in 00 01 02 03 04 05 06; do
        for _t in $_h:00:00 $_h:15:00 $_h:30:00 $_h:45:00; do
            _now="$1 $_t"
            do_backup "$_now" "$_now" '' '.early_night_nothing'
        done
    done

    # hours and minutes backups
    for _h in 07 08 09; do
        for _t in $_h:15:00 $_h:30:00 $_h:45:00; do
            _now="$1 $_t"
            [ -d "$_day_dir" ] || mkdir "$_day_dir"
            echo "wakeup content ($_now)" > "$_day_dir"/0_wakeup_work
            do_backup "$_now" "$_now" '' '.wakeup_work'
        done
    done

    # fake a morning install
    _now="$1 10:00:00"
    do_backup "$_now" "$_now" '' '.morning_install_before'
    _now="$1 10:01:00"
    [ -d "$_day_dir" ] || mkdir "$_day_dir"
    echo "morning install ($_now)" > "$_day_dir"/1_morning_install
    do_backup "$_now" "$_now" '' '.morning_install_after'

    # hours and minutes backups
    for _t in 10:15:00 10:30:00 10:45:00; do
        _now="$1 $_t"
        [ -d "$_day_dir" ] || mkdir "$_day_dir"
        echo "morning content ($_now)" > "$_day_dir"/2_morning_work
        do_backup "$_now" "$_now" '' '.morning_work'
    done

    # hours and minutes backups
    for _h in 11 12 13 14 15; do
        for _t in $_h:00:00 $_h:15:00 $_h:30:00 $_h:45:00; do
            _now="$1 $_t"
            [ -d "$_day_dir" ] || mkdir "$_day_dir"
            echo "day content ($_now)" > "$_day_dir"/3_day_work
            do_backup "$_now" "$_now" '' '.day_work'
        done
    done

    # fake an afternoon install
    _now="$1 16:00:00"
    do_backup "$_now" "$_now" '' '.afternoon_install_before'
    _now="$1 16:01:00"
    [ -d "$_day_dir" ] || mkdir "$_day_dir"
    echo "afternoon install ($_now)" > "$_day_dir"/4_afternoon_install
    do_backup "$_now" "$_now" '' '.afternoon_install_after'

    # hours and minutes backups
    for _t in 16:15:00 16:30:00 16:45:00; do
        _now="$1 $_t"
        [ -d "$_day_dir" ] || mkdir "$_day_dir"
        echo "afternoon content ($_now)" > "$_day_dir"/5_afternoon_work
        do_backup "$_now" "$_now" '' '.evening_work'
    done

    # hours and minutes backups
    for _h in 17 18 19 20; do
        for _t in $_h:00:00 $_h:15:00 $_h:30:00 $_h:45:00; do
            _now="$1 $_t"
            [ -d "$_day_dir" ] || mkdir "$_day_dir"
            echo "evening content ($_now)" > "$_day_dir"/6_evening_work
            do_backup "$_now" "$_now" '' '.day_work'
        done
    done

    # hours and minutes backups
    for _h in 21 22 23; do
        for _t in $_h:00:00 $_h:15:00 $_h:30:00 $_h:45:00; do
            _now="$1 $_t"
            do_backup "$_now" "$_now" '' '.late_night_nothing'
        done
    done
    if [ "$DEBUG_TEST" != 'true' ]; then
        echo
    fi
}


# print a time interval in seconds to a human readble form
#
# inspired from: https://stackoverflow.com/a/56530876
#
# @param  $1  string  duration in seconds
#
secs_to_human()
{
    hours=0
    mins=0
    if [ "$1" = '' ] || [ "$1" -lt 60 ]; then
        secs="$1"
    else
        time_mins="$(echo "$1" | LC_ALL=C awk '{printf "%.2f", ($1 / 60)}')"
        mins="$(echo "$time_mins" | cut -d'.' -f1)"
        secs="0.$(echo "$time_mins" | cut -d'.' -f2)"
        secs="$(echo "$secs" | LC_ALL=C awk '{print int(($1 * 60) + 0.5)}')"
        time_hours="$(echo "$1" | LC_ALL=C awk '{printf "%.2f", ($1 / 60 / 60)}')"
        hours="$(echo "$time_hours" | cut -d'.' -f1)"
        mins="0.$(echo "$time_hours" | cut -d'.' -f2)"
        mins="$(echo "$mins" | LC_ALL=C awk '{print int(($1 * 60) + 0.5)}')"
    fi
    _txt_format=
    if [ "$hours" -gt 0 ]; then
        _txt_format=" ($hours hours $mins minutes $secs seconds)"
    elif [ "$mins" -gt 0 ]; then
        _txt_format=" ($mins minutes $secs seconds)"
    else
        _txt_format=" ($secs seconds)"
    fi
    secs="$(echo "$secs" | sed 's/^\([0-9]\)$/0\1/g')"
    mins="$(echo "$mins" | sed 's/^\([0-9]\)$/0\1/g')"
    hours="$(echo "$hours" | sed 's/^\([0-9]\)$/0\1/g')"
    _std_format="$(printf '%2s:%2s:%2s' "$hours" "$mins" "$secs")"
    echo "Duration : ${_std_format}${_txt_format}"
}

# print number of operations there is in the persistent log
report_on_operations_from_log()
{
    if [ -r "$TEST_PERSISTENT_LOG" ]; then
        __debug "Analysing persistent log file: '%s'\n" "$TEST_PERSISTENT_LOG"
        _op_snap_create="$(grep -c "^$DATE_STD_REGEX \\[[^]]\\+\\] + [^</]\\+ <== .*\$" \
                           "$TEST_PERSISTENT_LOG" || true)"
        _op_snap_delete="$(grep -c "^$DATE_STD_REGEX \\[[^]]\\+\\] - [^/>(]\\+\$" \
                           "$TEST_PERSISTENT_LOG" || true)"
        _op_subvol_create="$(grep -c "^$DATE_STD_REGEX \\[[^]]\\+\\] + /[^<]\\+ <<< [^/]\\+\$" \
                             "$TEST_PERSISTENT_LOG" || true)"
        _op_subvol_delete="$(grep -c "^$DATE_STD_REGEX \\[[^]]\\+\\] - /.*\$" \
                             "$TEST_PERSISTENT_LOG" || true)"
        _op_total="$((_op_snap_create + _op_snap_delete + _op_subvol_create + _op_subvol_delete))"

        printf "Operations : %d (snapshots: %d created %d deleted, "`
               `"subvolumes: %d created %d deleted)\n" "$_op_total" \
                "$_op_snap_create" "$_op_snap_delete" "$_op_subvol_create" "$_op_subvol_delete"
    else
        __debug "No persistent log file: '%s'\n" "$TEST_PERSISTENT_LOG"
    fi
}

# print statistics about duration and operations (to STDERR)
#
# @param  $1  string  duration in seconds
#
report_test_stats()
{
    secs_to_human "$1" | sed 's/^/     /' >&2
    _report_ops="$(report_on_operations_from_log)"
    if [ "$_report_ops" != '' ]; then
        echo "$_report_ops" | sed 's/^/   /' >&2
        _op_total="$(echo "$_report_ops" | sed "s/^Operations : \([0-9]\+\) .*$/\1/g")"
        _op_time_avg="$(echo "$_op_total $1" | awk '{printf "%.2f", ($1 / $2)}')"
        echo "AVG time : $_op_time_avg s/operation "`
             `"(/!\ this is not the real time spent doing the operation)" | sed 's/^/     /' >&2
    fi
}


# tests cases

# TEST: one week of fake activity with restoration
test__1WeekWithRestoration()
{
    __warn "This test case takes approx' 20min long"

    # shellcheck disable=SC2086
    __create_global_conf 6 3 4 12 2

    _tmp="$(mktemp)"
    # shellcheck disable=SC2154
    "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    # simulate the fake activity
    year=2020
    month=01
    for day in $(seq 1 7); do
        day="$(echo "$day" | sed 's/^\([0-9]\)$/0\1/')"
        _restore=
        if [ "$day" -eq 3 ]; then
            _restore="$year-$month-01_17h00m00.shutdown.safe"
            __debug "Simulating day '$year-$month-$day' (with restoration)\n" 
        elif [ "$day" -eq 6 ]; then
            _restore="$year-$month-04_17h00m00.shutdown.safe"
            __debug "Simulating day '$year-$month-$day' (with restoration)\n" 
        else
            __debug "Simulating day '$year-$month-$day'\n" 
        fi
        if ! simulate_session_for_a_day "$year-$month-$day" "$_restore"; then
            fail "day '$year-$month-$day' have failed"
        fi
    done

    # compare trees
    assertSame "1WWithRetention tree should be the same" \
"$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── 2020-01-07_17h00m00.shutdown.safe -> 2020-01-07_16h45m00.evening_work
    ├── 2020-01-07_16h45m00.evening_work
    ├── 2020-01-07_16h30m00.evening_work
    ├── 2020-01-07_16h15m00.evening_work
    ├── 2020-01-07_16h01m00.afternoon_install_after
    ├── 2020-01-07_16h00m00.afternoon_install_before -> 2020-01-07_15h45m00.morning_work
    ├── 2020-01-07_15h45m00.morning_work
    ├── 2020-01-07_15h30m00.morning_work
    ├── 2020-01-07_15h15m00.morning_work
    ├── 2020-01-07_14h45m00.morning_work
    ├── 2020-01-07_14h30m00.morning_work
    ├── 2020-01-07_14h15m00.morning_work
    ├── 2020-01-07_14h00m00.resume -> 2020-01-07_11h45m00.morning_work
    ├── 2020-01-07_12h00m00.suspend -> 2020-01-07_11h45m00.morning_work
    ├── 2020-01-07_11h45m00.morning_work
    ├── 2020-01-07_11h30m00.morning_work
    ├── 2020-01-07_11h15m00.morning_work
    ├── 2020-01-07_10h45m00.morning_work
    ├── 2020-01-07_10h30m00.morning_work
    ├── 2020-01-07_10h15m00.morning_work
    ├── 2020-01-07_10h01m00.morning_install_after
    ├── 2020-01-07_10h00m00.morning_install_before -> 2020-01-07_09h45m00.wakeup_work
    ├── 2020-01-07_09h45m00.wakeup_work
    ├── 2020-01-07_09h30m00.wakeup_work
    ├── 2020-01-07_09h15m00.wakeup_work
    ├── 2020-01-07_09h00m00.boot -> 2020-01-06_16h45m00.evening_work
    ├── 2020-01-06_17h00m00.shutdown.safe -> 2020-01-06_16h45m00.evening_work
    ├── 2020-01-06_16h45m00.evening_work
    ├── 2020-01-06_16h30m00.evening_work
    ├── 2020-01-06_16h15m00.evening_work
    ├── 2020-01-06_16h01m00.afternoon_install_after
    ├── 2020-01-06_16h00m00.afternoon_install_before -> 2020-01-06_15h45m00.morning_work
    ├── 2020-01-06_15h45m00.morning_work
    ├── 2020-01-06_15h30m00.morning_work
    ├── 2020-01-06_15h15m00.morning_work
    ├── 2020-01-06_14h45m00.morning_work
    ├── 2020-01-06_14h30m00.morning_work
    ├── 2020-01-06_14h15m00.morning_work
    ├── 2020-01-06_14h00m00.resume -> 2020-01-06_11h45m00.morning_work
    ├── 2020-01-06_12h00m00.suspend -> 2020-01-06_11h45m00.morning_work
    ├── 2020-01-06_11h45m00.morning_work
    ├── 2020-01-06_11h30m00.morning_work
    ├── 2020-01-06_11h15m00.morning_work
    ├── 2020-01-06_10h45m00.morning_work
    ├── 2020-01-06_10h30m00.morning_work
    ├── 2020-01-06_10h15m00.morning_work
    ├── 2020-01-06_10h01m00.morning_install_after
    ├── 2020-01-06_10h00m00.morning_install_before -> 2020-01-06_09h45m00.wakeup_work
    ├── 2020-01-06_09h45m00.wakeup_work
    ├── 2020-01-06_09h30m00.wakeup_work
    ├── 2020-01-06_09h15m00.wakeup_work
    ├── 2020-01-06_09h00m00.boot -> 2020-01-06_08h00m00.1.after-restoration-is-equals-to-2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-06_08h00m00.1.after-restoration-is-equals-to-2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-06_08h00m00.0.before-restoring-from-2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-05_17h00m00.shutdown.safe
    ├── 2020-01-04_17h00m00.shutdown.safe
    ├── 2020-01-03_17h00m00.shutdown.safe
    ├── 2020-01-02_17h00m00.shutdown.safe
    └── 2020-01-01_17h00m00.shutdown.safe" \
        "$(tree -L 2 -n -r --noreport "$TEST_SUBVOL_DIR_BACKUPS")"
}

# TEST: simulate two weeks of server activity (two huge sessions but with KEEP_NB_SESSIONS=0)
test__2WeeksOfServerLikeActivitySimple()
{
    __warn "This test case takes approx' 1h long"

    # shellcheck disable=SC2086
    __create_global_conf 0 7 4 12 2

    _tmp="$(mktemp)"
    "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __set_config_var "$TEST_CONF_DATA" 'PURGE_NUMBER_NO_SESSION'  'yes'
    __set_config_var "$TEST_CONF_DATA" 'KEEP_NB_MINUTES' 20
    __set_config_var "$TEST_CONF_DATA" 'KEEP_NB_HOURS'   20

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    # simulate the fake activity
    year=2020
    month=01
    for day in $(seq 1 14); do
        if [ "$day" -eq 7 ]; then
            DEBUG=true
            export DEBUG
        fi
        day="$(echo "$day" | sed 's/^\([0-9]\)$/0\1/')"
        __debug "Simulating day '$year-$month-$day'\n" 
        if ! simulate_server_for_a_day "$year-$month-$day"; then
            fail "day '$year-$month-$day' have failed"
        fi
    done

    # compare trees
    assertSame "2WeeksOfServerLikeActivitySimple tree should be the same" \
"$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── 2020-01-14_23h45m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_23h30m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_23h15m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_23h00m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_22h45m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_22h30m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_22h15m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_22h00m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_21h45m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_21h30m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_21h15m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_21h00m00.late_night_nothing -> 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_20h45m00.day_work
    ├── 2020-01-14_20h30m00.day_work
    ├── 2020-01-14_20h15m00.day_work
    ├── 2020-01-14_20h00m00.day_work
    ├── 2020-01-14_19h45m00.day_work
    ├── 2020-01-14_19h30m00.day_work
    ├── 2020-01-14_19h15m00.day_work
    ├── 2020-01-14_19h00m00.day_work
    ├── 2020-01-14_18h00m00.day_work
    ├── 2020-01-14_17h00m00.day_work
    ├── 2020-01-14_16h00m00.afternoon_install_before
    ├── 2020-01-14_15h00m00.day_work
    ├── 2020-01-14_14h00m00.day_work
    ├── 2020-01-14_13h00m00.day_work
    ├── 2020-01-14_12h00m00.day_work
    ├── 2020-01-14_11h00m00.day_work
    ├── 2020-01-14_10h00m00.morning_install_before
    ├── 2020-01-14_09h15m00.wakeup_work
    ├── 2020-01-14_08h15m00.wakeup_work
    ├── 2020-01-14_07h15m00.wakeup_work
    ├── 2020-01-14_06h00m00.early_night_nothing -> 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-14_05h00m00.early_night_nothing -> 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-14_04h00m00.early_night_nothing -> 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-14_03h00m00.early_night_nothing -> 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-14_02h00m00.early_night_nothing -> 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-14_01h00m00.early_night_nothing -> 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-14_00h00m00.early_night_nothing -> 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-13_23h00m00.late_night_nothing
    ├── 2020-01-13_00h00m00.early_night_nothing
    ├── 2020-01-12_00h00m00.early_night_nothing
    ├── 2020-01-11_00h00m00.early_night_nothing
    ├── 2020-01-10_00h00m00.early_night_nothing
    ├── 2020-01-09_00h00m00.early_night_nothing
    ├── 2020-01-08_00h00m00.early_night_nothing
    ├── 2020-01-07_00h00m00.early_night_nothing
    ├── 2020-01-06_00h00m00.early_night_nothing
    └── 2020-01-01_00h00m00.early_night_nothing" \
        "$(tree -L 2 -n -r --noreport "$TEST_SUBVOL_DIR_BACKUPS")"
}

# TEST: simulate two years of fake everyday activity
test__2YearsSimple()
{
    __warn "This test case takes approx' 2h long"

    _start="$(date '+%s')"

    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    # simulate the fake activity
    for year in 2018 2019; do
        for month in $(seq 1 12); do
            _month_days=30
            case "$month" in
                2) _month_days=28 ;;
                1|3|5|7|8|10|12) _month_days=31 ;;
            esac
            month="$(echo "$month" | sed 's/^\([0-9]\)$/0\1/')"
            for day in $(seq 1 $_month_days); do
                day="$(echo "$day" | sed 's/^\([0-9]\)$/0\1/')"
                __debug "Simulating day '$year-$month-$day'\n" 
                if ! simulate_session_for_a_day "$year-$month-$day"; then
                    fail "day '$year-$month-$day' have failed"
                fi
            done
        done
    done

    # compare trees
    assertSame "1WWithRetention tree should be the same" \
"$TEST_SUBVOL_DIR_BACKUPS
└── data
    ├── 2019-12-31_17h00m00.shutdown.safe
    ├── 2019-12-31_15h00m00.middle_afternoon_work
    ├── 2019-12-31_14h00m00.resume -> 2019-12-31_12h00m00.suspend
    ├── 2019-12-31_12h00m00.suspend
    ├── 2019-12-31_11h00m00.middle_morning_work
    ├── 2019-12-31_09h00m00.boot -> 2019-12-30_17h00m00.shutdown.safe
    ├── 2019-12-30_17h00m00.shutdown.safe
    ├── 2019-12-30_15h00m00.middle_afternoon_work
    ├── 2019-12-30_14h00m00.resume -> 2019-12-30_12h00m00.suspend
    ├── 2019-12-30_12h00m00.suspend
    ├── 2019-12-30_11h00m00.middle_morning_work
    ├── 2019-12-30_09h00m00.boot -> 2019-12-29_17h00m00.shutdown.safe
    ├── 2019-12-29_17h00m00.shutdown.safe
    ├── 2019-12-28_17h00m00.shutdown.safe
    ├── 2019-12-27_17h00m00.shutdown.safe
    ├── 2019-12-22_17h00m00.shutdown.safe
    ├── 2019-12-15_17h00m00.shutdown.safe
    ├── 2019-12-08_17h00m00.shutdown.safe
    ├── 2019-12-01_17h00m00.shutdown.safe
    ├── 2019-11-01_17h00m00.shutdown.safe
    ├── 2019-10-01_17h00m00.shutdown.safe
    ├── 2019-09-01_17h00m00.shutdown.safe
    ├── 2019-08-01_17h00m00.shutdown.safe
    ├── 2019-07-01_17h00m00.shutdown.safe
    ├── 2019-06-01_17h00m00.shutdown.safe
    ├── 2019-05-01_17h00m00.shutdown.safe
    ├── 2019-04-01_17h00m00.shutdown.safe
    ├── 2019-03-01_17h00m00.shutdown.safe
    ├── 2019-02-01_17h00m00.shutdown.safe
    ├── 2019-01-01_17h00m00.shutdown.safe
    └── 2018-01-01_17h00m00.shutdown.safe" \
        "$(tree -L 2 -n -r --noreport "$TEST_SUBVOL_DIR_BACKUPS")"

    secs_to_human "$(($(date +%s) - _start))" >&2
}

# 'btrfs-sp' root directory
THIS_DIR="$(dirname "$(realpath "$0")")"

# source helper tests functions
# shellcheck disable=SC1090
. "$THIS_DIR"/test.inc.sh

# run shunit2
# shellcheck disable=SC1090
. "$SHUNIT2"
