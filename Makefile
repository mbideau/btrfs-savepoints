# Makefile for btrfs-sp
#
# Respect GNU make conventions
#  @see: https://www.gnu.org/software/make/manual/make.html#Makefile-Basics
#
# Copyright (C) 2019 Michael Bideau [France]
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
# along with btrfs-sp.  If not, see <https://www.gnu.org/licenses/>.
#

# use POSIX standard shell and fail at first error
.POSIX:

# source
srcdir             ?= .

# program
MAIN_SCRIPT        := $(srcdir)/btrfs_sp.sh
PROGRAM_NAME       ?= $(subst _,-,$(basename $(notdir $(MAIN_SCRIPT))))
GUI_SCRIPT         := $(srcdir)/btrfs_sp_restore_gui.sh

# tools / utilities
INITRAMFS_SCRIPT   := $(srcdir)/btrfs_sp_initramfs_script.sh
INITRAMFS_HOOK     := $(srcdir)/btrfs_sp_initramfs_hook.sh
SYSTEMD_SCRIPT     := $(srcdir)/btrfs_sp_systemd_script.sh
GUI_PROG_NAME      := $(subst _,-,$(basename $(notdir $(GUI_SCRIPT))))
INITRAMFS_PROG_NAME:= $(subst _,-,$(basename $(notdir $(INITRAMFS_SCRIPT))))
INITRAMFS_HOOK_NAME:= $(subst _,-,$(basename $(notdir $(INITRAMFS_HOOK))))
SYSTEMD_PROG_NAME  := $(subst _,-,$(basename $(notdir $(SYSTEMD_SCRIPT))))

# tests scripts
TEST_SCRIPTS       := $(wildcard $(srcdir)/test*.sh)

# package infos
PACKAGE_NAME       ?= $(PROGRAM_NAME)
PACKAGE_VERS       ?= 0.1.0

# author
AUTHOR_NAME        := Michael Bideau
EMAIL_SUPPORT      := mica.devel@gmail.com

# charset and languages
CHARSET            := UTF-8
LOCALES            := fr
LOCALES_PLUS_EN    := en $(LOCALES)

# temp dir
TMPDIR             ?= $(srcdir)/.tmp

# destination
# @see: https://www.gnu.org/software/make/manual/make.html#Directory-Variables
prefix             ?= /usr/local
exec_prefix        ?= $(prefix)
bindir             ?= $(exec_prefix)/bin
sbindir            ?= $(exec_prefix)/sbin
ifeq ($(strip $(prefix)),)
datarootdir        ?= $(prefix)/usr/share
else
datarootdir        ?= $(prefix)/share
endif
datadir            ?= $(datarootdir)
ifeq ($(strip $(prefix)),/usr)
sysconfdir         ?= /etc
else
sysconfdir         ?= $(prefix)/etc
endif
infodir            ?= $(datarootdir)/info
libdir             ?= $(exec_prefix)/lib
localedir          ?= $(datarootdir)/locale
mandir             ?= $(datarootdir)/man
dirs_var_name      := prefix exec_prefix bindir sbindir datarootdir datadir sysconfdir infodir libdir localedir mandir

# install
INSTALL            ?= install
INSTALL_PROGRAM    ?= $(INSTALL) $(INSTALLFLAGS) --mode 750
INSTALL_DATA       ?= $(INSTALL) $(INSTALLFLAGS) --mode 640
INSTALL_DIRECTORY  ?= $(INSTALL) $(INSTALLFLAGS) --directory --mode 750

# locale specific
MAIL_BUGS_TO       := $(EMAIL_SUPPORT)
TEXTDOMAINS        := $(PROGRAM_NAME) $(GUI_PROG_NAME) $(INITRAMFS_PROG_NAME) $(SYSTEMD_PROG_NAME)
LOCALE_DIR         := $(srcdir)/locale
PO_DIRS            := $(foreach locale,$(LOCALES),$(LOCALE_DIR)/$(locale)/LC_MESSAGES)
PO_FILES           := $(foreach po_dir,$(PO_DIRS),$(foreach textdomain,$(TEXTDOMAINS),$(po_dir)/$(textdomain).po))
MO_FILES           := $(subst .po,.mo,$(PO_FILES))
POT_FILES          := $(foreach textdomain,$(TEXTDOMAINS),$(LOCALE_DIR)/$(textdomain).pot)

# man specific
MAN_DIR            := $(TMPDIR)/man
MAN_SECTION        ?= 8
MAN_FILENAMES      := $(PROGRAM_NAME) $(PROGRAM_NAME).conf $(GUI_PROG_NAME)

# generated files/dirs
LOCALE_DIRS        := $(foreach locale,$(LOCALES),$(LOCALE_DIR)/$(locale)/LC_MESSAGES)
MANS               := $(foreach fn,$(MAN_FILENAMES),$(foreach locale,$(LOCALES_PLUS_EN),$(MAN_DIR)/$(fn).$(locale).texi.gz))
DIRS               := $(LOCALE_DIR) $(LOCALE_DIRS) $(TMPDIR) $(MAN_DIR)

# destinations files/dirs
INST_MAIN_SCRIPT   := $(DESTDIR)$(sbindir)/$(PROGRAM_NAME)
INST_GUI_SCRIPT    := $(DESTDIR)$(sbindir)/$(GUI_PROG_NAME)
INST_INITRAMFS_DIR := $(DESTDIR)/etc/initramfs-tools/scripts/local-premount
INST_INITRAMFS     := $(INST_INITRAMFS_DIR)/$(PROGRAM_NAME)
INST_SYSTEMD_DIR   := $(DESTDIR)/lib/systemd/system-shutdown
INST_SYSTEMD       := $(INST_SYSTEMD_DIR)/$(PROGRAM_NAME).shutdown
INST_HOOK_DIR      := $(DESTDIR)/etc/initramfs-tools/hooks
INST_HOOK          := $(INST_HOOK_DIR)/$(PROGRAM_NAME)
INST_LOCALES       := $(foreach textdomain,$(TEXTDOMAINS),$(foreach locale,$(LOCALES),$(DESTDIR)$(localedir)/$(locale)/LC_MESSAGES/$(textdomain).mo))
INST_MANS          := $(foreach fn,$(MAN_FILENAMES),$(foreach locale,$(LOCALES_PLUS_EN),$(DESTDIR)$(mandir)/$(locale)/man$(MAN_SECTION)/$(fn).$(MAN_SECTION).gz))
INST_FILES         := $(INST_MAIN_SCRIPT) $(INST_GUI_SCRIPT) $(INST_INITRAMFS) $(INST_HOOK) \
					  $(INST_SYSTEMD) $(INST_LOCALES) $(INST_MANS)
INST_DIRS           = $(sort $(dir $(INST_MAIN_SCRIPT)) $(dir $(INST_LOCALES)) $(dir $(INST_MANS)))

# distribution
DIST_DIR           := $(TMPDIR)/dist
DIST_DIRNAME       ?= $(PACKAGE_NAME)-$(PACKAGE_VERS)
DIST_DIRPATH       := $(DIST_DIR)/$(DIST_DIRNAME)
DIST_SRC_FILES      = $(MAIN_SCRIPT) $(GUI_SCRIPT) $(INITRAMFS_SCRIPT) $(INITRAMFS_HOOK) \
					  $(SYSTEMD_SCRIPT) $(PO_FILES) $(srcdir)/README.md $(srcdir)/LICENSE.txt \
					  $(srcdir)/Makefile $(TEST_SCRIPTS)
DIST_FILES          = $(subst $(srcdir)/,$(DIST_DIRPATH)/,$(DIST_SRC_FILES))
DIST_DIRS           = $(sort $(dir $(DIST_FILES)))
DIST_TARNAME       ?= $(DIST_DIRNAME).tar.gz
DIST_TARPATH       := $(DIST_DIR)/$(DIST_TARNAME)
DIST_TARFLAGS      := --create --auto-compress --posix --mode=0755 --recursion --exclude-vcs \
                      --file "$(DIST_TARPATH)"  \
                      --directory "$(DIST_DIR)" \
                      "$(DIST_DIRNAME)"

# Debian packaging
DEBEMAIL           ?= $(EMAIL_SUPPORT)
DEBFULLNAME        ?= $(AUTHOR_NAME)
DEB_DIR            := $(TMPDIR)/deb
DEB_NAME           ?= $(PACKAGE_NAME)-$(PACKAGE_VERS)
DEB_FILENAME       := $(PACKAGE_NAME)-$(PACKAGE_VERS).deb
DEB_DIRPATH        := $(DEB_DIR)/$(DEB_FILENAME)
DEB_DATA           := $(DEB_DIR)/$(DEB_FILENAME)/data

# msginit and msgmerge use the WIDTH to break lines
WIDTH              ?= 80

# which shell to use
SHELL              := /bin/sh

# binaries
GETTEXT            ?= gettext
XGETTEXT           ?= xgettext
MSGFMT             ?= msgfmt
MSGINIT            ?= msginit
MSGMERGE           ?= msgmerge
MSGCAT             ?= msgcat
GZIP               ?= gzip
TAR                ?= tar
SHELLCHECK         ?= shellcheck
GIMME_A_MAN        ?= gimme-a-man
SHUNIT2            ?= $(TMPDIR)/shunit2

# binaries flags
GETTEXTFLAGS       ?=
GETTEXTFLAGS_ALL   := -d "$(TEXTDOMAIN)"
XGETTEXTFLAGS      ?=
XGETTEXTFLAGS_ALL  := --keyword --keyword=__ \
				      --language=shell --from-code=$(CHARSET) \
				      --width=$(WIDTH)       \
				      --sort-output          \
				      --foreign-user         \
				      --package-name="$(PACKAGE_NAME)" --package-version="$(PACKAGE_VERS)" \
				      --msgid-bugs-address="$(MAIL_BUGS_TO)"
MSGFMTFLAGS        ?=
MSGFMTFLAGS_ALL    := --check --check-compatibility
MSGINITFLAGS       ?=
MSGINITFLAGS_ALL   := --no-translator  --width=$(WIDTH)
MSGMERGEFLAGS      ?=
MSGMERGEFLAGS_ALL  := --quiet
MGSCATFLAGS        ?=
MGSCATFLAGS_ALL    := --sort-output --width=$(WIDTH)
GZIPFLAGS          ?=
TARFLAGS           ?= --gzip
SHELLCHECKFLAGS    ?=
SHELLCHECKFLAGS_ALL:= --check-sourced --external-sources

# man helper flags
GIMME_A_MAN_FLAGS     ?=


# Use theses suffixes in rules
.SUFFIXES: .po .mo .pot .gz .sh

# Do not delete those files even if they are intermediaries to other targets
.PRECIOUS: $(PO_FILES) $(MO_FILES)


# replace a variable inside a file (inplace) if not empty (except for PREFIX)
# $(1) string  the name of the variable to replace (will be uppercased)
# $(2) string  the value of the variable to set
# $(3) string  the path to the file to modify
define replace_var_in_file
	set -e; \
	name_upper="`echo "$(1)"|tr '[:lower:]' '[:upper:]'`"; \
	if grep -q "^[[:space:]]*$$name_upper=" "$(3)"; then \
		if [ "$(2)" != '' -o "$$name_upper" = 'PREFIX' ]; then \
			echo "## Replacing var '$$name_upper' with value '$(2)' in file '$(3)'"; \
			sed -e "s#^\([[:blank:]]*$$name_upper=\).*#\1"'"'"$(2)"'"'"#g" -i "$(3)"; \
		fi; \
	fi;
endef

# create man page from help of the script with translation support
# @param  $(1)  string   locale
# @param  $(2)  string   path to script file
# @param  $(3)  string   path to man file output
# @param  $(4)  string   (optional) option to passe to the program instead of --help
define generate_man_from_script_help
	set -e; \
	_locale_short="$(1)"; \
	_locale="$$_locale_short"; \
	if [ "$$(printf '%%s' "$$_locale_short" | wc -c)" -eq 2 ]; then \
		_locale="$${_locale_short}_$$(echo "$$_locale_short" | tr '[a-z]' '[A-Z]').$(CHARSET)"; \
	fi; \
	_prog_name="$(subst _,-,$(basename $(notdir $(2))))"; \
	_opt_help='--help'; \
	_opt_help_text=; \
	if [ "$(4)" != '' ]; then \
		_opt_help="$(4)"; \
		_opt_help_text=" ($(4))"; \
	fi; \
	if [ ! -e "$(3)" ]; then \
		echo "## Creating man page '$(3)' from '$(2)'$$_opt_help_text [$$_locale_short]"; \
	else \
		echo "## Updating man page '$(3)' from '$(2)'$$_opt_help_text [$$_locale_short]"; \
	fi; \
	$(GIMME_A_MAN) \
		--locale "$$_locale" \
		$(GIMME_A_MAN_FLAGS) $(GIMME_A_MAN_FLAGS_ALL) --help-option "$$_opt_help" \
		"$$(realpath "$(2)")" "$$_prog_name" "$$_prog_name $(PACKAGE_VERS)" $(MAN_SECTION) \
	| $(GZIP) $(GZIPFLAGS) > "$(3)";
endef

# install a man
# @param  $(1)  string  locale of the man
# @param  $(2)  string  path to the source man
# @param  $(3)  string  path to the destination man
define install_man
	@echo "## Installing man '$(1)' to '$(3)'"
	@$(INSTALL_DATA) "$(2)" "$(3)"
endef

# install a locale
# @param  $(1)  string  locale name
# @param  $(2)  string  path to the source locale
# @param  $(3)  string  path to the destination locale
define install_locale
	@echo "## Installing locale '$(1)' to '$(3)'"
	@$(INSTALL_DATA) "$(2)" "$(3)"
endef

# re-generate a translation catalogue
# @param  $(1)  string  path to the source script
# @param  $(2)  string  path to the destination catalogue
define regenerate_translation_catalogue
	@echo "## (re-)generating '$(2)' from '$(1)' ..."
	@$(XGETTEXT) $(XGETTEXTFLAGS) $(XGETTEXTFLAGS_ALL) --output "$(2)" "$(1)"
endef

# create or update a translation catalogue from the main one
# @param  $(1)  string  locale name
# @param  $(2)  string  path to the source catalogue
# @param  $(3)  string  path to the destination catalogue
define create_or_update_translation_catalogue
	set -e; \
	_locale_short="$(1)"; \
	_locale="$$_locale_short"; \
	if [ "$$(printf '%%s' "$$_locale_short" | wc -c)" -eq 2 ]; then \
		_locale="$${_locale_short}_$$(echo "$$_locale_short" | tr '[a-z]' '[A-Z]').$(CHARSET)"; \
	fi; \
	if [ ! -e "$(3)" ]; then \
		echo "## Initializing catalogue '$(3)' from '$(2)' [$$_locale_short]"; \
		$(MSGINIT) $(MSGINITFLAGS) $(MSGINITFLAGS_ALL) --input "$(2)" --output "$(3)" \
			--locale="$$_locale" >/dev/null; \
	else \
		echo "## Updating catalogue '$(3)' from '$(2)' [$$_locale_short]"; \
		$(MSGMERGE) $(MSGMERGEFLAGS) $(MSGMERGEFLAGS_ALL) --update "$(3)" "$(2)"; \
		touch "$(3)"; \
	fi
endef


# special case for english manual that do not depends on any translation but on script
$(MAN_DIR)/$(PROGRAM_NAME).en.texi.gz: $(MAIN_SCRIPT)
	@$(call generate_man_from_script_help,en,$<,$@)
$(MAN_DIR)/$(PROGRAM_NAME).conf.en.texi.gz: $(MAIN_SCRIPT)
	@$(call generate_man_from_script_help,en,$<,$@,--help-conf)
$(MAN_DIR)/$(GUI_PROG_NAME).en.texi.gz: $(GUI_SCRIPT)
	@$(call generate_man_from_script_help,en,$<,$@)


# manuals depends on translations
$(MAN_DIR)/$(PROGRAM_NAME).%.texi.gz: $(MAIN_SCRIPT) $(LOCALE_DIR)/%/LC_MESSAGES/$(PROGRAM_NAME).mo
	@$(call generate_man_from_script_help,$*,$<,$@)
$(MAN_DIR)/$(PROGRAM_NAME).conf.%.texi.gz: $(MAIN_SCRIPT) $(LOCALE_DIR)/%/LC_MESSAGES/$(PROGRAM_NAME).mo
	@$(call generate_man_from_script_help,$*,$<,$@,--help-conf)
$(MAN_DIR)/$(GUI_PROG_NAME).%.texi.gz: $(GUI_SCRIPT) $(LOCALE_DIR)/%/LC_MESSAGES/$(GUI_PROG_NAME).mo
	@$(call generate_man_from_script_help,$*,$<,$@)


# compiled translations depends on their not-compiled sources
%.mo: %.po
	@echo "## Compiling catalogue '$<' to '$@'"
	@$(MSGFMT) $(MSGFMTFLAGS) $(MSGFMTFLAGS_ALL) --output "$@" "$<"


# translations files depends on the main translation catalogue
$(LOCALE_DIR)/%/LC_MESSAGES/$(PROGRAM_NAME).po: $(LOCALE_DIR)/$(PROGRAM_NAME).pot
	@$(call create_or_update_translation_catalogue,$*,$<,$@)
$(LOCALE_DIR)/%/LC_MESSAGES/$(GUI_PROG_NAME).po: $(LOCALE_DIR)/$(GUI_PROG_NAME).pot
	@$(call create_or_update_translation_catalogue,$*,$<,$@)
$(LOCALE_DIR)/%/LC_MESSAGES/$(INITRAMFS_PROG_NAME).po: $(LOCALE_DIR)/$(INITRAMFS_PROG_NAME).pot
	@$(call create_or_update_translation_catalogue,$*,$<,$@)
$(LOCALE_DIR)/%/LC_MESSAGES/$(SYSTEMD_PROG_NAME).po: $(LOCALE_DIR)/$(SYSTEMD_PROG_NAME).pot
	@$(call create_or_update_translation_catalogue,$*,$<,$@)


# main translation catalogues depends on the scripts
$(LOCALE_DIR)/$(PROGRAM_NAME).pot: $(MAIN_SCRIPT)
	@$(call regenerate_translation_catalogue,$<,$@)
$(LOCALE_DIR)/$(GUI_PROG_NAME).pot: $(GUI_SCRIPT)
	@$(call regenerate_translation_catalogue,$<,$@)
$(LOCALE_DIR)/$(INITRAMFS_PROG_NAME).pot: $(INITRAMFS_SCRIPT)
	@$(call regenerate_translation_catalogue,$<,$@)
$(LOCALE_DIR)/$(SYSTEMD_PROG_NAME).pot: $(SYSTEMD_SCRIPT)
	@$(call regenerate_translation_catalogue,$<,$@)


# create all required directories
$(DIRS):
	@echo "## Creating directory '$@'"
	@mkdir -p "$@"


# create all install directories
$(INST_DIRS):
	$(PRE_INSTALL)
	@echo "## Creating directory '$@'"
	@mkdir -p -m 0750 "$@"


# install main script
$(INST_MAIN_SCRIPT): $(MAIN_SCRIPT)
	@echo "## Installing main script '$(notdir $<)' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"
	@$(call replace_var_in_file,PACKAGE_NAME,$(PACKAGE_NAME),$@)
	@$(call replace_var_in_file,VERSION,$(PACKAGE_VERS),$@)
	@$(foreach name,$(dirs_var_name),$(call replace_var_in_file,$(name),$($(name)),$@))


# install GUI script
$(INST_GUI_SCRIPT): $(GUI_SCRIPT)
	@echo "## Installing GUI script '$(notdir $<)' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"
	@$(call replace_var_in_file,PACKAGE_NAME,$(PACKAGE_NAME),$@)
	@$(call replace_var_in_file,VERSION,$(PACKAGE_VERS),$@)
	@$(foreach name,$(dirs_var_name),$(call replace_var_in_file,$(name),$($(name)),$@))

# install initramfs script
$(INST_INITRAMFS): $(INITRAMFS_SCRIPT)
	@echo "## Installing initramfs script from '$<' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"

# install initramfs hook
$(INST_HOOK): $(INITRAMFS_HOOK)
	@echo "## Installing initramfs hook from '$<' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"

# install systemd-shutdown script
$(INST_SYSTEMD): $(SYSTEMD_SCRIPT)
	@echo "## Installing systemd-shutdown script from '$<' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"

# install locales
$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(PROGRAM_NAME).mo: $(LOCALE_DIR)/%/LC_MESSAGES/$(PROGRAM_NAME).mo
	@$(call install_locale,$*,$<,$@)
$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(GUI_PROG_NAME).mo: $(LOCALE_DIR)/%/LC_MESSAGES/$(GUI_PROG_NAME).mo
	@$(call install_locale,$*,$<,$@)
$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(INITRAMFS_PROG_NAME).mo: $(LOCALE_DIR)/%/LC_MESSAGES/$(INITRAMFS_PROG_NAME).mo
	@$(call install_locale,$*,$<,$@)
$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(SYSTEMD_PROG_NAME).mo: $(LOCALE_DIR)/%/LC_MESSAGES/$(SYSTEMD_PROG_NAME).mo
	@$(call install_locale,$*,$<,$@)

# install man files
$(DESTDIR)$(mandir)/%/man$(MAN_SECTION)/$(PROGRAM_NAME).$(MAN_SECTION).gz: $(MAN_DIR)/$(PROGRAM_NAME).%.texi.gz
	@$(call install_man,$*,$<,$@)
$(DESTDIR)$(mandir)/%/man$(MAN_SECTION)/$(PROGRAM_NAME).conf.$(MAN_SECTION).gz: $(MAN_DIR)/$(PROGRAM_NAME).conf.%.texi.gz
	@$(call install_man,$*,$<,$@)
$(DESTDIR)$(mandir)/%/man$(MAN_SECTION)/$(GUI_PROG_NAME).$(MAN_SECTION).gz: $(MAN_DIR)/$(GUI_PROG_NAME).%.texi.gz
	@$(call install_man,$*,$<,$@)


# to build everything, create directories then 
# all the man files (they depends on all the rest)
all: $(DIRS) $(MO_FILES) $(MANS)


# install all files to their proper location
install: all $(INST_DIRS) $(INST_FILES)
	@echo "## Renew your initramfs with the following command:"
	@echo "\$$ update-initramfs -u"


# uninstall
uninstall:
	@echo "## Removing files ..."
	@echo "$(INST_FILES)" | tr ' ' '\n' | sed 's/^/##   /g'
	@$(RM) $(INST_FILES)
	@echo "## Removing directories (only the empty ones will be actually removed) ..."
	@echo "$(INST_DIRS)" | tr ' ' '\n' | sed 's/^/##   /g'
	-@rmdir --parents $(INST_DIRS) 2>/dev/null||true


# cleanup
clean:
	@echo "## Removing files ..."
	@echo "$(LOCALE_DIR)/*/LC_MESSAGES/*~ $(srcdir)/*~"
	@$(RM) $(LOCALE_DIR)/*/LC_MESSAGES/*~ $(srcdir)/*~
	@echo "## Removing directory ..."
	@echo "$(TMPDIR)"
	@$(RM) -r $(TMPDIR)


# test
unit-test: $(TMPDIR)
	@[ -e "$(SHUNIT2)" ] || { echo "shunit2 ($(SHUNIT2)) not found" && exit 3; }
	@echo "## Running unit tests ..."
	@TMPDIR="$(TMPDIR)" SHUNIT2="$(SHUNIT2)" sh $(srcdir)/test_unit.sh
test-simple: $(TMPDIR)
	@[ -e "$(SHUNIT2)" ] || { echo "shunit2 ($(SHUNIT2)) not found" && exit 3; }
	@echo "## Running test simple ..."
	@TMPDIR="$(TMPDIR)" SHUNIT2="$(SHUNIT2)" sh $(srcdir)/test_simple.sh
test-retention: $(TMPDIR)
	@[ -e "$(SHUNIT2)" ] || { echo "shunit2 ($(SHUNIT2)) not found" && exit 3; }
	@echo "## Running test retention ..."
	@TMPDIR="$(TMPDIR)" SHUNIT2="$(SHUNIT2)" sh $(srcdir)/test_retention.sh
test-errors: $(TMPDIR)
	@[ -e "$(SHUNIT2)" ] || { echo "shunit2 ($(SHUNIT2)) not found" && exit 3; }
	@echo "## Running test erros ..."
	@TMPDIR="$(TMPDIR)" SHUNIT2="$(SHUNIT2)" sh $(srcdir)/test_errors.sh
test-as-root: $(TMPDIR)
	@[ -e "$(SHUNIT2)" ] || { echo "shunit2 ($(SHUNIT2)) not found" && exit 3; }
	@echo "## Running test as root ..."
	@TMPDIR="$(TMPDIR)" SHUNIT2="$(SHUNIT2)" sh $(srcdir)/test_as_root.sh


# shellcheck
shellcheck:
	@echo "## Checking shell errors and POSIX compatibility"
	@for script in "$(MAIN_SCRIPT)" "$(GUI_SCRIPT)" "$(INITRAMFS_SCRIPT)" "$(INITRAMFS_HOOK)" \
				   "$(SYSTEMD_SCRIPT)"; \
	do \
	    echo "  $$s"; \
	    _extra_args=''; \
	    $(SHELLCHECK) $(SHELLCHECKFLAGS) $(SHELLCHECKFLAGS_ALL) $$_extra_args "$$s"; \
	done;


# create all dist directories
$(DIST_DIRS):
	@echo "## Creating directory '$@'"
	@mkdir -p -m 0755 "$@"


# copy (hard link) source files
$(DIST_DIRPATH)/%: $(srcdir)/%
	@echo "## Copying source file '$<' to '$@'"
	@ln "$<" "$@"


# distribution tarball
$(DIST_TARPATH): $(DIST_FILES)
	@echo "## Creating distribution tarball '$@'"
	@$(TAR) $(TARFLAGS) $(DIST_TARFLAGS)


# create a distribution tarball
dist: all $(DIST_DIRS) $(DIST_TARPATH)


# dist cleanup
distclean: clean


# catch-all
.PHONY: all install uninstall clean unit-test test-simple test-retention test-errors test-as-root shellcheck dist distclean


# default target
.DEFAULT_GOAL := all

# vim:set ts=4 sw=4
