#!/bin/sh

set -e


# shunit2 functions

oneTimeSetUp()    { __oneTimeSetUp; }
oneTimeTearDown() { __oneTimeTearDown; }
setUp()           { __setUp; }
tearDown()        { __tearDown; }


# tests cases

test__ListEmptyConfs()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"

    assertEquals "Listing configurations with none defined should print an empty string" \
        '' "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" ls-conf 2>"$_tmp")"

    assertEquals "Warning message appears" \
        "Warning: no configuration yet. You might want to create one with command 'create-conf'" \
        "$(cut -c 21- < "$_tmp")"
}

test__AddConf()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    # shellcheck disable=SC2154
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "Configuration file named 'data.conf' exists" "[ -r '$TEST_CONF_DATA' ]"

    _content="$(sed '/^$/d' "$TEST_CONF_DATA")"

    assertContains "variable 'SUBVOLUME' with value '$TEST_SUBVOL_DIR_DATA' "`
                   `"in configuration 'data' :" \
        "$_content" "SUBVOLUME='$TEST_SUBVOL_DIR_DATA'"

    assertContains "variable 'SUBVOLUME_FROM_TOPLEVEL_SUBVOL' "`
                   `"with value '$_rel_TEST_SUBVOL_DIR_DATA' in configuration 'data' :" \
        "$_content" "SUBVOLUME_FROM_TOPLEVEL_SUBVOL='$_rel_TEST_SUBVOL_DIR_DATA'"

    (
        # shellcheck disable=SC1090
        . "$TEST_CONF_GLOBAL"

        for _var in SAVEPOINTS_DIR_BASE BACKUP_BOOT BACKUP_REBOOT BACKUP_SHUTDOWN BACKUP_HALT \
                BACKUP_SUSPEND BACKUP_RESUME SUFFIX_BOOT SUFFIX_REBOOT SUFFIX_SHUTDOWN SUFFIX_HALT \
                SUFFIX_SUSPEND SUFFIX_RESUME SAFE_BACKUP KEEP_NB_SESSIONS KEEP_NB_DAYS KEEP_NB_WEEKS\
                KEEP_NB_MONTHS KEEP_NB_YEARS
        do
            eval _value="\$SP_DEFAULT_$_var"
            # shellcheck disable=SC2154
            assertContains \
                "variable '$_var' with value '$_value' in configuration 'data' :" \
                "$_content" "$_var='$_value'"
        done
    )
}

test__ListConfs()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data-bis \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _content="$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" ls-conf 2>"$_tmp")"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertEquals "lines for configurations 'data' and 'data-bis'" \
"data: $TEST_SUBVOL_DIR_DATA ==> $TEST_SUBVOL_DIR_BACKUPS/data ($TEST_DEFAULT_RETENTION_STRATEGY_TEXT)
data-bis: $TEST_SUBVOL_DIR_DATA ==> $TEST_SUBVOL_DIR_BACKUPS/data-bis ($TEST_DEFAULT_RETENTION_STRATEGY_TEXT)" \
    "$_content"
}

test__ListEmptySavepoints()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertEquals "Listing savepoints with none defined should print only config name" \
        'data' "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" ls 2>"$_tmp")"

    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"
}

test__CreateSavepointWithDefaults()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" \
        2>"$_tmp"

    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__CreateSavepointWithMoment()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.boot'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__CreateSavepointWithMomentSafe()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'reboot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.reboot.safe'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__CreateSavepointWithSuffixOption()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --suffix '.test' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.test'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__CreateSavepointWithSuffixAndMomentOption()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --suffix '.test' --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.test'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__CreateSavepointSkippedWithMoment()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'halt' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' do not exist" \
        "[ ! -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"
}

test__ListAllSavepoints()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.boot'
    _sp_name_1="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"

    # prevent the purge-diff algorithm to turn it into a symlink
    __change_data

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'suspend' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_11h35m52.suspend'
    _sp_name_2="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"

    assertEquals "Listing savepoints should print data and both savepoints" \
"data
   $_sp_name_2
   $_sp_name_1" "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" ls 2>"$_tmp")"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"
}

test__CreateSavepointNoPurgeDiffOption()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.boot'
    _sp_name_1="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"
    assertTrue "savepoints '$_sp_name' is NOT a symlink" \
        "[ ! -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'suspend' --no-purge-diff 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_11h35m52.suspend'
    _sp_name_2="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"
    assertTrue "savepoints '$_sp_name' is NOT a symlink" \
        "[ ! -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__ListConfSavepoints()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'
    _sp_name_1="$_sp_name"

    # prevent the purge-diff algorithm to turn it into a symlink
    __change_data

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'suspend' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_11h35m52.suspend'
    _sp_name_2="$_sp_name"

    assertEquals "Listing savepoints should print both savepoints" \
"$_sp_name_2
$_sp_name_1" "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data ls 2>"$_tmp")"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"
}

test__PruneByDiff()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'
    _sp_name_1="$_sp_name"

    # not chaning data between savepoints should turn the new one into a symlink
    # (targeting the previous one)

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'suspend' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_11h35m52.suspend'
    _sp_name_2="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is a symlink" \
        "[ -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    # not chaning data between savepoints should turn the new one into a symlink
    # (targeting the first one)

    _now_std='2018-04-12 14:15:36'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'resume' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_14h15m36.resume'
    _sp_name_3="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is a symlink" \
        "[ -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertTrue "savepoints '$_sp_name' symlink targets '$_sp_name_1'" \
        "[ '$(readlink "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name")' = '$_sp_name_1' ]"

    # prevent the purge-diff algorithm to turn it into a symlink
    __change_data

    _now_std='2018-04-12 15:02:51'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'shutdown' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_15h02m51.shutdown.safe'
    _sp_name_4="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is NOT a symlink" \
        "[ ! -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"
}

test__DeleteSingleSavepoint()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" rm data "$_sp_name" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints '$_sp_name' doesn't exist anymore" \
        "[ ! -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"
}

test__DeleteSavepointWithANewerSymlink()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'
    _sp_name_1="$_sp_name"

    # not chaning data between savepoints should turn the new one into a symlink
    # (targeting the previous one)

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'suspend' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_11h35m52.suspend'
    _sp_name_2="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is a symlink" \
        "[ -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    # not chaning data between savepoints should turn the new one into a symlink
    # (targeting the first one)

    _now_std='2018-04-12 14:15:36'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'resume' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_14h15m36.resume'
    _sp_name_3="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is a symlink" \
        "[ -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertTrue "savepoints '$_sp_name' symlink targets '$_sp_name_1'" \
        "[ '$(readlink "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name")' = '$_sp_name_1' ]"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" rm data "$_sp_name_1" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints '$_sp_name_1' doesn't exist anymore" \
        "[ ! -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_1' ]"

    assertTrue "savepoints '$_sp_name_2' still exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2' ]"

    assertTrue "savepoints '$_sp_name_2' is not a symlink anymore" \
        "[ ! -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2' ]"

    assertTrue "savepoints '$_sp_name_3' still exists and is a symlink" \
        "[ -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3' ]"

    assertTrue "savepoints '$_sp_name_3' symlink targets '$_sp_name_2'" \
        "[ '$(readlink "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3")' = '$_sp_name_2' ]"
}

test__DeleteWithANewerSymlinkAndForceDeletion()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'
    _sp_name_1="$_sp_name"

    # not chaning data between savepoints should turn the new one into a symlink
    # (targeting the previous one)

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'suspend' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_11h35m52.suspend'
    _sp_name_2="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is a symlink" \
        "[ -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    # not chaning data between savepoints should turn the new one into a symlink
    # (targeting the first one)

    _now_std='2018-04-12 14:15:36'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'resume' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_14h15m36.resume'
    _sp_name_3="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is a symlink" \
        "[ -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertTrue "savepoints '$_sp_name' symlink targets '$_sp_name_1'" \
        "[ '$(readlink "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name")' = '$_sp_name_1' ]"

    # prevent the purge-diff algorithm to turn it into a symlink
    __change_data

    _now_std='2018-04-12 15:02:51'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'shutdown' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_15h02m51.shutdown.safe'
    _sp_name_4="$_sp_name"

    assertTrue "savepoints '$_sp_name' exists and is NOT a symlink" \
        "[ ! -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" rm --force-deletion data "$_sp_name_1" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints '$_sp_name_1' doesn't exist anymore" \
        "[ ! -e '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_1' ]"

    assertTrue "savepoints '$_sp_name_2' doesn't exist anymore" \
        "[ ! -e '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2' ]"

    assertTrue "savepoints '$_sp_name_3' doesn't exist anymore" \
        "[ ! -e '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3' ]"

    assertTrue "savepoints '$_sp_name_4' still exists and is still NOT a symlink" \
        "[ ! -L '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_4' ]"
}

test__RestoreSubvolume()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.boot'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    _tree_before_change="$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)"

    assertSame "data tree and savepoint 1 tree are the same" \
        "$_tree_before_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"

    # create a change to see the differences with after restoration
    __change_data

    _tree_after_change="$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)"

    _now_std='2018-04-12 11:35:52'

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" restore data "$_sp_name" \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name_2="2018-04-12_11h35m52.0.before-restoring-from-$_sp_name"
    _sp_name_3="2018-04-12_11h35m52.1.after-restoration-is-equals-to-$_sp_name"

    assertTrue "savepoints '$_sp_name_2' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2' ]"

    assertSame "data tree and savepoint 2 tree are the same" \
        "$_tree_after_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2" | tail -n +2)"

    assertTrue "savepoints '$_sp_name_3' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3' ]"

    assertSame "data tree and savepoint 3 tree are the same" \
        "$_tree_before_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3" | tail -n +2)"
}

test__RestoreSubvolume()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"

    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27.boot'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    _tree_before_change="$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)"

    assertSame "data tree and savepoint 1 tree are the same" \
        "$_tree_before_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"

    # create a change to see the differences with after restoration
    __change_data

    _tree_after_change="$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)"

    _now_std='2018-04-12 11:35:52'

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" restore data "$_sp_name" \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name_2="2018-04-12_11h35m52.0.before-restoring-from-$_sp_name"
    _sp_name_3="2018-04-12_11h35m52.1.after-restoration-is-equals-to-$_sp_name"

    assertTrue "savepoints '$_sp_name_2' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2' ]"

    assertSame "data tree and savepoint 2 tree are the same" \
        "$_tree_after_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2" | tail -n +2)"

    assertTrue "savepoints '$_sp_name_3' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3' ]"

    assertSame "data tree and savepoint 3 tree are the same" \
        "$_tree_before_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3" | tail -n +2)"
}

test__LogRead()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'
    _sp_name_1="$_sp_name"

    assertEquals "log file content contains the new savepoint line" \
"[data] CMD backup '$_sp_name_1'
[data] + $_sp_name_1 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-number" \
    "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log 2>"$_tmp" | cut -c 21-)"

    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    # not chaning data between savepoints should turn the new one into a symlink
    # (targeting the previous one)

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'suspend' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_11h35m52.suspend'
    _sp_name_2="$_sp_name"

    assertEquals "log file content contains the 2nd savepoint lines" \
"[data] CMD backup '$_sp_name_1'
[data] + $_sp_name_1 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-number
[data] CMD backup '$_sp_name_2'
[data] + $_sp_name_2 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] - $_sp_name_2
[data] = $_sp_name_2 -> $_sp_name_1
[data] ALG purge-number" \
    "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log 2>"$_tmp" | cut -c 21-)"

    # create a change to see the differences with after restoration
    __change_data

    _now_std='2018-04-12 14:15:36'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" restore data "$_sp_name_1" \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name_3="2018-04-12_14h15m36.0.before-restoring-from-$_sp_name_1"
    _sp_name_4="2018-04-12_14h15m36.1.after-restoration-is-equals-to-$_sp_name_1"

    assertEquals "log file content contains the restorations lines" \
"[data] CMD backup '$_sp_name_1'
[data] + $_sp_name_1 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-number
[data] CMD backup '$_sp_name_2'
[data] + $_sp_name_2 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] - $_sp_name_2
[data] = $_sp_name_2 -> $_sp_name_1
[data] ALG purge-number
[data] CMD restore '$_sp_name_1'
[data] + $_sp_name_3 <== $TEST_SUBVOL_DIR_DATA
[data] - $TEST_SUBVOL_DIR_DATA
[data] + $TEST_SUBVOL_DIR_DATA <<< $_sp_name_1
[data] + $_sp_name_4 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] ALG purge-number" \
    "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log 2>"$_tmp" | cut -c 21-)"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" rm data "$_sp_name_1" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertEquals "log file content contains the deletion line" \
"[data] CMD backup '$_sp_name_1'
[data] + $_sp_name_1 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-number
[data] CMD backup '$_sp_name_2'
[data] + $_sp_name_2 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] - $_sp_name_2
[data] = $_sp_name_2 -> $_sp_name_1
[data] ALG purge-number
[data] CMD restore '$_sp_name_1'
[data] + $_sp_name_3 <== $TEST_SUBVOL_DIR_DATA
[data] - $TEST_SUBVOL_DIR_DATA
[data] + $TEST_SUBVOL_DIR_DATA <<< $_sp_name_1
[data] + $_sp_name_4 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] ALG purge-number
[data] CMD delete '$_sp_name_1'
[data] - $_sp_name_1
[data] = $_sp_name_2 <- $_sp_name_1" \
    "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log 2>"$_tmp" | cut -c 21-)"

    _now_std='2018-04-12 15:02:51'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'shutdown' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_15h02m51.shutdown.safe'
    _sp_name_5="$_sp_name"

    assertEquals "log file content contains the new/last savepoint line" \
"[data] CMD backup '$_sp_name_1'
[data] + $_sp_name_1 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-number
[data] CMD backup '$_sp_name_2'
[data] + $_sp_name_2 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] - $_sp_name_2
[data] = $_sp_name_2 -> $_sp_name_1
[data] ALG purge-number
[data] CMD restore '$_sp_name_1'
[data] + $_sp_name_3 <== $TEST_SUBVOL_DIR_DATA
[data] - $TEST_SUBVOL_DIR_DATA
[data] + $TEST_SUBVOL_DIR_DATA <<< $_sp_name_1
[data] + $_sp_name_4 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] ALG purge-number
[data] CMD delete '$_sp_name_1'
[data] - $_sp_name_1
[data] = $_sp_name_2 <- $_sp_name_1
[data] CMD backup '$_sp_name_5'
[data] + $_sp_name_5 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] - $_sp_name_5
[data] = $_sp_name_5 -> $_sp_name_4
[data] ALG purge-number" \
    "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log 2>"$_tmp" | cut -c 21-)"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" rm data --force-deletion "$_sp_name_4" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertEquals "log file content contains the 2nd deletion line" \
"[data] CMD backup '$_sp_name_1'
[data] + $_sp_name_1 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-number
[data] CMD backup '$_sp_name_2'
[data] + $_sp_name_2 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] - $_sp_name_2
[data] = $_sp_name_2 -> $_sp_name_1
[data] ALG purge-number
[data] CMD restore '$_sp_name_1'
[data] + $_sp_name_3 <== $TEST_SUBVOL_DIR_DATA
[data] - $TEST_SUBVOL_DIR_DATA
[data] + $TEST_SUBVOL_DIR_DATA <<< $_sp_name_1
[data] + $_sp_name_4 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] ALG purge-number
[data] CMD delete '$_sp_name_1'
[data] - $_sp_name_1
[data] = $_sp_name_2 <- $_sp_name_1
[data] CMD backup '$_sp_name_5'
[data] + $_sp_name_5 <== $TEST_SUBVOL_DIR_DATA
[data] ALG purge-diff
[data] - $_sp_name_5
[data] = $_sp_name_5 -> $_sp_name_4
[data] ALG purge-number
[data] CMD delete '$_sp_name_4' (--force-deletion)
[data] - $_sp_name_5 ( -> $_sp_name_4)
[data] - $_sp_name_4" \
    "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log 2>"$_tmp" | cut -c 21-)"
}

test__LogWrite()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log-write "This is a test
on two lines" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertEquals "log file content contains the first line" \
"This is a test" \
    "$(LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" log 2>"$_tmp" | cut -c 21-)"
}

test__CreateSavepointWithOwnConfSavepointsDir()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _alternate_backup_dir="${TEST_SUBVOL_DIR_BACKUPS}-bis"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$_alternate_backup_dir" >/dev/null

    _now_std='2018-04-12 08:53:27'
    _sp_name='2018-04-12_08h53m27'

    __set_config_var "$TEST_CONF_DATA" 'SAVEPOINTS_DIR_BASE' "$_alternate_backup_dir"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$_alternate_backup_dir/data' exists" \
        "[ -d '$_alternate_backup_dir/data' ]"

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$_alternate_backup_dir/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$_alternate_backup_dir/data/$_sp_name" | tail -n +2)"

    mv "$_alternate_backup_dir" "$TEST_SUBVOL_DIR_BACKUPS"
}

test__CreateSavepointWithHooks()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    _sp_name='2018-04-12_08h53m27'

    _hook="$(mktemp)"
    cat > "$_hook" <<ENDCAT
#!/bin/sh

set -e

echo "\$1" >&2
echo "\$2" >&2

[ "\$1" = '$TEST_SUBVOL_DIR_DATA' ] && [ "\$2" = '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]
ENDCAT
    if ! sh -n "$_hook"; then
        fail "hook script is invalid"
    fi
    chmod +x "$_hook"

    __set_config_var "$TEST_CONF_DATA" 'HOOK_BEFORE_BACKUP' "$_hook"
    __set_config_var "$TEST_CONF_DATA" 'HOOK_AFTER_BACKUP' "$_hook"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    rm -f "$_hook"
    assertEquals "STDERR containes twice (before/after) both arguments" \
"$TEST_SUBVOL_DIR_DATA
$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name
$TEST_SUBVOL_DIR_DATA
$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__RestoreSavepointWithHooks()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    _tree_before_change="$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)"

    assertSame "data tree and savepoint 1 tree are the same" \
        "$_tree_before_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"

    # create a change to see the differences with after restoration
    __change_data

    _tree_after_change="$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)"

    _hook="$(mktemp)"
    cat > "$_hook" <<ENDCAT
#!/bin/sh

set -e

echo "\$1" >&2
echo "\$2" >&2

[ "\$1" = '$TEST_SUBVOL_DIR_DATA' ] && [ "\$2" = '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]
ENDCAT
    if ! sh -n "$_hook"; then
        fail "hook script is invalid"
    fi
    chmod +x "$_hook"

    __set_config_var "$TEST_CONF_DATA" 'HOOK_BEFORE_RESTORE' "$_hook"
    __set_config_var "$TEST_CONF_DATA" 'HOOK_AFTER_RESTORE' "$_hook"

    _now_std='2018-04-12 11:35:52'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" restore data "$_sp_name" \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    rm -f "$_hook"
    assertEquals "STDERR containes twice (before/after) both arguments" \
"$TEST_SUBVOL_DIR_DATA
$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name
$TEST_SUBVOL_DIR_DATA
$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" "$(cat "$_tmp")"

    _sp_name_2="2018-04-12_11h35m52.0.before-restoring-from-$_sp_name"
    _sp_name_3="2018-04-12_11h35m52.1.after-restoration-is-equals-to-$_sp_name"

    assertTrue "savepoints '$_sp_name_2' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2' ]"

    assertSame "data tree and savepoint 2 tree are the same" \
        "$_tree_after_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_2" | tail -n +2)"

    assertTrue "savepoints '$_sp_name_3' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3' ]"

    assertSame "data tree and savepoint 3 tree are the same" \
        "$_tree_before_change" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name_3" | tail -n +2)"
}

test__DeleteWithHooks()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" --moment 'boot' 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    _sp_name='2018-04-12_08h53m27.boot'

    _hook="$(mktemp)"
    cat > "$_hook" <<ENDCAT
#!/bin/sh

set -e

echo "\$1" >&2

[ "\$1" = '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]
ENDCAT
    if ! sh -n "$_hook"; then
        fail "hook script is invalid"
    fi
    chmod +x "$_hook"

    __set_config_var "$TEST_CONF_DATA" 'HOOK_BEFORE_DELETE' "$_hook"
    __set_config_var "$TEST_CONF_DATA" 'HOOK_AFTER_DELETE' "$_hook"

    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" rm data "$_sp_name" 2>"$_tmp"
    rm -f "$_hook"
    assertEquals "STDERR containes twice (before/after) the argument" \
"$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name
$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" "$(cat "$_tmp")"

    assertTrue "savepoints '$_sp_name' doesn't exist anymore" \
        "[ ! -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"
}

test__CreateSavepointWithNotEnoughFreeSpaceAndDefaultAction()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    # make sure there is not enough free space
    __set_config_var "$TEST_CONF_GLOBAL" 'ENSURE_FREE_SPACE_GB' 999999

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    assertContains "fatal error for not enough space" "$(cat "$_tmp")" \
"Fatal error: not enough free space for path '$TEST_SUBVOL_DIR_BACKUPS/data'"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' doesn't exist" \
        "[ ! -e '$TEST_SUBVOL_DIR_BACKUPS/data' ]"
}

test__CreateSavepointWithNotEnoughFreeSpaceAndWarnAction()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    # make sure there is not enough free space
    __set_config_var "$TEST_CONF_GLOBAL" 'ENSURE_FREE_SPACE_GB' 999999
    __set_config_var "$TEST_CONF_GLOBAL" 'NO_FREE_SPACE_ACTION' 'warn'

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    assertContains "warning for not enough space" "$(cat "$_tmp")" \
"Warning: not enough free space for path '$TEST_SUBVOL_DIR_BACKUPS/data'"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

test__CreateSavepointWithNotEnoughFreeSpaceAndPruneAction()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    # make sure there is not enough free space
    __set_config_var "$TEST_CONF_GLOBAL" 'ENSURE_FREE_SPACE_GB' 999999
    __set_config_var "$TEST_CONF_GLOBAL" 'NO_FREE_SPACE_ACTION' 'prune'

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    assertContains "fatal error for not enough space" "$(cat "$_tmp")" \
"Fatal error: not enough free space for path '$TEST_SUBVOL_DIR_BACKUPS/data'"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' doesn't exist" \
        "[ ! -e '$TEST_SUBVOL_DIR_BACKUPS/data' ]"
}

test__CreateSavepointWithNotEnoughFreeSpaceAndShellAction()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    _script="$(mktemp)"
    cat > "$_script" <<ENDCAT
#!/bin/sh

set -e

echo "\$1" >&2
echo "\$2" >&2
echo "\$3" >&2
ENDCAT
    if ! sh -n "$_script"; then
        fail "shell script is invalid"
    fi
    chmod +x "$_script"

    # make sure there is not enough free space
    __set_config_var "$TEST_CONF_GLOBAL" 'ENSURE_FREE_SPACE_GB' 999999
    __set_config_var "$TEST_CONF_GLOBAL" 'NO_FREE_SPACE_ACTION' "shell:$_script"

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data \
        "$TEST_SUBVOL_DIR_DATA" "$_rel_TEST_SUBVOL_DIR_DATA" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    __debug "   creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" 2>"$_tmp"
    rm -f "$_script"

    assertSame "STDERR contains first argument passed to the shell script" \
        "$TEST_SUBVOL_DIR_BACKUPS/data" "$(tail -n +1 "$_tmp" | head -n 1)"

    assertSame "STDERR contains last argument passed to the shell script" \
        '999999' "$(tail -n +3 "$_tmp" | head -n 1)"

    assertContains "fatal error for not enough space" "$(cat "$_tmp")" \
"Fatal error: not enough free space for path '$TEST_SUBVOL_DIR_BACKUPS/data'"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' doesn't exist" \
        "[ ! -e '$TEST_SUBVOL_DIR_BACKUPS/data' ]"
}

# 'btrfs-sp' root directory
THIS_DIR="$(dirname "$(realpath "$0")")"

# source helper tests functions
# shellcheck disable=SC1090
. "$THIS_DIR"/test.inc.sh

# run shunit2
# shellcheck disable=SC1090
. "$SHUNIT2"
