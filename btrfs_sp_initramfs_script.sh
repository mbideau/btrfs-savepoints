#!/bin/sh
#
# initramfs script that uses btrfs-sp to create savepoint and eventually restore the system from one
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

# install it to: /etc/initramfs-tools/scripts/local-premount/btrfs-sp
# then update initramfs files with: 'update-initramfs -tuck all'
# after reboot: check that 'btrfs-sp ls' is showing a new savepoint

# halt on first error
set -e

# pre-requisites
PREREQS='btrfs resume'

# configuration
BTRFS_SP_CONFIG_PATH=/etc/btrfs-sp/initramfs.conf

# technical vars
MSG_DATETIME_FORMAT='%Y-%m-%d %H:%M:%S '
PLYMOUTH_CALLBACK=false
REBOOT=false
THIS_SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# program name
PROGRAM_NAME=btrfs-sp-initramfs-script

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

# parse the kernel command line and return True if a restoration is specified
is_restoration_specified_via_kernel_cmdline()
{
    [ "$GUI_START_KERNEL_CMDLINE_KEY" != '' ] && \
        grep -q "\\(^\\| \\)$GUI_START_KERNEL_CMDLINE_KEY\\(\$\\| \\)" /proc/cmdline
}

# return 0 if the system have resumed (or is supposed to)
have_system_resumed()
{
    grep -q "\\(^\\| \\)resume=[^ ]\\+\\(\$\\| \\)" /proc/cmdline
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

# mount the BTRFS top level subvolume
#
# inspired from 'initramfs-tools/scripts/local::local_mount_root()'
#
# @param  $1  string  path where to mount the filesystem
#
# Note: use functions and variables defined in the initramfs helpers scripts,
#       so ensure those files are sourced first:
#         - initramfs-tools/scripts/functions
#         - initramfs-tools/scripts/local
#
mount_btrfs_toplevel_subvol()
{
    debug "Mounting BTRFS top level subvolume to '%s'" "$1"

    # shellcheck disable=SC2174
    if [ "$1" = '' ]; then
        debug "No BTRFS top level subvolume mount point specified."
        panic "No BTRFS top level subvolume mount point specified."
    elif LC_ALL=C mount | grep -q " on $1 "; then
        debug "A filesystem is already mounted on BTRFS top level subvolume mount point '%s'." "$1"
        panic "A filesystem is already mounted on BTRFS top level subvolume mount point '$1'."
    elif [ ! -d "$1" ] && ! mkdir -m "0770" -p "$1"; then
        debug "Failed to create directory '%s'." "$1"
        panic "Failed to create directory '$1'."
    fi

    # top scripts are supposed to have ran (because this script should be in local-premount)
    # no need to close the device mapped previously, because they will be reused

    debug "Root var (ROOT) is: '%s'" "$ROOT"
    if [ "$ROOT" = '' ]; then
        debug "No root device specified. Boot arguments must include a root= parameter."
        panic "No root device specified. Boot arguments must include a root= parameter."
    fi

    if [ -x /scripts/local-premount/btrfs ]; then
       debug "Running script 'btrfs' ..."
       /scripts/local-premount/btrfs || true
    else
       debug "Scanning btrfs devices ..."
       btrfs device scan || true
    fi

    debug "Running device setup (local_device_setup) ..."
    set +e
    local_device_setup "$ROOT" "root file system" || true
    set -e
    debug "Device var (DEV) is: '%s'" "$DEV"
    ROOT="$DEV"
    debug "Root var (ROOT) is now: '%s'" "$ROOT"

    # Get the root filesystem type if not set
    debug "Root filesystem type is: '%s'" "$ROOTFSTYPE"
    if [ "$ROOTFSTYPE" = '' ] || [ "$ROOTFSTYPE" = auto ]; then
        FSTYPE=$(get_fstype "$ROOT")
    else
        FSTYPE=$ROOTFSTYPE
    fi
    debug "Detected filesystem type: '%s'" "$FSTYPE"

    _fstype_opt=
    if [ "$FSTYPE" != '' ]; then
        _fstype_opt="-t $FSTYPE"
    fi

    debug "Checking filesystem ('%s' root '%s') ..." "$ROOT" "$FSTYPE"
    set +e
    checkfs "$ROOT" root "$FSTYPE"
    set -e

    # ensure mount options have the 'subvol' or 'subvolid' parameter
    debug "Ensuring mount options have the 'subvol' or 'subvolid' parameter"
    if ! echo "$ROOTFLAGS" | sed 's/^-o \+//' | grep -q '\(^\|,\)subvol\(id\)\?='; then
        debug "No parameter 'subvol' or 'subvolid' in root flags '%s'." "$ROOTFLAGS"
        panic "No parameter 'subvol' or 'subvolid' in root flags '$ROOTFLAGS'."
    fi

    # replace the 'subvol' value option with '/' and 'subvolid' with '5'
    debug "Replacing the 'subvol' value option with '/' and 'subvolid' with '5'"
    _rootflags="$(echo "$ROOTFLAGS" | sed 's/^-o \+//' \
                |sed 's/\(^\|,\)subvol=[^,]\+\(,\|$\)/\1subvol=\/\2/g' \
                |sed 's/\(^\|,\)subvolid=[^,]\+\(,\|$\)/\1subvolid=5\2/g')"

    debug "Mouting '%s' to '%s' (options: %s -o %s)" "$ROOT" "$1" "$_fstype_opt" "$_rootflags"
    # shellcheck disable=SC2086
    if ! mount $_fstype_opt -o $_rootflags "$ROOT" "$1"; then
        debug "Failed to mount %s as BTRFS top level subvolume to '%s' "`
              `"(options: %s -o %s)." "$ROOT" "$1" "$_fstype_opt" "$_rootflags"
        panic "Failed to mount $ROOT as BTRFS top level subvolume to '$1' "`
              `"(options: $_fstype_opt -o $_rootflags)."
    fi
}

# enable colors only when terminal supports it
enable_colors()
{
    _color_yellow=
    _color_cyan=
    _color_reset=
    _term_colors="$(get_term_colors || echo 0)"
    if [ "$_term_colors" -ge 8 ] && [ "$GUI_START_ASK_NO_COLORS" != 'true' ]; then
        debug "Enabling colors (terminal has '%d' colors)" "$_term_colors"
        _color_yellow='\033[1;33m'
        _color_cyan='\033[1;36m'
        _color_reset='\033[0m'
    fi
}

# colors returns the number of supported colors for the TERM.
# stolen from: shunit2
get_term_colors() {
  if _tput="$(tput colors 2>/dev/null)"; then
    echo "${_tput}"
  else
    echo 16
  fi
  unset _tput
}


# handle the plymouth callback
handle_plymouth_callback()
{
    debug "Got plymouth callback"

    # flag the callback
    PLYMOUTH_CALLBACK=true

    # and continue the script as before
}


# run the restoration GUI
run_restore_GUI()
{
    # disable plymouth
    _plymouth_was_disabled=false
    if [ "$GUI_START_DISABLE_PLYMOUTH" = 'true' ]; then
        debug "Checking if plymouth is running ..."
        if plymouth --ping >/dev/null; then
            debug "Plymouth is running."
            debug "Pausing plymouth"
            plymouth pause-progress 2>>"$LOG_FILE_TMP" || true
            debug "Hidding splash screen"
            plymouth hide-splash 2>>"$LOG_FILE_TMP" || true
            _plymouth_was_disabled=true
        fi
    fi

    debug "Running the restoration GUI"
    # shellcheck disable=SC2097,SC2098
    btrfs-sp-restore-gui --from-toplevel-subvol "$TOPLEVEL_SUBVOL_MNT" \
        2>>"$LOG_FILE_TMP" || \
        {
            if [ "$?" -eq 3 ]; then
                REBOOT=true
                debug "User asked to reboot"
            fi
        }

    if [ "$_plymouth_was_disabled" = 'true' ] && plymouth --ping >/dev/null; then
        debug "Re-Showing splash screen"
        plymouth show-splash 2>>"$LOG_FILE_TMP" || true
        debug "Unpause plymouth"
        plymouth unpause-progress 2>>"$LOG_FILE_TMP" || true
    fi

    if command -v clear >/dev/null 2>&1; then
        debug "Clearing the console"
        clear
    fi
}

# write the log to persistent storage
log_write_to_persistent_storage()
{
    # write the log file to root fs (if asked)
    if [ "$LOG_FILE_DEST_REL" != '' ] && {
        [ "$NO_LOG_WRITE_WHEN_KERNEL_CMDLINE_MATCHES" = '' ] || 
        ! grep -q "$NO_LOG_WRITE_WHEN_KERNEL_CMDLINE_MATCHES" /proc/cmdline; }
    then
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
unmount_btrfs_toplevel_subvol()
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
    unmount_btrfs_toplevel_subvol

    # reboot ?
    if [ "$REBOOT" = 'true' ]; then
        if command -v plymouth >/dev/null 2>&1 && plymouth --ping >/dev/null; then
            debug "Sending a message to plymouth (to warn about reboot)"
            plymouth display-message --text="$(__ "Rebooting now")" || true
            sleep 2
        fi
        reboot -f
    fi
}


# just display pre-requisites
if [ "$1" = 'prereqs' ]; then
    echo "$PREREQS"
    exit 0
fi

# sourcing the configuration
if [ -r "$BTRFS_SP_CONFIG_PATH" ]; then
    # shellcheck disable=SC1090
    . "$BTRFS_SP_CONFIG_PATH"
fi

# set rootfs mount point
if [ "$TOPLEVEL_SUBVOL_MNT" = '' ]; then
    TOPLEVEL_SUBVOL_MNT='/mnt/btrfs_toplevel_subvol'
fi

# source the initramfs helper script
# shellcheck disable=SC1091
. /scripts/functions
# shellcheck disable=SC1091
. /scripts/local


# use a subshell to capture output to a log file
LOG_FILE_TMP="$(mktemp "/tmp/$(basename "$0" '.sh').log.XXXXXX")"
{
    # if the binary is found
    if command -v btrfs-sp >/dev/null; then

        # setup language
        setup_language
        debug "Language: LANGUAGE='%s', LC_ALL='%s', LANG='%s', TEXTDOMAINDIR='%s'" \
            "$LANGUAGE" "$LC_ALL" "$LANG" "$TEXTDOMAINDIR"

        # dump the kernel command line
        debug "Kernel command line: '%s'" "$(cat /proc/cmdline)"

        # mount the BTRFS top level subvolume
        mount_btrfs_toplevel_subvol "$TOPLEVEL_SUBVOL_MNT"

        # if restoration is specified through kernel command line
        if is_restoration_specified_via_kernel_cmdline; then
            debug "Restoration specified through kernel command line"
            debug "Enabling restoration GUI"
            _restore_gui=true
        fi

        # if the restore GUI is not already selected
        if [ "$_restore_gui" != 'true' ]; then

            # if the kernel parameters allow for asking the user about the restoration GUI
            if [ "$GUI_START_WHEN_KERNEL_CMDLINE_MATCHES" != '' ] && \
                    grep -q "$GUI_START_WHEN_KERNEL_CMDLINE_MATCHES" /proc/cmdline; then
                debug "Kernel command line match for the restoration GUI"

                # if there is no plymouth
                debug "Checking if plymouth is running ..."
                if ! command -v plymouth >/dev/null 2>&1 || ! plymouth --ping >/dev/null; then
                    debug "Plymouth is NOT running."

                    # if all the required variables are specified
                    if [ "$GUI_START_USER_INPUT_TIMEOUT_SEC" != '' ] && \
                       [ "$GUI_START_KEY_NAME" != '' ] && \
                       [ "$GUI_START_KEY_LENGTH" != '' ]
                    then

                        # enable colors (may be)
                        enable_colors

                        # read 5 chars with a timeout into the '_key_press' variable
                        debug "Reading user input (5 chars), with a '%s' timeout ..." \
                            "$GUI_START_USER_INPUT_TIMEOUT_SEC"
                        _key_press=
                        printf "\n\n%b" \
                             "${_color_yellow}"`
                            `"$(__ "Press '%s' key" "$GUI_START_KEY_NAME")"`
                            `"${_color_reset}, $(__ "to enter") "`
                            `"${_color_cyan}"`
                            `"$(__ "the BTRFS SavePoint restoration GUI")"`
                            `"${_color_reset} "`
                            `"($(__ "%d seconds left" "$GUI_START_USER_INPUT_TIMEOUT_SEC")) ... "
                        # TODO find a POSIX way to read withtout '-n' option
                        # shellcheck disable=SC2039,SC2162,SC3045
                        read -n "$GUI_START_KEY_LENGTH" -t "$GUI_START_USER_INPUT_TIMEOUT_SEC" -s \
                            _key_press || true
                        printf "\n\n"

                        # if F6 or 'Home' key were hitten, enable the restore GUI
                        _restore_gui=false
                        if [ "$_key_press" = "$(printf '%b' "$GUI_START_KEY_CODE")" ]; then
                            debug "User has pressed key '%s'" "$GUI_START_KEY_NAME"
                            debug "Enabling restoration GUI"
                            _restore_gui=true
                        fi
                    fi

                # plymouth is running
                elif command -v plymouth >/dev/null 2>&1; then

                    # if all the required variables are specified
                    if [ "$GUI_START_USER_INPUT_TIMEOUT_SEC" != '' ] && \
                       [ "$GUI_START_KEY_PLYMOUTH" != '' ]
                    then
                        # shellcheck disable=SC2021
                        _ply_key_up="$(echo "$GUI_START_KEY_PLYMOUTH" | tr '[a-z]' '[A-Z]')"
                        # shellcheck disable=SC2021
                        _ply_key_low="$(echo "$GUI_START_KEY_PLYMOUTH" | tr '[A-Z]' '[a-z]')"

                        # ask plymouth the capture the key and when pressed execute the GUI command
                        debug "Sending message to plymouth about having '%d' seconds to hit '%s'" \
                            "$GUI_START_USER_INPUT_TIMEOUT_SEC" "$GUI_START_KEY_PLYMOUTH"
                        plymouth display-message \
                            --text="$(__ "Hit '%s' to enter BTRFS SavePoint restoration GUI" \
                                        "$_ply_key_up") "`
                                  `"($(__ "%d seconds left" "$GUI_START_USER_INPUT_TIMEOUT_SEC"))"
                        debug "Setting up a trap to catch plymouth callback"
                        trap 'handle_plymouth_callback' USR1
                        debug "Ask plymouth to handle '%s' key press" \
                            "${_ply_key_low}${_ply_key_up}"
                        plymouth watch-keystroke \
                            --keys="${_ply_key_low}${_ply_key_up}" \
                            --command="kill -USR1 $$" &
                        debug "Plymouth is now watching for keystroke '%s'" \
                            "${_ply_key_low}${_ply_key_up}"
                        for _s in $(seq 1 "$GUI_START_USER_INPUT_TIMEOUT_SEC"); do
                            [ "$PLYMOUTH_CALLBACK" != 'true' ] || break

                            debug "Sleeping 1 sec"
                            sleep 1
                            _ply_countdown="$((GUI_START_USER_INPUT_TIMEOUT_SEC - _s))"
                            debug "Sending message to plymouth with countdown (%d sec left)" \
                                "$_ply_countdown"
                            plymouth display-message \
                                --text="$(__ "Hit '%s' to enter BTRFS SavePoint restoration GUI" \
                                            "$_ply_key_up") "`
                                    `"($(__ "%d seconds left" "$_ply_countdown"))"
                        done
                        debug "Tell plymouth to stop handling '%s' key press" \
                            "${_ply_key_low}${_ply_key_up}"
                        plymouth ignore-keystroke --keys="${_ply_key_low}${_ply_key_up}" &
                        debug "Undo the trap to catch plymouth callback"
                        trap '' USR1
                    fi
                fi

            # no kernel command line parameter match for restoration GUI
            else
                debug "No kernel command line parameter match for restoration GUI"
            fi
        fi

        # if plymouth callback was triggered, or restoration was already selected
        if [ "$PLYMOUTH_CALLBACK" = 'true' ] || [ "$_restore_gui" = 'true' ]; then

            # run the restoration GUI
            # shellcheck disable=SC2119
            run_restore_GUI

        # no restoration specified, and not prevented to create a savepoint
        elif [ "$NO_SAVEPOINT_WHEN_KERNEL_CMDLINE_MATCHES" = '' ] || \
            ! grep -q "$NO_SAVEPOINT_WHEN_KERNEL_CMDLINE_MATCHES" /proc/cmdline
        then
            debug "No restoration specified"

            # create a savepoint (backup)
            debug "Creating a new savepoint (snapshoting the system state) ..."
            if _out="$(btrfs-sp create \
                --moment "$(if have_system_resumed; then echo 'resume'; else echo 'boot'; fi)" \
                --from-toplevel-subvol "$TOPLEVEL_SUBVOL_MNT" \
                --initramfs)"
            then
                debug "Savepoint created for: %s" "$(echo "$_out" | tr '\n' ' ')"
                if command -v plymouth >/dev/null 2>&1 && plymouth --ping >/dev/null; then
                    _ply_msg="$(__ "               BTRFS SavePoint created")
                    $(echo "$_out" | tr '\n' ' ')"
                    if [ "$GUI_START_KEY_PLYMOUTH" != '' ]; then
                        # shellcheck disable=SC2021
                        _ply_msg="$_ply_msg


$(__ "   To restore the system to a previous state"),
$(__ "              reboot and hit '%s' at startup" \
    "$(echo "$GUI_START_KEY_PLYMOUTH" | tr '[a-z]' '[A-Z]')")"
                    fi

                    debug "Sending a message to plymouth"
                    plymouth display-message --text="$_ply_msg" || true
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
        fi
    else
        debug "binary 'btrfs-sp' not found"
    fi
} 2>>"$LOG_FILE_TMP" || true

# clean stop this program
do_clean_stop
