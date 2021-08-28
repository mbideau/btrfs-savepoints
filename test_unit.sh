#!/bin/sh

# halt on first error
set -e


# shunit2 functions

oneTimeSetUp()    { __oneTimeSetUp; set_default_vars; }
oneTimeTearDown() { __oneTimeTearDown; }
setUp()           { __setUp; }
tearDown()        { __tearDown; }


# tests cases

test__is_conf_name_valid()
{
    assertTrue "is_conf_name_valid 'th1s-is_@_valid.name'"
    assertFalse "is_conf_name_valid 'invalid with a space'"
}

test__get_config_list()
{
    mkdir -p "$TEST_CONFS_DIRS"
    assertEquals 'no configs' '' "$(CONFIGS_DIR="$TEST_CONFS_DIRS" get_config_list)"
    touch "$TEST_CONFS_DIRS"/invalid
    assertEquals 'one invalid conf' '' "$(CONFIGS_DIR="$TEST_CONFS_DIRS" get_config_list)"
    mkdir "$TEST_CONFS_DIRS"/innerdir
    assertEquals 'one directory still no configs' ''\
        "$(CONFIGS_DIR="$TEST_CONFS_DIRS" get_config_list)"
    touch "$TEST_CONFS_DIRS"/1.conf
    assertEquals 'one valid conf' "$TEST_CONFS_DIRS"/1.conf \
        "$(CONFIGS_DIR="$TEST_CONFS_DIRS" get_config_list)"
    touch "$TEST_CONFS_DIRS"/innerdir/2.conf
    assertEquals 'one valid conf ignoring the inner one' "$TEST_CONFS_DIRS"/1.conf \
        "$(CONFIGS_DIR="$TEST_CONFS_DIRS" get_config_list)"
}

# shellcheck disable=SC2034
test__get_opt_or_var_value()
{
    __TEST=
    opt___test=
    SP_DEFAULT___TEST=
    assertEquals "all vars empty" '' "$(get_opt_or_var_value '__test')"
    __TEST=
    opt___test=
    SP_DEFAULT___TEST=1
    assertEquals "only default non-empty" '1' "$(get_opt_or_var_value '__test')"
    __TEST=
    opt___test=1
    SP_DEFAULT___TEST=
    assertEquals "only option non-empty" '1' "$(get_opt_or_var_value '__test')"
    __TEST=1
    opt___test=
    SP_DEFAULT___TEST=
    assertEquals "only var non-empty" '1' "$(get_opt_or_var_value '__test')"
    __TEST=1
    opt___test=2
    SP_DEFAULT___TEST=3
    assertEquals "all vars non-empty" '2' "$(get_opt_or_var_value '__test')"
    __TEST=1
    opt___test=
    SP_DEFAULT___TEST=3
    assertEquals "only option empty" '1' "$(get_opt_or_var_value '__test')"
    unset __TEST
    unset opt___test
    unset SP_DEFAULT___TEST
    __test=1
    opt___TEST=2
    SP_DEFAULT___test=3
    assertEquals "all vars miss" '' "$(get_opt_or_var_value '__test')"
    unset __test
    unset opt___TEST
    unset SP_DEFAULT___test
    __other=1
    opt___other=2
    SP_DEFAULT___other=3
    assertEquals "other var match" '1' \
        "$(get_opt_or_var_value '__test' '__other')"
    unset __other
    unset opt___other
    unset SP_DEFAULT___other
    __OTHER=1
    SP_DEFAULT___OTHER=3
    assertEquals "all vars miss (other)" '' \
        "$(get_opt_or_var_value '__test' '__other')"
    unset __OTHER
    unset SP_DEFAULT___OTHER
}

test__bool()
{
    assertTrue "bool 'true'"
    assertTrue "bool 'yes'"
    assertTrue "bool 'y'"
    assertTrue "bool 't'"
    assertTrue "bool '1'"
    assertTrue "bool 'on'"

    assertTrue "bool 'TRUE'"
    assertTrue "bool 'YES'"
    assertTrue "bool 'Y'"
    assertTrue "bool 'T'"
    assertTrue "bool 'ON'"

    assertTrue "bool 'True'"
    assertTrue "bool 'Yes'"
    assertTrue "bool 'On'"

    assertTrue "bool 'tRUE'"
    assertTrue "bool 'yES'"
    assertTrue "bool 'oN'"

    assertFalse "bool 'false'"
    assertFalse "bool 'no'"
    assertFalse "bool 'n'"
    assertFalse "bool 'f'"
    assertFalse "bool '0'"
    assertFalse "bool 'off'"

    assertFalse "bool '10'"
    assertFalse "bool '.1'"
    assertFalse "bool 'invalid'"
    assertFalse "bool ''"
}

test__upper()
{
    assertEquals 'MUTLIPLE WORDS WITH NUM3RIC4L V@LUES AND _SPECIALS-CHARS.' \
        "$(upper 'mutliple words with num3ric4l v@lues and _specials-chars.')"
}

test__path_join()
{
    assertEquals '/' "$(path_join '//' '//')"
    assertEquals '/' "$(path_join '//' '/')"
    assertEquals '/' "$(path_join '/' '//')"
    assertEquals '/' "$(path_join '/' '/')"
    assertEquals '/' "$(path_join '/' '')"
    assertEquals '/' "$(path_join '' '/')"
    assertEquals '' "$(path_join '' '')"

    assertEquals '/tmp/test' "$(path_join '//tmp//' '//test')"
    assertEquals '/tmp/test' "$(path_join '//tmp/' '//test')"
    assertEquals '/tmp/test' "$(path_join '/tmp//' '//test')"
    assertEquals '/tmp/test' "$(path_join '//tmp//' '/test')"
    assertEquals '/tmp/test' "$(path_join '/tmp' '/test')"
    assertEquals '/tmp/test' "$(path_join '/tmp' 'test')"
    assertEquals '/tmp/test with spaces/in' "$(path_join '/tmp' 'test with spaces/in')"
}

test__btrfs_subvolumes_diff()
{
    _bak_dir="$TEST_SUBVOL_DIR_BACKUPS"
    btrfs subvolume create "$_bak_dir" >/dev/null
    mkdir "$_bak_dir"/data
    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$_bak_dir"/data/0 >/dev/null

    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$_bak_dir"/data/1 >/dev/null
    assertTrue "0 = 1" "btrfs_subvolumes_diff '$_bak_dir/data/0' '$_bak_dir/data/1'"
    assertTrue "1 = 0" "btrfs_subvolumes_diff '$_bak_dir/data/1' '$_bak_dir/data/0'"

    echo 'content for a new file' > "$TEST_SUBVOL_DIR_DATA"/new_file.txt
    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$_bak_dir"/data/2 >/dev/null
    assertTrue "0 = 1" "btrfs_subvolumes_diff '$_bak_dir/data/0' '$_bak_dir/data/1'"
    assertTrue "1 = 0" "btrfs_subvolumes_diff '$_bak_dir/data/1' '$_bak_dir/data/0'"
    assertFalse "0 != 2" "btrfs_subvolumes_diff '$_bak_dir/data/0' '$_bak_dir/data/2'"
    assertFalse "2 != 0" "btrfs_subvolumes_diff '$_bak_dir/data/2' '$_bak_dir/data/0'"
    assertFalse "1 != 2" "btrfs_subvolumes_diff '$_bak_dir/data/1' '$_bak_dir/data/2'"
    assertFalse "2 != 1" "btrfs_subvolumes_diff '$_bak_dir/data/2' '$_bak_dir/data/1'"

    echo 'a new content for an existing file' > "$TEST_SUBVOL_DIR_DATA"/new_file.txt
    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$_bak_dir"/data/3 >/dev/null
    assertTrue "0 = 1" "btrfs_subvolumes_diff '$_bak_dir/data/0' '$_bak_dir/data/1'"
    assertTrue "1 = 0" "btrfs_subvolumes_diff '$_bak_dir/data/1' '$_bak_dir/data/0'"
    assertFalse "0 != 3" "btrfs_subvolumes_diff '$_bak_dir/data/0' '$_bak_dir/data/3'"
    assertFalse "3 != 0" "btrfs_subvolumes_diff '$_bak_dir/data/3' '$_bak_dir/data/0'"
    assertFalse "1 != 3" "btrfs_subvolumes_diff '$_bak_dir/data/1' '$_bak_dir/data/3'"
    assertFalse "3 != 1" "btrfs_subvolumes_diff '$_bak_dir/data/3' '$_bak_dir/data/1'"
    assertFalse "2 != 3" "btrfs_subvolumes_diff '$_bak_dir/data/2' '$_bak_dir/data/3'"
    assertFalse "3 != 2" "btrfs_subvolumes_diff '$_bak_dir/data/3' '$_bak_dir/data/2'"

    rm -f "$TEST_SUBVOL_DIR_DATA"/new_file.txt
    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$_bak_dir"/data/4 >/dev/null
    assertTrue "0 = 4" "btrfs_subvolumes_diff '$_bak_dir/data/0' '$_bak_dir/data/4'"
    assertTrue "4 = 0" "btrfs_subvolumes_diff '$_bak_dir/data/4' '$_bak_dir/data/0'"
    assertTrue "1 = 4" "btrfs_subvolumes_diff '$_bak_dir/data/1' '$_bak_dir/data/4'"
    assertTrue "4 = 1" "btrfs_subvolumes_diff '$_bak_dir/data/4' '$_bak_dir/data/1'"
    assertFalse "2 != 4" "btrfs_subvolumes_diff '$_bak_dir/data/2' '$_bak_dir/data/4'"
    assertFalse "4 != 2" "btrfs_subvolumes_diff '$_bak_dir/data/4' '$_bak_dir/data/2'"
    assertFalse "3 != 4" "btrfs_subvolumes_diff '$_bak_dir/data/3' '$_bak_dir/data/4'"
    assertFalse "4 != 3" "btrfs_subvolumes_diff '$_bak_dir/data/4' '$_bak_dir/data/3'"
}

test__get_savepoint_timestamp()
{
    _tmp="$(mktemp)"
    assertTrue "returns true" "(get_savepoint_timestamp '2020-01-01_00h00m00' 2>'$_tmp')"
    assertEquals "empty STDERR" '' "$(cat "$_tmp")"
    assertEquals "1577833200" "$(get_savepoint_timestamp '2020-01-01_00h00m00')"
    assertFalse "invalid input should fail" "(LC_ALL=C get_savepoint_timestamp 'invalid' 2>'$_tmp')"
    assertContains "Fatal error: failed to get a date from filename 'invalid'" \
        "$(cut -c 21- "$_tmp")"
}

test__is_session_begining()
{
    assertTrue  "is_session_begining '2020-01-01_00h00m00.boot'"
    assertTrue  "is_session_begining '2020-01-01_00h00m00.resume'"
    assertFalse "is_session_begining '2020-01-01_00h00m00.invalid'"
    assertFalse "is_session_begining '2020-01-01_00h00m00.suspend'"
    assertFalse "is_session_begining '2020-01-01_00h00m00.reboot'"
    assertFalse "is_session_begining '2020-01-01_00h00m00.shutdown'"
    assertFalse "is_session_begining '2020-01-01_00h00m00.halt'"
}

test__is_session_end()
{
    assertFalse "is_session_end '2020-01-01_00h00m00.boot'"
    assertFalse "is_session_end '2020-01-01_00h00m00.resume'"
    assertFalse "is_session_end '2020-01-01_00h00m00.invalid'"
    assertTrue  "is_session_end '2020-01-01_00h00m00.suspend'"
    assertTrue  "is_session_end '2020-01-01_00h00m00.reboot'"
    assertTrue  "is_session_end '2020-01-01_00h00m00.shutdown'"
    assertTrue  "is_session_end '2020-01-01_00h00m00.halt'"
}

test__is_safe_savepoint()
{
    assertTrue  "is_safe_savepoint '2020-01-01_00h00m00.shutdown.safe'"
    assertTrue  "is_safe_savepoint '2020-01-01_00h00m00.reboot.safe'"
    assertFalse "is_safe_savepoint '2020-01-01_00h00m00.before-restoring-from-XXX.safe'"
    assertFalse "is_safe_savepoint '2020-01-01_00h00m00.after-restoration-is-equals-to-XXX.safe'"
}

test__is_btrfs_subvolume()
{
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null
    assertTrue "subvolume" "is_btrfs_subvolume '$TEST_SUBVOL_DIR_BACKUPS'"
    mkdir "$TEST_SUBVOL_DIR_BACKUPS"/data
    assertFalse "directory" "is_btrfs_subvolume '$TEST_SUBVOL_DIR_BACKUPS/data'"
    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$TEST_SUBVOL_DIR_BACKUPS"/data/0 >/dev/null
    assertTrue "snapshot" "is_btrfs_subvolume '$TEST_SUBVOL_DIR_BACKUPS/data/0'"
    ln -s '0' "$TEST_SUBVOL_DIR_BACKUPS"/data/1
    assertFalse "link" "is_btrfs_subvolume '$TEST_SUBVOL_DIR_BACKUPS/data/1'"
}

test__get_free_space_gb()
{
    _tmp="$(mktemp)"

    assertTrue "ok on dir" "get_free_space_gb '$TEST_SUBVOL_DIR_DATA' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"

    assertTrue "inexsitant should succeed anyway" \
        "get_free_space_gb '$TEST_SUBVOL_DIR_DATA/inexistant' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"

    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    assertTrue "ok on subvolume" "get_free_space_gb '$TEST_SUBVOL_DIR_BACKUPS' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"

    assertTrue "inexistant in subvolume should also succeed" \
        "get_free_space_gb '$TEST_SUBVOL_DIR_BACKUPS/inexistant' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"
}

test__ensure_enough_free_space()
{
    _tmp="$(mktemp)"

    PERSISTENT_LOG="$TEST_PERSISTENT_LOG"
    export PERSISTENT_LOG
    ENSURE_FREE_SPACE_GB='0.0'
    NO_FREE_SPACE_ACTION=fail
    export ENSURE_FREE_SPACE_GB
    export NO_FREE_SPACE_ACTION

    assertTrue "$ENSURE_FREE_SPACE_GB min free space (dir)" \
               "ensure_enough_free_space '$TEST_SUBVOL_DIR_DATA' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"

    assertTrue "$ENSURE_FREE_SPACE_GB min free space (dir inexistant)" \
               "ensure_enough_free_space '$TEST_SUBVOL_DIR_DATA/inexistant' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"

    assertTrue "$ENSURE_FREE_SPACE_GB min free space (subvolume)" \
               "ensure_enough_free_space '$TEST_SUBVOL_DIR_BACKUPS' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"

    assertTrue "$ENSURE_FREE_SPACE_GB min free space (subvolume inexistant)" \
               "ensure_enough_free_space '$TEST_SUBVOL_DIR_BACKUPS/inexistant' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"

    ENSURE_FREE_SPACE_GB='999999'
    NO_FREE_SPACE_ACTION=fail
    export ENSURE_FREE_SPACE_GB

    assertFalse "$ENSURE_FREE_SPACE_GB min free space (dir)" \
                "(ensure_enough_free_space '$TEST_SUBVOL_DIR_DATA' 2>'$_tmp')"
    assertContains 'Warning in STDERR' "$(cut -c 21- "$_tmp")" \
        "Fatal error: not enough free space for path '$TEST_SUBVOL_DIR_DATA'"
}

# test__get_date_to_text()
# {
#     assertEquals "2020-01-01_00h00m00" "$(get_date_to_text '2020-01-01 00:00:00')"
# }
# 
# test__get_date_to_std()
# {
#     assertEquals "2020-01-01 00:00:00" "$(get_date_to_std "@$(date -d '2020-01-01 00:00:00' '+%s')")"
# }
# 
# test__get_date_std_from_text()
# {
#     assertEquals "2020-01-01 00:00:00" "$(get_date_std_from_text '2020-01-01_00h00m00')"
# }

test__get_week_days()
{
    _week_out="[1] 2019-12-30_00h00m00
[2] 2019-12-31_00h00m00
[3] 2020-01-01_00h00m00
[4] 2020-01-02_00h00m00
[5] 2020-01-03_00h00m00
[6] 2020-01-04_00h00m00
[7] 2020-01-05_00h00m00"

    assertEquals "first week day 1" "$_week_out" "$(get_week_days '2019-12-31 00:00:00' || true)"
    assertEquals "first week day 2" "$_week_out" "$(get_week_days '2020-01-01 00:00:00' || true)"
    assertEquals "first week day 3" "$_week_out" "$(get_week_days '2020-01-01 00:00:00' || true)"
    assertEquals "first week day 4" "$_week_out" "$(get_week_days '2020-01-02 00:00:00' || true)"
    assertEquals "first week day 5" "$_week_out" "$(get_week_days '2020-01-03 00:00:00' || true)"
    assertEquals "first week day 6" "$_week_out" "$(get_week_days '2020-01-04 00:00:00' || true)"
    assertEquals "first week day 7" "$_week_out" "$(get_week_days '2020-01-05 00:00:00' || true)"

    _week_out_29th="[1] 2020-02-24_00h00m00
[2] 2020-02-25_00h00m00
[3] 2020-02-26_00h00m00
[4] 2020-02-27_00h00m00
[5] 2020-02-28_00h00m00
[6] 2020-02-29_00h00m00
[7] 2020-03-01_00h00m00"

    assertEquals "9th week day 1" "$_week_out_29th" "$(get_week_days '2020-02-24 00:00:00' || true)"
    assertEquals "9th week day 2" "$_week_out_29th" "$(get_week_days '2020-02-25 00:00:00' || true)"
    assertEquals "9th week day 3" "$_week_out_29th" "$(get_week_days '2020-02-26 00:00:00' || true)"
    assertEquals "9th week day 4" "$_week_out_29th" "$(get_week_days '2020-02-27 00:00:00' || true)"
    assertEquals "9th week day 5" "$_week_out_29th" "$(get_week_days '2020-02-28 00:00:00' || true)"
    assertEquals "9th week day 6" "$_week_out_29th" "$(get_week_days '2020-02-29 00:00:00' || true)"
    assertEquals "9th week day 7" "$_week_out_29th" "$(get_week_days '2020-03-01 00:00:00' || true)"

    for _day in $(seq 1 365); do
        _day_date="$(date -d "2020-01-01 +$_day days -1 day" '+%F %T' || true)"
        if [ "$_day_date" = '' ]; then
            fail "Failed to get date from day number '$_day' of year '2020'."
            return 1
        fi
        assertEquals "week days of day '$_day_date' are 7 items" '7' \
            "$(get_week_days "$_day_date" | wc -l || true)"
    done

    assertFalse "invalid date should fail" "(get_week_days 'invalid')"

    _tmp="$(mktemp)"
    assertEquals '' "$( (get_week_days 'invalid' 2>"$_tmp") || true)"
    assertContains "Error in STDERR" "$(cat "$_tmp")" \
        "Fatal error: failed to get week day of datetime 'invalid'"
}

test__ensure_positive_number()
{
    assertTrue  "ensure_positive_number '0'"
    assertTrue  "ensure_positive_number '1'"
    assertTrue  "ensure_positive_number '10'"
    assertTrue  "ensure_positive_number '010'"
    assertFalse "(ensure_positive_number '-0')"
    assertFalse "(ensure_positive_number '-1')"
    assertFalse "(ensure_positive_number '0.10')"
    assertFalse "(ensure_positive_number '10.0')"
}
test__ensure_decimal_number()
{
    assertTrue  "ensure_decimal_number '0'"
    assertTrue  "ensure_decimal_number '1'"
    assertTrue  "ensure_decimal_number '10'"
    assertTrue  "ensure_decimal_number '010'"
    assertTrue  "ensure_decimal_number '0.10'"
    assertTrue  "ensure_decimal_number '10.0'"
    assertFalse "(ensure_decimal_number '-0')"
    assertFalse "(ensure_decimal_number '-1')"
    assertFalse "(ensure_decimal_number '-1.0')"
}

test__ensure_boolean()
{
    assertTrue 'true' "ensure_boolean 'true'"
    assertTrue 'yes'  "ensure_boolean 'yes'"
    assertTrue 'y'    "ensure_boolean 'y'"
    assertTrue 't'    "ensure_boolean 't'"
    assertTrue '1'    "ensure_boolean '1'"
    assertTrue 'on'   "ensure_boolean 'on'"

    assertTrue 'TRUE' "ensure_boolean 'TRUE'"
    assertTrue 'YES ' "ensure_boolean 'YES'"
    assertTrue 'Y'    "ensure_boolean 'Y'"
    assertTrue 'T'    "ensure_boolean 'T'"
    assertTrue 'ON'   "ensure_boolean 'ON'"

    assertTrue 'True' "ensure_boolean 'True'"
    assertTrue 'Yes'  "ensure_boolean 'Yes'"
    assertTrue 'On'   "ensure_boolean 'On'"

    assertTrue 'tRUE' "ensure_boolean 'tRUE'"
    assertTrue 'yES'  "ensure_boolean 'yES'"
    assertTrue 'oN'   "ensure_boolean 'oN'"

    assertTrue 'false' "ensure_boolean 'false'"
    assertTrue 'no'    "ensure_boolean 'no'"
    assertTrue 'n'     "ensure_boolean 'n'"
    assertTrue 'f'     "ensure_boolean 'f'"
    assertTrue '0'     "ensure_boolean '0'"
    assertTrue 'off'   "ensure_boolean 'off'"

    assertTrue 'FALSE' "ensure_boolean 'FALSE'"
    assertTrue 'NO'    "ensure_boolean 'NO'"
    assertTrue 'N'     "ensure_boolean 'N'"
    assertTrue 'F'     "ensure_boolean 'F'"
    assertTrue 'OFF'   "ensure_boolean 'OFF'"

    assertTrue 'False' "ensure_boolean 'False'"
    assertTrue 'No'    "ensure_boolean 'No'"
    assertTrue 'Off'   "ensure_boolean 'Off'"

    assertTrue 'fALSE' "ensure_boolean 'fALSE'"
    assertTrue 'nO'    "ensure_boolean 'nO'"
    assertTrue 'oFF'   "ensure_boolean 'oFF'"

    assertFalse '10'      "(ensure_boolean '10')"
    assertFalse '.1'      "(ensure_boolean '.1')"
    assertFalse 'invalid' "(ensure_boolean 'invalid')"
    assertFalse '{EMPTY}' "(ensure_boolean '')"
}

test__count_list()
{
    assertEquals 'empty line without line break' '0' "$(count_list '')"
    assertEquals 'empty line with line break' '2' "$(count_list '
')"
    assertEquals 'empty line with line break (--not-empty)' '0' "$(count_list '
' --not-empty)"
    assertEquals 'one item no line break' '1' "$(count_list 'item1')"
    assertEquals 'one item on second line' '2' "$(count_list '
item1')"
    assertEquals 'one item on second line (--not-empty)' '1' "$(count_list '
item1' --not-empty)"
    assertEquals 'one item with second empty line' '2' "$(count_list 'item1
')"
    assertEquals 'one item with second empty line (--not-empty)' '1' "$(count_list 'item1
' --not-empty)"
    assertEquals 'two items' '2' "$(count_list 'item1
item2')"
    assertEquals 'two items starting at second line' '3' "$(count_list '
item1
item2')"
assertEquals 'two items starting at second line (--not-empty)' '2' "$(count_list '
item1
item2' --not-empty)"
}

test__add_to_list()
{
    _my_list=
    add_to_list '_my_list' ''
    assertEquals '' "$_my_list"
    add_to_list '_my_list' 'item1'
    assertEquals 'item1' "$_my_list"
    add_to_list '_my_list' 'item2'
    assertEquals 'item1
item2' "$_my_list"
}

test__remove_savepoint()
{
    _tmp="$(mktemp)"
    _bak_dir="$TEST_SUBVOL_DIR_BACKUPS"

    btrfs subvolume create "$_bak_dir" >/dev/null
    mkdir "$_bak_dir"/data

    PERSISTENT_LOG="$TEST_PERSISTENT_LOG"
    export PERSISTENT_LOG
    SAVEPOINTS_DIR="$_bak_dir"/data
    NAME=data
    export SAVEPOINTS_DIR
    export NAME

    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$_bak_dir"/data/0 >/dev/null
    assertTrue "delete single savepoint" \
        "remove_savepoint '$_bak_dir/data/0' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"
    assertTrue "savepoint was deleted" "[ ! -e '$_bak_dir/data/0' ]"
    assertTrue "savepoint was deleted (bis)" "[ ! -e '/root/btrfs-sp-new/tests/backups/data/0' ]"

    btrfs subvolume snapshot -r "$TEST_SUBVOL_DIR_DATA" "$_bak_dir"/data/0 >/dev/null
    ln -s '0' "$_bak_dir"/data/1
    assertTrue "delete single savepoint with single newer link" \
        "remove_savepoint '$_bak_dir/data/0' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"
    assertTrue "savepoint was deleted (with link)" "[ ! -e '$_bak_dir/data/0' ]"
    assertTrue "savepoint replace the symlink" "[ ! -L '$_bak_dir/data/1' ]"

    ln -s '1' "$_bak_dir"/data/2
    ln -s '2' "$_bak_dir"/data/3
    ln -s '3' "$_bak_dir"/data/4
    assertTrue "delete single savepoint with multiple newer links" \
        "remove_savepoint '$_bak_dir/data/1' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"
    assertTrue "savepoint was deleted (with multiple links)" "[ ! -e '$_bak_dir/data/1' ]"
    assertTrue "savepoint replace the symlink" "[ ! -L '$_bak_dir/data/2' ]"
    assertTrue "other links have not updated their target" \
         "[ '$(readlink "$_bak_dir"/data/3)' = '2' ] && "`
         `"[ '$(readlink "$_bak_dir"/data/4)' = '3' ]"

    assertTrue "delete single savepoint with multiple newer links (forced deletion)" \
        "remove_savepoint '$_bak_dir/data/2' 'true' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"
    assertTrue "savepoint was deleted (force deletion)" "[ ! -e '$_bak_dir/data/2' ]"
    assertTrue "other links have been deleted too" \
         "[ ! -e '$_bak_dir/data/3' ] && [ ! -e '$_bak_dir/data/4' ]"
}

test__remove_symlinks_recursively()
{
    mkdir "$TEST_SUBVOL_DIR_DATA"/symlinks_test
    touch "$TEST_SUBVOL_DIR_DATA"/symlinks_test/file.txt
    ln -s 'file.txt' "$TEST_SUBVOL_DIR_DATA"/symlinks_test/link1
    ln -s 'link1' "$TEST_SUBVOL_DIR_DATA"/symlinks_test/link2
    ln -s 'link2' "$TEST_SUBVOL_DIR_DATA"/symlinks_test/link3

    _tmp="$(mktemp)"
    assertTrue "symlinks removing from a file" \
        "remove_symlinks_recursively '$TEST_SUBVOL_DIR_DATA/symlinks_test/file.txt' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"
    assertTrue "file still exists" "[ -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/file.txt' ]"
    assertTrue "other links have been deleted" \
         "[ ! -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/link1' ] && "`
         `"[ ! -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/link2' ] && "`
         `"[ ! -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/link3' ]"

    rm -f "$TEST_SUBVOL_DIR_DATA"/symlinks_test/file.txt
    ln -s 'inexistant' "$TEST_SUBVOL_DIR_DATA"/symlinks_test/file.txt
    ln -s 'file.txt' "$TEST_SUBVOL_DIR_DATA"/symlinks_test/link1
    ln -s 'link1' "$TEST_SUBVOL_DIR_DATA"/symlinks_test/link2
    ln -s 'link2' "$TEST_SUBVOL_DIR_DATA"/symlinks_test/link3
    assertTrue "symlinks removing from a broken symlink" \
        "remove_symlinks_recursively '$TEST_SUBVOL_DIR_DATA/symlinks_test/file.txt' 2>'$_tmp'"
    assertSame 'empty STDERR' '' "$(cat "$_tmp")"
    assertTrue "all links have been deleted" \
         "[ ! -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/file.txt' ] && "`
         `"[ ! -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/link1' ] && "`
         `"[ ! -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/link2' ] && "`
         `"[ ! -e '$TEST_SUBVOL_DIR_DATA/symlinks_test/link3' ]"
}


# 'btrfs-sp' root directory
THIS_DIR="$(dirname "$(realpath "$0")")"

# source helper tests functions
# shellcheck disable=SC1090
. "$THIS_DIR"/test.inc.sh

# source the 'btrfs-sp' shell script
# shellcheck disable=SC2034
NO_MAIN=true
export NO_MAIN
# shellcheck disable=SC1090
. "$BTRFSSP"

# run shunit2
# shellcheck disable=SC1090
. "$SHUNIT2"
