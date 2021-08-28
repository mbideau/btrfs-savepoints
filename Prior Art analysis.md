# btrfs-savepoints - Backup and Restore instantly with ease your BTRFS base filesystem

## Review of the existing project

### Restore

btrroll

  https://github.com/SpencerMichaels/btrroll
  + it is executed in initrd, it seems to do the job well (not tested though)
  + allow to add a description to the snapshots
  - not configurable enough for me (fixed root.d/snapshots and symlinks)
  - manage the bootloader entries itself (and specificaly systemd-boot)
  - seems to only take care of restoring one subvolume (not multiple at once)


### Backup

btrbk (perl)

  https://github.com/digint/btrbk
  + very simple configuration
  + lots of features
  - perl
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - no minimization of snapshots number

bktr (rust)

  https://github.com/yuqio/bktr
  - no documentation at all

sanoid (perl)

  https://github.com/jimsalterjrs/sanoid
  - no btrfs support (as I understand, because they claim btrfs is not stable, WTF)

incrbtrfs (go)

  https://github.com/drewkett/incrbtrfs
  + can send snapshots to remote
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - no minimization of snapshots number

minisnap (go)

  https://github.com/adrian-bl/minisnap
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - no minimization of snapshots number

btrfs-time-machine (go)

  https://github.com/sam701/btrfs-time-machine
  + very simple configuration
  - no documentation at all
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - no minimization of snapshots number

snapbtr

  https://github.com/yvolchkov/snapbtr
  + very smart retention strategy, by scoring / distance (same as the previous one)
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy

snapbtrex (python)

  https://github.com/yoshtec/snapbtrex
  + very smart retention strategy, by scoring / distance (same as the previous one)
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy

buttermanager (python)

  https://github.com/egara/buttermanager
  + integrates with grub-btrfs

snap-in-time (python)

  https://snap-in-time.readthedocs.io/en/latest/culling_explained.html
  + very smart retention strategy, by progressively keep less and less daily/weekly snapshots
  + great documentation
  + does remote sending of the snapshots
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy

coward (python)

  https://github.com/n-st/coward/blob/master/coward.example.yaml
  + does remote sending of the snapshots
  ~ kind of a little rude (but complete) documentation (in a config file)
  - no minimization of snapshots number
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - simplistic retention strategy

btr-backup (python)

  https://github.com/klarsson/btr-backup
  + does remote sending of the snapshots
  - kind of a wip
  - almost no doc
  - python (not runnable in initrd without embeding the python binary)
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - simplistic retention strategy

btrfs-snappy (python)

  https://github.com/patrickglass/btrfs-snappy
  + does remote sending of the snapshots
  - kind of a wip
  - almost no doc
  - python (not runnable in initrd without embeding the python binary)
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - simplistic retention strategy

UBackup (python)

  https://github.com/UlrichBerntien/UBackup
  + does remote sending of the snapshots
  - documentation introduction is great, but no doc for retention strategy
  - python (not runnable in initrd without embeding the python binary)
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - simplistic retention strategy

snapman (python)

  https://github.com/mdomlop/snapman
  + has a gui
  + great documentation
  + does remote sending of the snapshots
  + does snapshot minimization (diff with previous)
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - simplistic retention strategy

btrfs-backup (python)

  https://github.com/d-e-s-o/btrfs-backup/tree/devel/btrfs-backup
  + interesting use of filters
  + great documentation
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - simplistic retention strategy

plasma-backup (python)

  https://github.com/m1kc/plasma-backup
  + great documentation
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - no minimization of snapshots number
  - simplistic retention strategy
  - overkill and too simple at the same time

lazysnapshotter (python)

  https://github.com/jwdev42/lazysnapshotter/blob/master/doc/lazysnapshotter.md
  + management of LUKS container (but useless most of the time)
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - no minimization of snapshots number
  - simplistic retention strategy
  - overkill and too simple at the same time

manjaro-album (python)

  https://github.com/philmmanjaro/manjaro-album
  + try to update grub entries by replacing update-grub
  - python (not runnable in initrd without embeding the python binary)
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - no minimization of snapshots number
  - simplistic retention strategy
  - overkill and too simple at the same time

btrfs-snapshotter (python)

  https://github.com/rb1205/btrfs-snapshotter
  + very smart retention strategy, by progressively keep less and less daily/weekly snapshots
  + great documentation
  - python (not runnable in initrd without embeding the python binary)
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy

btrfs-snapshot-backup-manager (python)

  https://github.com/sww1235/btrfs-snapshot-backup-manager
  ~ try to mimic snapper (I don't actually feal that is a great point)
  + command to diff snapshots (but unused)
  - python (not runnable in initrd without embeding the python binary)
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - overkill and too simple at the same time

btrfs-snapshot-rotation (shell)

  https://github.com/mmehnert/btrfs-snapshot-rotation
  + one of the oldest (a lot of other tools do no improvment over this old one)
  - simplistic retention strategy
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy

adlibre-backup (shell)

  https://github.com/adlibre/adlibre-backup
  + lots of features
  + great documentation
  - simplistic retention strategy
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - overkill and too simple at the same time

snazzer (shell)

  https://github.com/csirac2/snazzer
  + lots of features
  + great documentation
  - simplistic retention strategy
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - overkill and too simple at the same time

btrfs-backup (shell)

  https://github.com/3coma3/btrfs-backup
  + one of the best
  + simplicity and complexity well managed
  + no dependencies
  + able to implement complexe retention strategies (hierarchical by default)
  + let the user handle the order of the execution (prune first, then backup, or the over way, and more)
  + dry run
  + lean code
  - no minimization of snapshots number
  - no way to differenciate between safe snapshots and unsafe one in retention strategy
  - bash (not runable in initramfs I think, busybox use dash)

btrfs-auto-snapshot (shell)

  https://github.com/mk01/btrfs-auto-snapshot
  ~ mimics zfs autobackup
  + lean code
  + old (so others could have extended this one instead of duplicating effort)
  + can flag snapshots to be excluded from retention
  - miss rollbacks (the whole point)
  - require a specific fs structure mixing data and snapshots (I personaly don't like it)


### Extra / interesting

btrfs-diff-gui

  https://github.com/igelbox/btrfs-diff-gui


### Duplicates with no improvement

The following project should have spent more time investigating what currently existed before
even starting, because, **to my comprehension**, they ended up having less value than the other
previously existing projects (less features, less quality, or both).
Like re-inventing the wheel, but [squared, without a catenary road](https://mathenchant.wordpress.com/2015/07/15/the-lessons-of-a-square-wheeled-trike/).

  https://github.com/ehazlett/shadow (python)
  https://github.com/lenzenmi/btrsnap (python)
  https://github.com/dcepelik/snap (go)
  https://github.com/mmckeen/btrfs-backup (go)
  https://github.com/DeedleFake/yabs (go)
  https://github.com/Nonpython/claw (python)
  https://github.com/adferrand/rsbtbackup (python)
  https://github.com/pyokagan/btrup
  https://github.com/sjuvonen/tessa
  https://github.com/pj1031999/pjbackup
  https://github.com/fabianmenges/snapd
  https://github.com/RobWouters/btrsnap.py
  https://github.com/avishorp/btrfs-snaprotate
  https://github.com/j-szulc/Btrfs-autosnap
  https://github.com/johannes-mueller/saltoreto
  https://github.com/cycoe/btrfs-machine
  https://github.com/ArnaudLevaufre/btrfs-simple-snapshots
  https://github.com/jf647/btrfs-snap
  https://github.com/nachoparker/btrfs-snp
  https://github.com/nachoparker/btrfs-sync
  https://github.com/moviuro/butter
  https://github.com/c0xc/btrfs-snapshot
  https://github.com/dodo/btrtime
  https://github.com/hunleyd/btrfs-auto-snapshot


## About this document

### License: CC-BY-SA

[![License: CC BY-SA 4.0](https://licensebuttons.net/l/by-sa/4.0/80x15.png)](https://creativecommons.org/licenses/by-sa/4.0/)  

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
