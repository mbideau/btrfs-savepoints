# btrfs-savepoints - Backup and Restore instantly with ease your BTRFS filesystem

A suite of well tested POSIX shell scripts to provide system's backup and restore functionalities
(with a GUI for restoration) minimising/optimising the number of BTRFS snapshots to keep the system
performing well and selecting the most secure backups over the unsafe ones when pruning.

All backups are planed and happen instantaneously without user interaction or slow down.  
The restoration GUI can be displayed at boot time (if the user hit a keyboard key), allowing
him/she to fully restore its system in seconds with a clear view of what are the differences
between the current system and the backup.

There are absolutely no dependencies other than the `GNU coreutils`, except the `btrfs-progs` and
`whiptail` for the GUI. You should add `gettext` to get translations but that's optional.  
And I strongly recommend using a BTRFS diff utility like my
[btrfs-diff-sh](https://github.com/mbideau/btrfs-diff-sh), to get more insight about save points.

Backups, are *BTRFS snapshots*, respecting some naming convention, and in this project we
call them *save points*, hence the name of the program _btrfs-**sp**_.

**Table of content**
<!-- toc -->

- [Usage](#usage)
- [Aren't already thousands of backup solutions out there ?! Yes, but not like this one](#arent-already-thousands-of-backup-solutions-out-there--yes-but-not-like-this-one)
- [Very easy to use: setup and forget it (after testing it :wink:)](#very-easy-to-use-setup-and-forget-it-after-testing-it-wink)
- [Installation and first run](#installation-and-first-run)
- [Getting started: to backup the root filesystem and restore a test subvolume](#getting-started-to-backup-the-root-filesystem-and-restore-a-test-subvolume)
  - [Skyview of the savepoint configuration](#skyview-of-the-savepoint-configuration)
- [Killer feature : the two pruning algorithms, keeping only few relevant BTRFS snapshots](#killer-feature--the-two-pruning-algorithms-keeping-only-few-relevant-btrfs-snapshots)
- [Why shell script and not X interpreteted language, or X compiled language ? Because, not yet ;-)](#why-shell-script-and-not-x-interpreteted-language-or-x-compiled-language--because-not-yet--)
- [What's missing ? Restoring from a remote backup/savepoint](#whats-missing--restoring-from-a-remote-backupsavepoint)
- [Feedbacks wanted, PR/MR welcome :heart:](#feedbacks-wanted-prmr-welcome-heart)
  - [Improvements considered](#improvements-considered)
    - [TODO](#todo)
  - [Developing](#developing)
  - [Testing](#testing)
  - [Debuging](#debuging)
- [But BTRFS is cripled with bugs, right ? End word for those that still doesn't RTFM](#but-btrfs-is-cripled-with-bugs-right--end-word-for-those-that-still-doesnt-rtfm)
- [Copyright and License GPLv3](#copyright-and-license-gplv3)
- [Code of conduct](#code-of-conduct)
- [About this document](#about-this-document)
  - [License: CC-BY-SA](#license-cc-by-sa)
  - [Author: Michael Bideau](#author-michael-bideau)
  - [Made with: Formiko and Vim, plus some helpers/linters](#made-with-formiko-and-vim-plus-some-helperslinters)

<!-- /toc -->

## Usage

This is an extract of the output of `btrfs-sp --help` :

```text

btrfs-sp - backup and restore instantly with ease your BTRFS filesystem.

USAGE

    btrfs-sp [OPTIONS] COMMAND [CMD_ARGS]

    btrfs-sp new-conf CONFIG MOUNTED_PATH SUBVOL_PATH
    btrfs-sp ls-conf

    btrfs-sp backup
    btrfs-sp restore  CONFIG SAVEPOINT
    btrfs-sp delete   CONFIG SAVEPOINT ..SAVEPOINTS..

    btrfs-sp ls
    btrfs-sp diff CONFIG SP_REF SP_CMP
    btrfs-sp subvol-diff CONFIG SP_CMP

    btrfs-sp prune
    btrfs-sp replace-diff
    btrfs-sp rotate-number

    btrfs-sp log
    btrfs-sp log-add

    btrfs-sp [ -h | --help ]


COMMANDS

    … extract truncated …

OPTIONS

    … extract truncated …

CONFIGURATION

    See the option '--help-conf' or the man page 'btrfs-sp.conf'.

FILES

    /etc/btrfs-sp/btrfs-sp.conf
        The default global configuration path (if not overriden with option --global-config).

    /etc/btrfs-sp/btrfs-sp.local.conf
        The default configuration path for local overrides.

    /etc/btrfs-sp/conf.d
        Directory where to find the configurations for each managed folder.

NOTES
    The backup directory must be reachable inside the top level BTRFS filesystem mount.
    This implies that it must be in the same BTRFS filesystem than the backuped subvolumes
    (and also because of 'btrfs send/receive').

EXAMPLES

    Get the differences between two snapshots.
    $ btrfs-sp diff rootfs 2020-12-25_22h00m00.shutdown.safe 2019-12-25_21h00m00.shutdown.safe

ENVIRONMENT

    DEBUG
        Print debuging information to 'STDERR' only if DEBUG='btrfs-sp'.

    LANGUAGE
    LC_ALL
    LANG
    TEXTDOMAINDIR
        Influence the translation.
        See GNU gettext documentation.

… extract truncated …

```

## Aren't already thousands of backup solutions out there ?! Yes, but not like this one

I have done my homework and benchmarked a lot of solutions, see
[Prior art analysis document](Prior%20Art%20analysis.md), but none where meeting my requirements:

- **System restoration in a guarantied coherent state**: _safe backup_ concept
- **User friendly**: no user interactions when it is not required, and when it is: GUI with
  intuitive actions calls
- **Instantaneous**: never wait, even a little, every time there is a backup, a pruning, or a
  restoration
- **Efficient**: no performance loss / slow down of the computer, no matter how frequent the
  backups are
- **Smart**: retains the backup with the most values, and dump the rest to remain efficient
- **Hackable**: a shell script is perfect for that
- **Translated**: because not all users speaks English
- **Initramfs friendly**: able to run in initramfs, for restoration at boot time

See the
[killer features](#killer-feature--the-two-pruning-algorithms-keeping-only-few-relevant-BTRFS-snapshots)
below to know more about how I implemented that solution.

For the story: I started to use and create backup solutions two decades ago :

- first using [grsync](https://sourceforge.net/projects/grsync/)
- then [rsync](https://rsync.samba.org/) + ssh in a basic way
- also its derivatives [rdiff-backup](https://rdiff-backup.net/),
  [duplicity](http://duplicity.nongnu.org/) and
  [rsnapshot](https://rsnapshot.org/) (using
  [hardlinks](https://linuxhandbook.com/hard-link/))
- more industrial "overkill" solutions like [Bacula](https://www.bacula.org/)
- more custom made one with [tar](https://en.wikipedia.org/wiki/Tar_(computing)) then with
  [dar](http://dar.linux.free.fr/) to get better metadata support and offline diffs
- more user friendly [Timeshift](https://github.com/teejee2008/timeshift)
- almost found the _Graal_ with [borg-backup](https://www.borgbackup.org/), but it was slow and
  only CLI (at that time). I have used it during 4 or 5 years, and it saved my ass multiple times !
  Thank you guys

I finally ended up using a BTRFS file system which had changed everything.  
It offered me instantaneous snapshots (no more scanning, diff, and hardlinks), and live checksumming
(for hardware health and preventing silent corruption), basically for free. And one layer less in
the filesystem stack to manage RAID (before it was md + lvm2), with a minor downside (booting with
only one disk when two are configured in RAID will force read-only degraded mode).

Based on that filesystem specificity, I tried BTRFS [snapper](http://snapper.io/) from OpenSuse, but
wasn't satisfied the way it was designed (I couldn't bring it to the initramfs efficiently), then
other hack-ish scripts solutions (mentioned in the
[Prior art analysis document](Prior%20Art%20analysis.md#0)).

## Very easy to use: setup and forget it (after testing it :wink:)

There is a lot going on technically, but the every day use is a breath.
Set it up properly, then forget about it.  
The day you'll need it, it will just works (if you have tested it before and made no change to the
configuration or the BTRFS layout in the meantime, else just update the conf and test again).

I guaranty you will feel that after following those very quick installation steps ;-)


## Installation and first run

You should already have installed the `btrfs-progs` package in order to have your filesystem on it
(right ?). Else, I have added it to the command below, just in case. If you are testing BTRFS from
another filesystem, which one and why, tell [me](mailto:mica.devel@gmail.com).

Install the dependencies (for *Debian* based distro):

```sh
~> sudo apt install btrfs-progs git make gettext grep gzip tar sed mawk coreutils whiptail
```

Install the man page generator named [gimme-a-man](https://github.com/mbideau/gimme-a-man):

```sh
~> git clone -q https://github.com/mbideau/gimme-a-man
~> cd gimme-a-man
~> make
~> sudo make install prefix=/usr
```

I highly recommends (but it is not required) to also install a _btrfs-diff_ utility like
[btrfs-diff-sh](https://github.com/mbideau/btrfs-diff-sh):

```sh
~> git clone -q https://github.com/mbideau/btrfs-diff-sh
~> cd btrfs-diff
~> make
~> sudo make install prefix=/usr
```

Clone the sources repository somewhere

```sh
~> git clone -q htttps://github.com/mbideau/btrfs-savepoints /tmp/btrfs-savepoints
~> cd /tmp/btrfs-savepoints
```

Compile the translation files and manual pages

```sh
~> make
```

Install it into your system (`/usr/local` by default, use `prefix=/usr` as an option)

```sh
~> sudo make install prefix=/usr
```

This will install the following scripts to the following locations :

```text
* btrfs_sp.sh                  -> /usr/sbin/btrfs-sp
* btrfs_sp_restore_gui.sh      -> /usr/sbin/btrfs-sp-restore-gui
* btrfs_sp_initramfs_hook.sh   -> /etc/initramfs-tools/hooks/btrfs-sp
* btrfs_sp_initramfs_script.sh -> /etc/initramfs-tools/scripts/local-premount/btrfs-sp
* btrfs_sp_systemd_script.sh   -> /lib/systemd/system-shutdown/btrfs-sp.shutdown
```

Plus the translation files and the manual pages.

If you want to know more about this program, do :

```sh
~> man btrfs-sp
```

## Getting started: to backup the root filesystem and restore a test subvolume

Go read the [tutorial](Getting%20started%20-%20tutorial.md#0).

If you are feeling smart and impatient, this is the
[TL;DR](https://en.wikipedia.org/wiki/Wikipedia:Too_long;_didn%27t_read) :

```sh
~> sudo mkdir -p /mnt/toplevel
~> sudo mount -t btrfs -o subvol=/ "$(mount | grep ' on / ' | awk '{print $1}')" /mnt/toplevel
~> sudo mkdir -m 0770 /backup/btrfs-sp
~> [ -d /etc/btrfs-sp ] || sudo mkdir -p 0770 /etc/btrfs-sp
~> sudo cp examples/deleguate-to-local.global.conf /etc/btrfs-sp/btrfs-sp.conf
~> sudo cp examples/examples/desktop.global.conf /backup/btrfs-sp/btrfs-sp.local.conf
~> sudo btrfs-sp add-conf root / /root
~> sudo btrfs-sp ls-conf
~> sudo btrfs-sp backup --config root --suffix '.my-very-first-one'
~> sudo btrfs-sp ls --config root
~> sudo update-initramfs -u
~> reboot
~> sudo btrfs-sp ls --config root
```

And for restoration (with a test subvolume)

```sh
~> sudo brtfs subvolume create /testsbuvol
~> sudo btrfs-sp add-conf test /testsbuvol /testsbuvol
~> sudo btrfs-sp backup --config test --suffix '.my-first-test'
~> sudo btrfs-sp ls --config test
~> echo 'This is a test content' | sudo tee /testsbuvol/testfile.txt
~> sudo btrfs-sp backup --config test --suffix '.my-2nd-test'
~> sudo btrfs-sp ls --config test
~> echo "I don't like that bad content" | sudo tee /testsbuvol/badfile.txt
~> sudo btrfs-sp-restore-gui
~> sudo btrfs-sp ls --config test
```

### Skyview of the savepoint configuration

Lets look a little bit into that new configuration file.

The new configuration file, have been copied all the global default values, plus the two important
ones to tell what BTRFS subvolume to backup.

- **SUBVOLUME** is the path of the BTRFS subvolume to backup (relative to the rootfs when mounted
  into it)

- **SUBVOLUME_FROM_TOPLEVEL_SUBVOL** is the same as above but unmounted, and relative to the BTRFS
  top level subvolume (id: 5)

Then you'll have the following that tells when to automaticaly do a backup :

- **BACKUP_BOOT**
- **BACKUP_REBOOT**
- **BACKUP_SHUTDOWN**
- **BACKUP_…**

For example if you set `BACKUP_REBOOT=no` no backup will be automatically taken at reboot time.

The following tells at what time (called moment) the backup is considered safe :

- **SAFE_BACKUP** usually it is safe when filesystem are unmounted, like in *reboot* and *shutdown*

And then comes the parameters of the pruning algorithm (which will be explained further below) :

- **KEEP_NB_SESSIONS**
- **KEEP_NB_MINUTES**
- **KEEP_NB_HOURS**
- **KEEP_NB_DAYS**
- **KEEP_NB_WEEKS**
- **KEEP_NB_MONTHS**
- **KEEP_NB_YEARS**

Finaly comes the hooks. Those are commands or script that can be triggered before/after a backup or
a restoration.

- **HOOK_BEFORE_BACKUP**
- **HOOK_AFTER_BACKUP**
- **HOOK_BEFORE_RESTORE**
- **HOOK_AFTER_RESTORE**


To better understand each options,read the *CONFIGURATION* section in the manual pages

```sh
~> man btrfs-sp.conf
```

## Killer feature : the two pruning algorithms, keeping only few relevant BTRFS snapshots

It is known that
[BTRFS might have slowness when dealing with a large amount of snapshots](https://btrfs.wiki.kernel.org/index.php/Gotchas#Having_many_subvolumes_can_be_very_slow),
specialy when deleting one.

So I implemented two pruning algorithms with the goal of minimizing the amount of snapshots meanhile
retaining the ones with the most value.

They are automaticaly triggered after every creation of savepoint.

If you want to dive in the details, there is a (rather)
[short explanation of their inner process](Pruning%20algorithms.md#0).


## Why shell script and not X interpreteted language, or X compiled language ? Because, not yet ;-)

I choose hackability of shell script over performance, but I consider rewritting it to a more
optimized language after a while in production.

For more insight about how I see the choice of a programming language, refer to
[that text of mine](https://github.com/mbideau/tech-design-principles/blob/main/Choosing%20a%20programming%20language%20for%20a%20project.md).


## What's missing ? Restoring from a remote backup/savepoint

First, snapshots are backups, because they allow to recover from deletion or just going back in
time. But they are not durable backups, they are kind of ephemeral. They won't be of any help if
your disk die.

In order to have more permanent backups, you should have them on another device, and also in another
site, which are two different things BTW.

Whether it is one or the other, it is as easy as configuring a hook with the variable
**HOOK_AFTER_BACKUP**, that will receive the backup path as an argument, and might simply do a
*btrfs send/receive* or an *rsync* to a remote site or USB drive.

What is really missing is the ability to restore the system from a remote backup/savepoint.
That would be the next best/important thing to implement.  
This task is not trivial, it has to intregrate well with the local restoration and provide the same
level of functionnality (seeing the differences with the current system before actualy doing the
restoration), but that's feasible in a not-so-far-away future.


## Feedbacks wanted, PR/MR welcome :heart:

If you have any question or wants to share your uncovered case, please I be glad to answer and
accept changes through Pull Request.

### Improvements considered

I have considered to split the program into multiple smaller ones, respecting the
[Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy), but it would bring no value at
all because taking backups is just one line of code, the important parts are the pruning algorithms,
which is almost 95% of what that program is.  
Though, I may move the restore GUI to its own repo at some point.

Another aspect that could be improved, but I let that part for later, is to have an even better
pruning algorithm, based on smarter criterias, like the about the amount of differences (with the X
previous snapshots), plus the quality/kind of differences (like changing a critical file, or
deleting a system package).

On a technical point of view, more tests can be writthen to improve the reliability of the program,
specialy the tests suite checking the behaviour in case of errors (I really lack motivation for this
one), see file `test-errors.sh`.

#### TODO

- [ ] fix the TODOs in the code
- [ ] add example hook script to send the snapshots to remote location or USB drive
- [ ] create packages for _GNU Linux_ distributions
- [ ] create a screencast to showcase the program and the restoration GUI
- [ ] write an article to promote the software and post it on relevant forums and social networks
- [ ] move the restoration GUI to its own repository
- [ ] write more test cases, specially to for error management
- [ ] design and implement a diff protocol that allows do to diff between a local backup and a
  remote one
- [ ] design and implement restoration from remote backups

### Developing

If you want to develop that program, ensure to respect the standards use in the differents files
(POSIX, GNU Makefile, GNU gettext, etc.), and check the quality/correctness of your shell code with
[shellcheck](https://www.shellcheck.net/) :

```sh
~> make shellcheck
```

### Testing

Like said at the begining, I tried to test the program as much as I could.
I have used [shunit2](https://github.com/kward/shunit2/) which is simple and great for that job.

Using a test suite based on shell also means that I can keep that test suite even if I (or someone
else) rewrite the program in another programming language.

The retention test use `tree` so make sure it is installed :

```sh
~> sudo apt install tree
```

To start testing, install *shunit2* somewhere and specify its path while running the tests :

```sh
~> git clone -q https://github.com/kward/shunit2.git /tmp/shunit2
~> SHUNIT2=/tmp/shunit2/shunit2 make unit-test
```

There are all the following tests suite available :

- unit-test : testing of the inner functions of the program
- test-simple : testing of the main features of the program
- test-retention : testing the retention strategy behaviour
- test-as-root : testing in the context of root filesystem being unmounted, but accessible through
  a mount point of the BTRFS top level subvolume (like in *initram* or *systemd-shutdown*).


### Debuging

If you want to debug the program you should pass the following environment variable :

- for btrfs-sp: **DEBUG=btrfs-sp**
- for btrfs-sp-restore-gui: **DEBUG_GUI=true** and **DEBUG=btrfs-sp** if you want
- for the initram script: **DEBUG=btrfs-sp**
- for the systemd script: **DEBUG=btrfs-sp**


## But BTRFS is cripled with bugs, right ? End word for those that still doesn't RTFM

Nope, BTRFS is fine if you stay in the safe and known path with only the
[stable and mature features](https://btrfs.wiki.kernel.org/index.php/Status), which is specifed in
the
[first paragraph of the first page of the documentation of the project](https://btrfs.wiki.kernel.org/index.php/Main_Page#Stability_status).


## Copyright and License GPLv3

Copyright © 2020-2021 Michael Bideau, France

The *btrfs-savepoints* source codes are licensed under a _GPLv3_ license.  
The source codes are all the files in the project, but the Mardown ones (_.md_), which are licensed
under a _CC-BY-SA_ license (like the current document).

*btrfs-savepoints* is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

*btrfs-savepoints* is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along with *btrfs-savepoints*. If not,
see [https://www.gnu.org/licenses/](https://www.gnu.org/licenses/).


## Code of conduct

Please note that this project is released with a *Contributor Code of Conduct*. By participating in
this project you agree to abide by its terms.


## About this document

### License: CC-BY-SA

[![License: CC BY-SA 4.0](https://licensebuttons.net/l/by-sa/4.0/80x15.png)
](https://creativecommons.org/licenses/by-sa/4.0/)

Copyright © 2020-2021 Michael Bideau, France  
This document is licensed under a
[Creative Commons Attribution 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

### Author: Michael Bideau

Michael Bideau, France

### Made with: Formiko and Vim, plus some helpers/linters

I started with [formiko](https://github.com/ondratu/formiko), then used
[mdtoc](https://github.com/kubernetes-sigs/mdtoc) to generate the table of content, and finally used
[vim](https://www.vim.org/) with linters to help catching mistakes and badly written sentences:

- [mdl](https://github.com/markdownlint/markdownlint)
- [proselint](http://proselint.com)
- [write-good](https://github.com/btford/write-good)
