#!/bin/sh
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

# initramfs hook that includes btrfs-sp and its dependencies

# install it to /etc/initramfs-tools/hooks/btrfs-sp

# TODO add the tree binary for the tests in initramfs

set -e

PREFIX=
BTRFS_SP_CONFIG_PATH="$PREFIX"/etc/btrfs-sp/btrfs-sp.conf
BTRFS_SP_CONF_INITRAMFS="$PREFIX"/etc/btrfs-sp/initramfs.conf

# get the language, in its short form if it is possible
#(see gettext documentation about LANGUAGE)
# @param  $1  string  the locale (ll_TT.CHARSET)
get_language()
{
    [ "$(printf '%s' "$1" | wc -c)" -gt 2 ] || echo "$1"
    _language="$1"
    if echo "$_language" | grep -q '\.UTF-8$'; then
        _language="$(echo "$_language" | sed 's/\.UTF-8$//')"
    fi
    _language_first="$(echo "$_language" | sed 's/^\([^_]\+\)_.*$/\1/')"
    _language_second="$(echo "$_language" | sed 's/^[^_]\+_\(.*\)$/\1/')"
    if [ "$_language_first" = "$(echo "$_language_second" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "$_language_first"
    else
        echo "$1"
    fi
}

# replace a (SHELL) variable in a file
# @param  $1  string  the variable name
# @param  $2  string  the variable value (that will be double quoted)
# @param  $3  string  path of the file to create or modify (in place)
replace_var_in_file()
{
    if [ -r "$3" ] && grep -q "^ *$1 *=.*$" "$3"; then
        sed "s|^\( *$1=\).*$|\1"'"'"$2"'"'"|g" -i "$3"
    else
        echo "$1="'"'"$2"'"' >> "$3"
    fi
}

# display prerequisites
if [ "$1" = 'prereqs' ]; then
    echo 'btrfs resume'
    exit 0
fi

# source initramfs helper functions for hooks
# shellcheck disable=SC1091
. /usr/share/initramfs-tools/hook-functions

# update the path to find system binaries
PATH="$PATH:/usr/sbin"
export PATH

# add the 'btrfs-sp' binary and its configuration
if BTRFSSP_BIN="$(command -v btrfs-sp)"; then
    copy_exec "$BTRFSSP_BIN" /sbin

    # add configurations and inject the locale
    if [ -r "$BTRFS_SP_CONFIG_PATH" ]; then
        copy_file configuration "$BTRFS_SP_CONFIG_PATH"
        [ "$LANGUAGE" = '' ] || \
            replace_var_in_file 'LANGUAGE' "$LANGUAGE" "${DESTDIR}$BTRFS_SP_CONFIG_PATH"
        [ "$LC_ALL" = '' ] || \
            replace_var_in_file 'LC_ALL' "$LC_ALL" "${DESTDIR}$BTRFS_SP_CONFIG_PATH"
        [ "$LANG" = '' ] || \
            replace_var_in_file 'LANG' "$LANG" "${DESTDIR}$BTRFS_SP_CONFIG_PATH"
    fi
    if [ -r "$BTRFS_SP_CONF_INITRAMFS" ]; then
        copy_file configuration "$BTRFS_SP_CONF_INITRAMFS"
        [ "$LANGUAGE" = '' ] || \
            replace_var_in_file 'LANGUAGE' "$LANGUAGE" "${DESTDIR}$BTRFS_SP_CONF_INITRAMFS"
        [ "$LC_ALL" = '' ] || \
            replace_var_in_file 'LC_ALL' "$LC_ALL" "${DESTDIR}$BTRFS_SP_CONF_INITRAMFS"
        [ "$LANG" = '' ] || \
            replace_var_in_file 'LANG' "$LANG" "${DESTDIR}$BTRFS_SP_CONF_INITRAMFS"
    fi

    # add the others binaries
    for bin in gettext date; do
        if OTHER_BIN="$(command -v "$bin")"; then
            if [ -e "$DESTDIR/bin/$bin" ] && ! diff -q "$OTHER_BIN" "$DESTDIR/bin/$bin" >/dev/null
            then
                mv "$DESTDIR/bin/$bin" "$DESTDIR/bin/$bin.busybox"
            fi
            copy_exec "$OTHER_BIN" /bin
        fi
    done
else
    printf "Warning: binary '%s' not found\n" 'btrfs-sp' >&2
fi

# add the 'btrfs-sp-restore-gui' binary and its configuration
if BTRFSSP_GUI_BIN="$(command -v btrfs-sp-restore-gui)"; then
    copy_exec "$BTRFSSP_GUI_BIN" /sbin

    # add the 'dialog' binary
    if DIALOG_BIN="$(command -v whiptail 2>/dev/null)" || \
            DIALOG_BIN="$(command -v dialog 2>/dev/null)"; then
        copy_exec "$DIALOG_BIN" /bin
    fi

    # # add GUI dependencies (ncurses-bin)
    # for bin in clear infocmp tabs tic toe tput tset captoinfo infotocap reset; do
    #     if OTHER_BIN="$(command -v "$bin")"; then
    #         if [ -e "$DESTDIR/bin/$bin" ] && ! diff -q "$OTHER_BIN" "$DESTDIR/bin/$bin" >/dev/null
    #         then
    #             mv "$DESTDIR/bin/$bin" "$DESTDIR/bin/$bin.busybox"
    #         fi
    #         copy_exec "$OTHER_BIN" /bin
    #     fi
    # done

    # add more GUI dependencies (terminfo)
    copy_file 'file' /lib/terminfo/l/linux
else
    printf "Warning: binary '%s' not found\n" 'btrfs-sp-restore-gui' >&2
fi

# add the 'btrfs-diff' binary and its configuration
if BTRFS_DIFF_BIN="$(command -v btrfs-diff)"; then
    copy_exec "$BTRFS_DIFF_BIN" /bin
fi

# set LOCALES
if [ "$LOCALES" = '' ]; then
    if [ "$LANGUAGE" != '' ];then
        LOCALES="$(echo "$LANGUAGE" | sed 's/:/ /g')"
    elif [ "$LC_ALL" != '' ] && [ "$LC_ALL" != 'C' ] &&  [ "$LC_ALL" != 'C.UTF-8' ]; then
        LOCALES="$LC_ALL"
    elif [ "$LANG" != '' ] && [ "$LANG" != 'C' ] &&  [ "$LANG" != 'C.UTF-8' ]; then
        LOCALES="$LANG"
    fi
fi

# add the locales
if [ "$LOCALES" != '' ]; then
    locales_dir_src=/usr/share/locale
    for locale in $LOCALES; do
        lang="$(get_language "$locale")"
        for textdomain in btrfs-sp btrfs-sp-restore-gui btrfs-sp-initramfs-script cryptsetup; do
            mo="$locales_dir_src/$lang/LC_MESSAGES/${textdomain}.mo"
            copy_file 'file' "$mo"
        done

        # include locale-archive build by 'locale-gen' else gettext doesn't work
        if [ -e /usr/lib/locale/locale-archive ]; then

            # be careful: this file can be quite large if it store more than the current locale
            if command -v localedef >/dev/null 2>&1; then
                _locale_normalized="$(echo "$locale" \
                                     |sed -e 's/UTF-\?\(8\|16\)/utf\1/g' -e 's/UTF/utf/g')"
                if [ "$(localedef --list-archive)" != "$_locale_normalized" ]; then
                    echo "WARNING: the locale-archive contains more than the current locale "`
                         `"'$_locale_normalized' (see 'localedef --list-archive')"
                    _locale_archive_size="$(du -sh /usr/lib/locale/locale-archive)"
                    echo "WARNING: the current file's size of '/usr/lib/locale/locale-archive' is "`
                         `"'$_locale_archive_size'" >&2
                fi
            fi
            copy_file 'file' /usr/lib/locale/locale-archive

        # compiled locales
        elif [ -d /usr/lib/locale/"$LANG" ]; then
            for f in /usr/lib/locale/"$LANG"/LC_*; do
                copy_file 'file' "$f" # ignore failure
            done
        fi
    done
fi

# ensure date and time are local to the user's timezone
# to avoid aving btrfs-sp savepoint appareaing in the past when they were more recent
if [ -r /etc/localtime ] && [ ! -e "$DESTDIR"/etc/localtime ]; then
    copy_file configuration /etc/localtime
fi
