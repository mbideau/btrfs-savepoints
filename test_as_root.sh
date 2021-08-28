#!/bin/sh

set -e


# shunit2 functions

oneTimeSetUp()    { __oneTimeSetUp; }
oneTimeTearDown() { __oneTimeTearDown; }
setUp()           { __setUp; }
tearDown()        { __tearDown; }


# tests cases

testCreateSavepointWithFromToplevelSubvolOption()
{
    # shellcheck disable=SC2086
    __create_global_conf $TEST_DEFAULT_RETENTION_STRATEGY

    __debug "Creating a subvolume for 'backups'\n"
    btrfs subvolume create "$TEST_SUBVOL_DIR_BACKUPS" >/dev/null

    # mounting the BTRFS top level subvolume
    _toplevel_subvol_mnt='/mnt/toplevel_subvol'
    __debug "Mounting BTRFS top level subvolume to '%s'\n" "$_toplevel_subvol_mnt"
    if ! __mount_toplevel_subvol "$_toplevel_subvol_mnt" "$TEST_SUBVOL_DIR_BACKUPS"; then
        fail "mounting the BTRFS top level subvolume to '$_toplevel_subvol_mnt' "`
             `"from dir '$TEST_SUBVOL_DIR_BACKUPS'"
        return 1
    fi

    # updating global configuration with relative paths
    __set_config_var "$TEST_CONF_GLOBAL" 'LOCAL_CONF_FROM_TOPLEVEL_SUBVOL' \
        "$_rel_TEST_LOCAL_CONF"
    __set_config_var "$TEST_CONF_GLOBAL" 'CONFIGS_DIR_FROM_TOPLEVEL_SUBVOL' \
        "$_rel_TEST_CONFS_DIRS"
    __set_config_var "$TEST_CONF_GLOBAL" 'PERSISTENT_LOG_FROM_TOPLEVEL_SUBVOL' \
        "$_rel_TEST_PERSISTENT_LOG"

    _tmp="$(mktemp)"
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" add-conf data "$TEST_SUBVOL_DIR_DATA" \
        "$_rel_TEST_SUBVOL_DIR_DATA" --from-toplevel-subvol "$_toplevel_subvol_mnt" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    # updating configuration with relative path
    __set_config_var "$TEST_CONF_DATA" 'SAVEPOINTS_DIR_FROM_TOPLEVEL_SUBVOL' \
        "$_rel_TEST_SUBVOL_DIR_BACKUPS"

    _now_std='2018-04-12 08:53:27'
    LC_ALL=C "$BTRFSSP" --global-config "$TEST_CONF_GLOBAL" --config data backup \
        --now "$_now_std" --date "$_now_std" \
        --from-toplevel-subvol "$_toplevel_subvol_mnt" 2>"$_tmp"
    assertEquals "Empty STDERR" '' "$(cat "$_tmp")"

    assertTrue "savepoints dir '$TEST_SUBVOL_DIR_BACKUPS/data' exists" \
        "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data' ]"

    _sp_name='2018-04-12_08h53m27'

    assertTrue "savepoints '$_sp_name' exists" "[ -d '$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name' ]"

    assertSame "data tree and savepoint tree are the same" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_DATA" | tail -n +2)" \
        "$(tree --noreport -n "$TEST_SUBVOL_DIR_BACKUPS/data/$_sp_name" | tail -n +2)"
}

# 'btrfs-sp' root directory
THIS_DIR="$(dirname "$(realpath "$0")")"

# source helper tests functions
# shellcheck disable=SC1090
. "$THIS_DIR"/test.inc.sh

# run shunit2
# shellcheck disable=SC1090
. "$SHUNIT2"
