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

# halt on first error
set -e

# technical vars
THIS_SCRIPT_NAME="$(basename "$(realpath "$0")")"
THIS_SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# program name
PROGRAM_NAME=btrfs-sp-restore-gui

# default 'btrfs-sp' binary
if ! BTRFSSP="$(command -v btrfs-sp 2>/dev/null)"; then
    if [ -x "$THIS_SCRIPT_DIR/btrfs_sp.sh" ]; then
        BTRFSSP="$THIS_SCRIPT_DIR/btrfs_sp.sh"
    fi
fi

# no btrfs-sp options by default
BTRFSSP_OPTS=

# default btrfs-sp configuration's name regex for the bootfs subvolume (containing /boot)
DEFAULT_ROOTFS_CONF_NAME_REGEX='^@\?[br]oot\(fs\)\?$'

# kernel filename prefix/suffix
DEFAULT_KERNEL_PREFIX='vmlinuz-'
DEFAULT_KERNEL_SUFFIX=

# default console size
DEFAULT_CONSOLE_ROWS=40
DEFAULT_CONSOLE_COLS=100

# default theme colors
COLORS_ROOT='root=lightgray,gray'
COLORS_ROOTTEXT='roottext=green,gray'
COLORS_WINDOW='window=black,lightgray'
COLORS_SHADOW='shadow=gray,blue'
COLORS_BORDER='border=brown,lightgray'
COLORS_TITLE='title=blue,lightgray'
COLORS_BUTTON='button=gray,lightgray'
COLORS_ACTBUTTON='actbutton=gray,yellow'
#COLORS_COMPACTBUTTON='compactbutton=gray,lightgray'
COLORS_CHECKBOX='checkbox=cyan,lightgray'
COLORS_ACTCHECKBOX='actcheckbox=gray,yellow'
COLORS_TEXTBOX='textbox=gray,lightgray'
#COLORS_ACTTEXTBOX='acttextbox=lightgreen,lightgray'
COLORS_TEXTBOX_ERROR='textbox=red,lightgray'
#COLORS_LISTBOX='listbox=lightgray,red'
#COLORS_ACTLISTBOX='actlistbox=green,blue'
#COLORS_SELLISTBOX='sellistbox=red,lightgreen'
#COLORS_ACTSELLISTBOX='actsellistbox=brightgreen,lightgray'
#COLORS_ENTRY='entry=yellow,brown'
#COLORS_DISENTRY='disentry=brightblue,lightgray'
#COLORS_LABEL='label=brightblue'
#COLORS_EMPTYSCALE='emptyscale=lightgray'
#COLORS_FULLSCALE='fullscale=brown'
#COLORS_HELPLINE='helpline=red,cyan'
COLORS_DEFAULT="
$COLORS_ROOT
$COLORS_ROOTTEXT
$COLORS_WINDOW
$COLORS_SHADOW
$COLORS_BORDER
$COLORS_TITLE
$COLORS_BUTTON
$COLORS_ACTBUTTON
$COLORS_CHECKBOX
$COLORS_ACTCHECKBOX
$COLORS_TEXTBOX
"
COLORS_RESTORE_YESNO="$COLORS_DEFAULT"
COLORS_CONFIGS_PICK="$COLORS_DEFAULT"
COLORS_NO_CONFIG_MSG="$COLORS_DEFAULT"
COLORS_SAVEPOINT_PICK="$COLORS_DEFAULT"
COLORS_COLLECTING_SAVEPOINT_MSG="$COLORS_DEFAULT"
COLORS_NO_SAVEPOINT_MSG="$COLORS_DEFAULT"
COLORS_WANTS_DIFF_YESNO="$COLORS_DEFAULT"
COLORS_NO_DIFF_MSG="$COLORS_DEFAULT"
COLORS_DIFF_MSG="$COLORS_DEFAULT"
COLORS_DIFF_FAIL_YESNO="$COLORS_DEFAULT"
COLORS_CONFIRM_YESNO="$COLORS_DEFAULT"
COLORS_RESULT_OK_MSG="$COLORS_DEFAULT"
COLORS_REBOOT_YESNO="$COLORS_DEFAULT"
COLORS_RESULT_KO_MSG="$(echo "$COLORS_DEFAULT" | sed 's/^textbox=.*//g')
$COLORS_TEXTBOX_ERROR"


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

# print out messages, only if DEBUG_GUI is 'true'
# each line is prefixed by '[GUI DEBUG] '
# arguments are the same than 'printf' function
debug()
{
    if [ "$DEBUG_GUI" = 'true' ]; then
        # shellcheck disable=SC2059
        printf "$@" | sed 's/^/[GUI DEBUG] /g' >&2
    fi
}

# print out information about a dialog that just closed
# it assume that its output has been captured to a tmp file
# @param  $1  string  what the user has clicked (Yes|No|Ok|Cancel)
# @param  $2  strnig  path of the file containing the output of the dialog
debug_gui()
{
    debug "Clicked: $1\n"
    if [ "$2" != '' ]; then
        debug "Output:\n"
        debug "%s\n" '---'
        debug "%s\n" "$(cat "$2")"
        debug "\n"
        debug "%s\n" '---'
    fi
}

# count the number of items in a list (separated by line break)
count_items()
{
    if [ "$1" = '' ]; then
        echo 0
    else
        echo "$1" | wc -l
    fi
}

# get the minimum out of the two numbers
min()
{
    echo "$1 $2" | awk '{print ($1 > $2) ? $2 : $1}'
}

# get the maximum out of the two numbers
max()
{
    echo "$1 $2" | awk '{print ($1 < $2) ? $2 : $1}'
}

# usage
usage()
{
    cat <<ENDCAT

$THIS_SCRIPT_NAME - $( \
    __ '%s GUI to restore a folder (BTRFS subvolume) at previous state.' 'btrfs-sp')

$(__ 'USAGE')

    $THIS_SCRIPT_NAME $(__ 'OPTIONS')

    $THIS_SCRIPT_NAME [ -h | --help ]


$(__ 'OPTIONS')

    -b | --btrfs-sp $(__ 'PATH')
        $(__ "Path to '%s' binary." 'btrfs-sp')
        $(__ 'Default to'): '$BTRFSSP'.

    -g | --bsp-global-conf $(__ 'PATH')
        $(__ "Path to '%s' global configuration." 'btrfs-sp')

    -d | --dialog $(__ 'PATH')
        $(__ "Path to a '%s' binary." 'dialog')
        $(__ "Default to '%s' binary, then '%s'." 'whiptail' 'dialog')

    -k | --boot-config-regexp
        $(__ "Regular expression to match the name of the '%s' %s configuration." 'btrfs-sp' '/boot')
        $(__ "When restoring that configuration's subvolume"), $(\
            __ "it checks that the current kernel is still present in the restored one.")
        $(__ "If the kernel is not found in the subvolume, it offers to reboot at the exit.")
        $(__ 'Default to'): '$DEFAULT_ROOTFS_CONF_NAME_REGEX'.

    -p | --kernel-prefix
        $(__ "Prefix of the kernel filename.")
        $(__ 'Default to'): '$DEFAULT_KERNEL_PREFIX'.

    -s | --kernel-suffix
        $(__ "Suffix of the kernel filename.")
        $(__ 'Default to'): '$DEFAULT_KERNEL_SUFFIX'.

    -r | --from-toplevel-subvol PATH
        $(__ 'Prefix paths with the specified PATH'), $(__ "see '%s' documentation." 'btrfs-sp')

    -t | --theme-file $(__ 'FILE')
        $(__ 'Load the specified theme file.')
        $(__ 'In order to create such a theme file'), $(__ \
        "You should define the following variables according to the %s documentation for '%s' :" \
                'libnewt' 'NEWT_COLORS')
            COLORS_RESTORE_YESNO
            COLORS_CONFIGS_PICK
            COLORS_NO_CONFIG_MSG
            COLORS_SAVEPOINT_PICK
            COLORS_NO_SAVEPOINT_MSG
            COLORS_CONFIRM_YESNO
            COLORS_RESULT_OK_MSG
            COLORS_REBOOT_YESNO
            COLORS_RESULT_KO_MSG
        $(__ 'Example'):
            COLORS_RESULT_KO_MSG='
                window=,red
                border=white,red
                textbox=white,red
                button=black,white'
        $(__ 'See also'):
            https://askubuntu.com/a/781062

    -z | --console-size $(__ 'ROWS')x$(__ "COLUMNS")
        $(__ "Force to treat the console as the specified size.")

    -h | --help
        $(__ 'Display help message.')


$(__ 'NOTES')

    $(__ "When the user ask for reboot, it will not really reboot, but just exit with return code '3'.")
    $(__ "Then it is up to the calling script to handle the rebooting on behalf of the user.")

ENDCAT
}


# main program

# options (requires GNU getopt)
if ! TEMP="$(getopt -o 'b:g:d:k:p:s:hr:' \
             --long 'btrfs-sp:,bsp-global-conf:,dialog:,boot-config-regexp:,'`
                    `'kernel-prefix:,kernel-suffix:,help,from-toplevel-subvol:,'`
                    `'console-size:,theme-file:' \
             -n "$THIS_SCRIPT_NAME" -- "$@")"
then
    __ 'Fatal error: invalid option' >&2
    exit 1
fi
eval set -- "$TEMP"

opt_bsp_bin="$BTRFSSP"
opt_bsp_global_config=
opt_dialog_bin=
opt_boot_config_regexp="$DEFAULT_ROOTFS_CONF_NAME_REGEX"
opt_kernel_prefix="$DEFAULT_KERNEL_PREFIX"
opt_kernel_suffix="$DEFAULT_KERNEL_SUFFIX"
opt_help=false
opt_from_toplevel_subvol=
opt_console_size=
opt_theme_file=
while true; do
    # shellcheck disable=SC2034
    case "$1" in
        -b | --btrfs-sp             ) opt_bsp_bin="$2"              ; shift 2 ;;
        -g | --bsp-global-config    ) opt_bsp_global_config="$2"    ; shift 2 ;;
        -d | --dialog               ) opt_dialog_bin="$2"           ; shift 2 ;;
        -k | --boot-config-regexp   ) opt_boot_config_regexp="$2"   ; shift 2 ;;
        -p | --kernel-prefix        ) opt_kernel_prefix="$2"        ; shift 2 ;;
        -s | --kernel-suffix        ) opt_kernel_suffix="$2"        ; shift 2 ;;
        -h | --help                 ) opt_help=true                 ; shift   ;;
        -r | --from-toplevel-subvol ) opt_from_toplevel_subvol="$2" ; shift 2 ;;
        -t | --theme-file           ) opt_theme_file="$2"           ; shift 2 ;;
        -z | --console-size         ) opt_console_size="$2"         ; shift 2 ;;
        -- ) shift; break ;;
        *  ) break ;;
    esac
done

# setup language
setup_language

# help/usage
if [ "$opt_help" = 'true' ]; then
    usage
    exit 0
fi

# ensure btrfs-sp binary exists and is executable
BTRFSSP="$opt_bsp_bin"
if [ ! -x "$BTRFSSP" ]; then
    __ "Fatal error: binary '%s' not found" "$BTRFSSP" >&2
    exit 1
fi
debug "Using '%s' as btrfs-sp binary\n" "$BTRFSSP"

# find a binary to display dialog boxes
if [ "$opt_dialog_bin" != '' ]; then
    DIALOG_BIN="$opt_dialog_bin"
elif ! DIALOG_BIN="$(command -v whiptail 2>/dev/null)"; then
    if ! DIALOG_BIN="$(command -v dialog 2>/dev/null)"; then
        __ "Fatal error: no binary found for handling dialog box (no '%s' nor '%s')" \
           'whiptail' 'dialog' >&2
        exit 1
    fi
fi
if [ ! -x "$DIALOG_BIN" ]; then
    __ "Fatal error: binary '%s' not found" "$DIALOG_BIN" >&2
    exit 1
fi
debug "Using '%s' as dialog binary\n" "$DIALOG_BIN"

# eventually use the specified btrfs-sp global configuration
if [ "$opt_bsp_global_config" != '' ]; then
    BTRFSSP_OPTS="--global-config $opt_bsp_global_config"
fi

# optionally use the path from '--from-toplevel-subvol'
if [ "$opt_from_toplevel_subvol" != '' ]; then
    BTRFSSP_OPTS="$BTRFSSP_OPTS --from-toplevel-subvol $opt_from_toplevel_subvol"
fi

# set up the title of the GUI
gui_title="btrfs-sp - $(__ "system's restoration, thanks to BTRFS snapshots")"
gui_backtitle="$(__ "Made with time, love and passion by Michael Bideau")"

# reboot at the end
reboot=false

# detect the size of the console
console_size_detected=
# forced by option
if [ "$opt_console_size" != '' ]; then
    console_rows="$(echo "$opt_console_size" | awk -F 'x' '{print $1}')"
    console_cols="$(echo "$opt_console_size" | awk -F 'x' '{print $2}')"
    console_size_detected=' (forced)'
# auto-detect
elif command -v stty >/dev/null 2>&1; then
    console_rows="$(stty size | awk '{print $1}')"
    console_cols="$(stty size | awk '{print $2}')"
    console_size_detected=' (detected automaticaly)'
# or use default parameters
else
    console_rows="$DEFAULT_CONSOLE_ROWS"
    console_cols="$DEFAULT_CONSOLE_COLS"
fi
debug "Console size: %d x %d%s\n" "$console_rows" "$console_cols" "$console_size_detected"
console_rows_max="$((console_rows - 4))"
console_cols_max="$((console_cols - 2))"
console_rows_big="$((console_rows_max - 2))"
console_cols_big="$((console_cols_max - 5))"

# theme file
if [ "$opt_theme_file" != '' ] && [ -r "$opt_theme_file" ]; then
    debug "Sourcing theme file '%s'\n" "$opt_theme_file"
    # shellcheck disable=SC1090
    . "$opt_theme_file"
fi

# use a temporary file
tmp_file="$(mktemp)"
debug "Temp file: '%s'\n" "$tmp_file"

# setup a trap to remove the temporary file when exiting
# shellcheck disable=SC2064
trap "debug "'"'"Removing temp file '$tmp_file'\n"'"'" && rm -f '$tmp_file'" \
    INT QUIT ABRT TERM EXIT

# running the GUI indefinitely, until the user ask to exit
debug "Running the GUI indefinitely, until the user ask to exit ...\n"
while true; do

    # ask the user if he wants to do a restoration of its system to a previous state
    debug "Ask the user if he wants to do a restoration of its system to a previous state ...\n"
    _ret=0
    NEWT_COLORS="$COLORS_RESTORE_YESNO" \
    "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" --fullbuttons \
        --clear \
        --yes-button "$(__ "Yes, please")" \
        --no-button "$(__ "No, thank you")" \
        --yesno "\n$(__ "       Do you want to restore your system from a previous state ?")\n\n" \
                "$(min 12 "$console_rows_max")" "$(min 75 "$console_cols_max")" \
        2>"$tmp_file" || _ret="$?"
    if [ "$_ret" -eq 1 ]; then
        debug_gui 'No' "$tmp_file"
        break
    elif [ "$_ret" -ne 0 ]; then
        debug_gui 'ESC (or crashed)' "$tmp_file"
        break
    fi

    debug "Clicked: Yes\n"

    # ask the user to select which configuration should be considered
    debug "Loop over restoration process indefinitely, until the user ask to exit ...\n"
    while true; do

        # get the btrfs-sp configurations and turn them into [tag text status]
        # expected by the dialog '--radiolist'
        debug "Getting the btrfs-sp configurations ...\n"
        debug "Running: '%s'\n" "'$BTRFSSP' $BTRFSSP_OPTS ls-conf --format-gui"
        _sed_cmd=
        [ "$opt_from_toplevel_subvol" = '' ] || _sed_cmd="s|$opt_from_toplevel_subvol||g"
        # shellcheck disable=SC2086
        items="$("$BTRFSSP" $BTRFSSP_OPTS ls-conf --format-gui | sed 's/$/ off/g' \
                | sed "$_sed_cmd" || true)"
        debug "Items:\n"
        debug "%s\n" '---'
        debug "%s\n" "$items"
        debug "%s\n" '---'
        items_count="$(count_items "$items")"
        debug "Items count: %s\n" "$items_count"

        # no items found
        if [ "$items_count" -eq 0 ]; then

            # inform the user that no configuration where found
            debug "Inform the user that no configuration where found ...\n"
            if NEWT_COLORS="$COLORS_NO_CONFIG_MSG" \
               "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                    --fullbuttons \
                    --ok-button "$(__ "Ok, then")" \
                    --msgbox "\n$(__ "                          No configuration found")" \
                             "$(min 12 "$console_rows_max")" "$(min 75 "$console_cols_max")" \
                2>"$tmp_file"
            then
                debug_gui 'Ok' "$tmp_file"
            else
                debug_gui 'ESC (or crashed)' "$tmp_file"
            fi
            break
        fi

        # present the list of configurations and ask the user to pick one
        conf_selected=
        while [ "$conf_selected" = '' ]; do

            debug "Ask the user to select which configuration should be considered ...\n"
            _ret=0
            # shellcheck disable=SC2086
            NEWT_COLORS="$COLORS_CONFIGS_PICK" \
            "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" --fullbuttons \
                --ok-button "$(__ "Ok")" \
                --cancel-button "$(__ "Cancel")" \
                --notags \
                --radiolist \
                    "\n$(__ "Select which element you want to restore :")\n"`
                    `"\n$(__ "Info: use 'arrow keys' to move up/down the list"), "`
                    `"$(__ "then press <space> to select an item");\n"`
                    `"$(__ "      use <tab> to move around selection (i.e.: change button).")\n" \
                    "$(min "$(max 40 "$console_rows_big")" "$console_rows_max")" \
                    "$(min "$(max 120 "$console_cols_big")" "$console_cols_max")" \
                    "$items_count" $items \
                2>"$tmp_file" || _ret="$?"
            if [ "$_ret" -eq 1 ]; then
                debug_gui 'Cancel' "$tmp_file"
                break 2
            elif [ "$_ret" -ne 0 ]; then
                debug_gui 'ESC (or crashed)' "$tmp_file"
                break 2
            fi

            debug_gui 'Ok' "$tmp_file"

            # save the configuration selected
            conf_selected="$(head -n 1 "$tmp_file")"
            debug "Conf selected: %s\n" "$conf_selected"
        done

        # inform the user that we are collecting savepoints and analyzing their differences
        debug "Inform the user that we are collecting savepoints and analyzing their differences ...\n"
        # NOTE: TERM=ansi is required here, else whiptail show nothing.
        #       See bug: https://stackoverflow.com/a/35098746
        if TERM=ansi NEWT_COLORS="$COLORS_COLLECTING_SAVEPOINT_MSG" \
            "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                --infobox "\n$(__ "Collecting savepoints for that configuration, and analyzing their differences...")\n"`
                          `"$(__ "This might take a few seconds and sometimes a few minutes.")" \
                          "$(min 8 "$console_rows_max")" "$(min 100 "$console_cols_max")" \
            2>"$tmp_file"
        then
            debug_gui 'Ok' "$tmp_file"
        else
            debug_gui 'ESC (or crashed)' "$tmp_file"
        fi

        # get the btrfs-sp savepoints for that configuration, and turn them into
        # [tag text status] expected by the dialog '--radiolist'
        debug "Getting the btrfs-sp savepoints for that configuration ...\n"
        debug "Running: '%s'\n" "'$BTRFSSP' $BTRFSSP_OPTS --config '$conf_selected' ls --format-gui"
        # shellcheck disable=SC2086
        items="$("$BTRFSSP" $BTRFSSP_OPTS --config "$conf_selected" ls --format-gui \
                |sed 's/$/ off/g' || true)"
        debug "Items:\n"
        debug "%s\n" '---'
        debug "%s\n" "$items"
        debug "%s\n" '---'
        items_count="$(count_items "$items")"
        debug "Items count: %s\n" "$items_count"

        # no items found
        if [ "$items_count" -eq 0 ]; then

            # inform the user that no savepoints where found
            debug "Inform the user that no savepoints where found ...\n"
            if NEWT_COLORS="$COLORS_NO_SAVEPOINT_MSG" \
               "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                    --fullbuttons \
                    --ok-button "$(__ "Ok, then")" \
                    --msgbox "\n$(__ "                            No savepoints found")" \
                             "$(min 12 "$console_rows_max")" "$(min 75 "$console_cols_max")" \
                2>"$tmp_file"
            then
                debug_gui 'Ok' "$tmp_file"
            else
                debug_gui 'ESC (or crashed)' "$tmp_file"
            fi
            break
        fi

        # present the list of savepoints and ask the user to pick one
        sp_selected=
        while [ "$sp_selected" = '' ]; do

            debug "Present the list of savepoints and ask the user to pick one ...\n"
            _ret=0
            # shellcheck disable=SC2086
            NEWT_COLORS="$COLORS_SAVEPOINT_PICK" \
            "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" --fullbuttons \
                --ok-button "$(__ "Ok")" \
                --cancel-button "$(__ "Cancel")" \
                --notags \
                --radiolist "\n$(__ "Legend: before each savepoint there are one of the following :")\n"`
                            `"$(__ "        3 groups of 3 signs ('.', '-', '+', '*'), or a single letter 'v'"), "`
                            `"$(__ "and together they form a representation of the differences with the previous/below savepoint").\n"`
                            `"$(__ "        the single letter 'v' means the savepoint is just a link to the previous/below savepoint").\n"`
                            `"$(__ "        the first/left group of 3 signs, represent the deletions, the more '-' sign there is the more files were deleted").\n"`
                            `"$(__ "        the second/middle group of 3 signs, represent the additions, the more '+' sign there is the more files were added").\n"`
                            `"$(__ "        the third/right group of 3 signs, represent the modifications, the more '*' sign there is the more files were modified").\n"`
                            `"$(__ "        in any of the 3 groups of 3 signs, a dot '.' means nothing, it is just a visual mark to show that an analysis have been done")\n"`
                            `"\n$(__ "Select the savepoint to restore from :")" \
                            "$(min "$(max 40 "$console_rows_big")" "$console_rows_max")" \
                            "$(min "$(max 120 "$console_cols_big")" "$console_cols_max")" \
                            "$items_count" $items \
                2>"$tmp_file" || _ret="$?"
            if [ "$_ret" -eq 0 ]; then
                debug_gui 'Ok' "$tmp_file"

                # save the savepoint selected
                sp_selected="$(head -n 1 "$tmp_file")"
                debug "Savepoint selected: %s\n" "$conf_selected"

            elif [ "$_ret" -eq 1 ]; then
                debug_gui 'Cancel' "$tmp_file"
                break
            else
                debug_gui 'ESC (or crashed)' "$tmp_file"
                break
            fi
            if [ "$sp_selected" = '' ]; then
                continue
            fi

            # get the subvolume for that configuration
            debug "Getting the subvolume for that configuration ...\n"
            debug "Running: '%s'\n" "'$BTRFSSP' $BTRFSSP_OPTS ls-conf"
            # shellcheck disable=SC2086
            conf_subvol="$("$BTRFSSP" $BTRFSSP_OPTS ls-conf \
                            | grep "^$conf_selected:" \
                            | sed 's/^\([a-zA-Z0-9@_.-]\+\): \+\([^=]\+\) \+==> .*$/\2/g' \
                            || true)"
            debug "Conf subvol: %s\n" "$conf_subvol"

            # offer the user to see the differences with the current subvolume
            debug "Offer the user to see the differences with the current subvolume ...\n"
            _ret=0
            NEWT_COLORS="$COLORS_WANTS_DIFF_YESNO" \
            "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                --fullbuttons \
                --yes-button "$(__ "Yes")" \
                --no-button "$(__ "Cancel")" \
                --yesno "\n$(__ "See the differences with the current state ?")"\
                            "$(min 12 "$console_rows_max")" "$(min 75 "$console_cols_max")" \
                    2>"$tmp_file" || _ret="$?"
            if [ "$_ret" -eq 0 ]; then
                debug_gui 'Yes' "$tmp_file"

                _temp="$(mktemp)"

                debug "Running: '%s'\n" "'$BTRFSSP' $BTRFSSP_OPTS subvolume-diff '$conf_selected' '$sp_selected'"
                # shellcheck disable=SC2086
                "$BTRFSSP" $BTRFSSP_OPTS subvolume-diff "$conf_selected" \
                    "$sp_selected" > "$_temp" || _ret="$?"

                # no differences
                if [ "$_ret" -eq 0 ]; then

                    # inform the user that no difference where found
                    debug "Inform the user that no difference where found ...\n"
                    if NEWT_COLORS="$COLORS_NO_DIFF_MSG" \
                    "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                            --fullbuttons \
                            --ok-button "$(__ "Ok, then")" \
                            --msgbox "\n$(__ "                            No difference found")" \
                                    "$(min 12 "$console_rows_max")" "$(min 75 "$console_cols_max")"\
                        2>"$tmp_file"
                    then
                        debug_gui 'Ok' "$tmp_file"
                    else
                        debug_gui 'ESC (or crashed)' "$tmp_file"
                    fi

                # differences
                elif [ "$_ret" -eq 1 ]; then

                    # show the differences
                    debug "Show the differences ...\n"
                    if NEWT_COLORS="$COLORS_DIFF_MSG" \
                    "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                            --fullbuttons \
                            --ok-button "$(__ "Ok, then")" \
                            --textbox "$_temp" "$(min 50 "$console_rows_max")" \
                                               "$(min 120 "$console_cols_max")"\
                        2>"$tmp_file"
                    then
                        debug_gui 'Ok' "$tmp_file"
                    else
                        debug_gui 'ESC (or crashed)' "$tmp_file"
                    fi

                # errors
                else
                    rm -f "$_temp"

                    # inform the user that the differences could not be produced
                    debug "Inform the user that there were an error and the differences "`
                          `"cannot be viewed ...\n"
                    _ret=0
                    NEWT_COLORS="$COLORS_DIFF_FAIL_YESNO" \
                    "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                        --fullbuttons \
                        --yes-button "$(__ "Yes")" \
                        --no-button "$(__ "Cancel")" \
                        --yesno "\n$(__ "There were an error when producing the differences.")\n\n"`
                                `"$(__ "Continue anyway ?")" \
                                 "$(min 12 "$console_rows_max")" "$(min 75 "$console_cols_max")" \
                            2>"$tmp_file" || _ret="$?"
                    if [ "$_ret" -eq 0 ]; then
                        debug_gui 'Yes' "$tmp_file"
                    elif [ "$_ret" -eq 1 ]; then
                        debug_gui 'No' "$tmp_file"
                        break
                    else
                        debug_gui 'ESC (or crashed)' "$tmp_file"
                        break
                    fi
                fi

                [ ! -e "$_temp" ] || rm -f "$_temp"

            elif [ "$_ret" -eq 1 ]; then
                debug_gui 'No' "$tmp_file"
            else
                debug_gui 'ESC (or crashed)' "$tmp_file"
            fi

            # ask the user to confirm that he wants to do the restoration
            debug "Ask the user to confirm that he wants to do the restoration ...\n"
            _ret=0
            NEWT_COLORS="$COLORS_CONFIRM_YESNO" \
            "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                --fullbuttons \
                --yes-button "$(__ "Yes")" \
                --no-button "$(__ "Cancel")" \
                --yesno "\n$(__ "Restore the BTRFS subvolume"):\n\n	$conf_subvol\n\n"`
                        `"$(__ "from the savepoint"):\n\n	$sp_selected\n\n\n"`
                        `"$(__ "Please confirm") ..." \
                            "$(min 18 "$console_rows_max")" "$(min 100 "$console_cols_max")" \
                    2>"$tmp_file" || _ret="$?"
            if [ "$_ret" -eq 0 ]; then
                debug_gui 'Yes' "$tmp_file"

                # do the restoration
                debug "Restoring '%s' from savepoint '%s' ...\n" \
                    "$conf_subvol" "$sp_selected"
                debug "Running: '%s'\n" "'$BTRFSSP' $BTRFSSP_OPTS restore '$conf_selected' '$sp_selected'"
                # shellcheck disable=SC2086
                if "$BTRFSSP" $BTRFSSP_OPTS restore "$conf_selected" "$sp_selected" \
                    >"$tmp_file" 2>&1
                then

                    # inform the user that the restoration has succeed
                    debug "Inform the user that the restoration has succeed ...\n"
                    if NEWT_COLORS="$COLORS_RESULT_OK_MSG" \
                        "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                            --fullbuttons \
                            --ok-button "$(__ "Ok, great")" \
                            --msgbox "\n$(__ "Restoration complete")" \
                                     "$(min 12 "$console_rows_max")" \
                                     "$(min 75 "$console_cols_max")" \
                        2>"$tmp_file"
                    then
                        debug_gui 'Ok' "$tmp_file"

                        # if this is the bootfs configuration
                        if echo "$conf_selected" | grep -q "$opt_boot_config_regexp"; then
                            debug "The current configuration is the 'bootfs' one "`
                                    `"(containing /boot)"

                            # checking if the current kernel is still present
                            # in the new bootfs
                            debug "Checking if the current kernel is still present "`
                                    `"in the new bootfs"
                            current_kernel="${opt_kernel_prefix}$(uname -r)"`
                                            `"${opt_kernel_suffix}"
                            current_kernel_supposed_path="$conf_subvol/boot/$current_kernel"
                            debug "Supposed current kernel path: %s" \
                                "$current_kernel_supposed_path"
                            if [ ! -e "$current_kernel_supposed_path" ]; then
                                debug "The current kernel was not found"

                                # ask the user if he/she wants to reboot at the end
                                debug "Ask the user if he/she wants to reboot at the end\n"
                                _ret=0
                                NEWT_COLORS="$COLORS_REBOOT_YESNO" \
                                "$DIALOG_BIN" --backtitle "$gui_backtitle" \
                                    --title "$gui_title" --fullbuttons \
                                    --yes-button "$(__ "Yes")" \
                                    --no-button "$(__ "Cancel")" \
                                    --yesno "\n$( \
                                    __ "Your currently running system's kernel '%s'") "`
                                    `"$(__ " was not found after the restoration, at :") "`
                                    `"\n\n$current_kernel_supposed_path\n\n"`
                                    `"$(__ "So you will not be able to boot") "`
                                    `"$(__ "before your system has rebooted.")"`
                                    `"\n\n$(__ "Reboot after exiting this program ?")"\
                                    "$(min 18 "$console_rows_max")" "$(min 80 "$console_cols_max")"\
                                        2>"$tmp_file" || _ret="$?"
                                if [ "$_ret" -eq 0 ]; then
                                    debug_gui 'Yes' "$tmp_file"

                                    # flag reboot
                                    reboot=true
                                elif [ "$_ret" -eq 1 ]; then
                                    debug_gui 'No' "$tmp_file"
                                else
                                    debug_gui 'ESC (or crashed)' "$tmp_file"
                                fi

                            # if the current kernel is present in the (possibily new) bootfs
                            else

                                # just continue to boot like normal (do nothing here)
                                debug "Current kernel found (nothing special to do:"`
                                        `"it will boot fine)"
                            fi
                        fi
                    else
                        debug_gui 'ESC (or crashed)' "$tmp_file"
                    fi
                else
                    debug "Restoration has failed\n"

                    # grab the output
                    debug "Grabing the output ...\n"
                    _err_output="$(cat "$tmp_file")"
                    debug "Error: %s" "$_err_output"

                    # copy the error to STDERR
                    debug "Copy the error to STDERR\n"
                    echo "$_err_output" >&2

                    # inform the user that the restoration has failed
                    debug "Inform the user that the restoration has failed ...\n"
                    if NEWT_COLORS="$COLORS_RESULT_KO_MSG" \
                        "$DIALOG_BIN" --backtitle "$gui_backtitle" --title "$gui_title" \
                            --fullbuttons \
                            --ok-button "$(__ "Ok, I understand")" \
                            --msgbox "\n$(__ "Restoration has failed.") "`
                                     `"$(__ "More details on the error below.")\n"`
                                     `"\n$_err_output" \
                                     "$(min "$(max 30 "$console_rows_big")" "$console_rows_max")" \
                                     "$(min "$(max 100 "$console_cols_big")" "$console_cols_max")" \
                        2>"$tmp_file"
                    then
                        debug_gui 'Ok' "$tmp_file"
                    else
                        debug_gui 'ESC (or crashed)' "$tmp_file"
                    fi
                fi
            elif [ "$_ret" -eq 1 ]; then
                sp_selected=
                debug_gui 'Cancel' "$tmp_file"
            else
                sp_selected=
                debug_gui 'ESC (or crashed)' "$tmp_file"
            fi
        done
    done
done

if [ "$reboot" = 'true' ]; then
    debug "Removing temp file '$tmp_file'\n"
    rm -f "$tmp_file"

    debug "User asked to reboot : returning exit code 3"
    exit 3
fi

# vim: set ts=4 sw=4 et mouse=
