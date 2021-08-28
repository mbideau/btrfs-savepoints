#!/bin/sh

set -e


# shunit2 functions

oneTimeSetUp()    { __oneTimeSetUp; }
oneTimeTearDown() { __oneTimeTearDown; }
setUp()           { __setUp; }
tearDown()        { __tearDown; }


# tests cases

test__AddConfWithNameWithSpace()
{
    __warn "Not implemented (yet)"
}

test__AddConfWithNonExistentSubvolume()
{
    __warn "Not implemented (yet)"
}

test__AddConfWithInvalidSubvolume()
{
    __warn "Not implemented (yet)"
}

test__ListConfsNonExistentConf()
{
    __warn "Not implemented (yet)"
}

test__ListConfsWithInvalidConf()
{
    __warn "Not implemented (yet)"
}

test__CreateSavepointWithInvalidMoment()
{
    __warn "Not implemented (yet)"
}

test__CreateSavepointWithSuffixWithSpace()
{
    __warn "Not implemented (yet)"
}

test__ListAllSavepoints()
{
    __warn "Not implemented (yet)"
}

test__ListConfSavepoints()
{
    __warn "Not implemented (yet)"
}

test__DeleteSavepoint()
{
    __warn "Not implemented (yet)"
}

test__RestoreSubvolume()
{
    __warn "Not implemented (yet)"
}

test__PruneByDiff()
{
    __warn "Not implemented (yet)"
}

test__LogWrite()
{
    __warn "Not implemented (yet)"
}

test__LogRead()
{
    __warn "Not implemented (yet)"
}

test__PruneByNumber()
{
    __warn "Not implemented (yet)"
}

test__GlobalConfigOption()
{
    __warn "Not implemented (yet)"
}

test__FromToplevelSubvolOption()
{
    __warn "Not implemented (yet)"
}

test__CreateBackupSafeOption()
{
    __warn "Not implemented (yet)"
}

test__CreateBackupMomentOption()
{
    __warn "Not implemented (yet)"
}

test__CreateBackupSuffixOption()
{
    __warn "Not implemented (yet)"
}

test__CreateBackupNoPurgeDiffOption()
{
    __warn "Not implemented (yet)"
}

test__CreateBackupWithOwnConfSavepointsDir()
{
    __warn "Not implemented (yet)"
}

# 'btrfs-sp' root directory
THIS_DIR="$(dirname "$(realpath "$0")")"

# source helper tests functions
# shellcheck disable=SC1090
. "$THIS_DIR"/test.inc.sh

# run shunit2
# shellcheck disable=SC1090
. "$SHUNIT2"
