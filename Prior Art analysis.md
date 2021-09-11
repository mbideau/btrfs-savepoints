# btrfs-savepoints - Backup and Restore instantly with ease your BTRFS filesystem

## Review of the existing projects

### Restore

- [btrroll](https://github.com/SpencerMichaels/btrroll)

  - :heavy_plus_sign: it is executed in initrd, it seems to do the job well (not tested though)
  - :heavy_plus_sign: allow to add a description to the snapshots
  - :heavy_minus_sign: not configurable enough for me (fixed root.d/snapshots and symlinks)
  - :heavy_minus_sign: manage the bootloader entries itself (and specificaly systemd-boot)
  - :heavy_minus_sign: seems to only take care of restoring one subvolume (not multiple at once)


### Backup

- [btrbk (perl)](https://github.com/digint/btrbk)

  - :heavy_plus_sign: very simple configuration
  - :heavy_plus_sign: lots of features
  - :heavy_minus_sign: perl
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: no minimization of snapshots number

- [bktr (rust)](https://github.com/yuqio/bktr)

  - :heavy_minus_sign: no documentation at all

- [sanoid (perl)](https://github.com/jimsalterjrs/sanoid)

  - :heavy_minus_sign: no btrfs support (as I understand, because they claim btrfs is not stable, WTF)

- [incrbtrfs (go)](https://github.com/drewkett/incrbtrfs)

  - :heavy_plus_sign: can send snapshots to remote
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: no minimization of snapshots number

- [minisnap (go)](https://github.com/adrian-bl/minisnap)

  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: no minimization of snapshots number

- [btrfs-time-machine (go)](https://github.com/sam701/btrfs-time-machine)

  - :heavy_plus_sign: very simple configuration
  - :heavy_minus_sign: no documentation at all
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: no minimization of snapshots number

- [snapbtr](https://github.com/yvolchkov/snapbtr)

  - :heavy_plus_sign: very smart retention strategy, by scoring / distance (same as the previous one)
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy

- [snapbtrex (python)](https://github.com/yoshtec/snapbtrex)

  - :heavy_plus_sign: very smart retention strategy, by scoring / distance (same as the previous one)
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy

- [buttermanager (python)](https://github.com/egara/buttermanager)

  - :heavy_plus_sign: integrates with grub-btrfs

- [snap-in-time (python)](https://snap-in-time.readthedocs.io/en/latest/culling_explained.html)

  - :heavy_plus_sign: very smart retention strategy, by keeping less and less daily/weekly snapshots
  - :heavy_plus_sign: great documentation
  - :heavy_plus_sign: does remote sending of the snapshots
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention
    strategy

- [coward (python)](https://github.com/n-st/coward/blob/master/coward.example.yaml)

  - :heavy_plus_sign: does remote sending of the snapshots
  - :heavy_plus_sign: kind of a little raw (but complete) documentation (in a config file)
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: simplistic retention strategy

- [btr-backup (python)](https://github.com/klarsson/btr-backup)

  - :heavy_plus_sign: does remote sending of the snapshots
  - :heavy_minus_sign: kind of a wip
  - :heavy_minus_sign: almost no doc
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: simplistic retention strategy

- [btrfs-snappy (python)](https://github.com/patrickglass/btrfs-snappy)

  - :heavy_plus_sign: does remote sending of the snapshots
  - :heavy_minus_sign: kind of a wip
  - :heavy_minus_sign: almost no doc
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: simplistic retention strategy

- [UBackup (python)](https://github.com/UlrichBerntien/UBackup)

  - :heavy_plus_sign: does remote sending of the snapshots
  - :heavy_minus_sign: documentation introduction is great, but no doc for retention strategy
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: simplistic retention strategy

- [snapman (python)](https://github.com/mdomlop/snapman)

  - :heavy_plus_sign: has a gui
  - :heavy_plus_sign: great documentation
  - :heavy_plus_sign: does remote sending of the snapshots
  - :heavy_plus_sign: does snapshot minimization (diff with previous)
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: simplistic retention strategy

- [btrfs-backup (python)](https://github.com/d-e-s-o/btrfs-backup/tree/devel/btrfs-backup)

  - :heavy_plus_sign: interesting use of filters
  - :heavy_plus_sign: great documentation
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: simplistic retention strategy

- [plasma-backup (python)](https://github.com/m1kc/plasma-backup)

  - :heavy_plus_sign: great documentation
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: simplistic retention strategy
  - :heavy_minus_sign: overkill and too simple at the same time

- [lazysnapshotter (python)](https://github.com/jwdev42/lazysnapshotter/blob/master/doc/lazysnapshotter.md)

  - :heavy_plus_sign: management of LUKS container (but useless most of the time)
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: simplistic retention strategy
  - :heavy_minus_sign: overkill and too simple at the same time

- [manjaro-album (python)](https://github.com/philmmanjaro/manjaro-album)

  - :heavy_plus_sign: try to update grub entries by replacing update-grub
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: simplistic retention strategy
  - :heavy_minus_sign: overkill and too simple at the same time

- [btrfs-snapshotter (python)](https://github.com/rb1205/btrfs-snapshotter)

  - :heavy_plus_sign: very smart retention strategy, by keeping less and less daily/weekly snapshots
  - :heavy_plus_sign: great documentation
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy

- [btrfs-snapshot-backup-manager (python)](https://github.com/sww1235/btrfs-snapshot-backup-manager)

  - :wavy_dash: try to mimic snapper (I don't actually feel that is a great point)
  - :heavy_plus_sign: command to diff snapshots (but unused)
  - :heavy_minus_sign: python (not runnable in initrd without embeding the python binary)
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: overkill and too simple at the same time

- [btrfs-snapshot-rotation (shell)](https://github.com/mmehnert/btrfs-snapshot-rotation)

  - :heavy_plus_sign: one of the oldest (a lot of other tools do no improvment over this old one)
  - :heavy_minus_sign: simplistic retention strategy
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy

- [adlibre-backup (shell)](https://github.com/adlibre/adlibre-backup)

  - :heavy_plus_sign: lots of features
  - :heavy_plus_sign: great documentation
  - :heavy_minus_sign: simplistic retention strategy
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: overkill and too simple at the same time

- [snazzer (shell)](https://github.com/csirac2/snazzer)

  - :heavy_plus_sign: lots of features
  - :heavy_plus_sign: great documentation
  - :heavy_minus_sign: simplistic retention strategy
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: overkill and too simple at the same time

- [btrfs-backup (shell)](https://github.com/3coma3/btrfs-backup)

  - :heavy_plus_sign: one of the best
  - :heavy_plus_sign: simplicity and complexity well managed
  - :heavy_plus_sign: no dependencies
  - :heavy_plus_sign: able to implement complexe retention strategies (hierarchical by default)
  - :heavy_plus_sign: let the user handle the order of the execution (prune first, then backup, or
    the over way, and more)
  - :heavy_plus_sign: dry run
  - :heavy_plus_sign: lean code
  - :heavy_minus_sign: no minimization of snapshots number
  - :heavy_minus_sign: no way to differenciate between safe snapshots and unsafe one in retention strategy
  - :heavy_minus_sign: bash (not runable in initramfs I think, busybox use dash)

- [btrfs-auto-snapshot (shell)](https://github.com/mk01/btrfs-auto-snapshot)

  - :wavy_dash: mimics zfs autobackup
  - :heavy_plus_sign: lean code
  - :heavy_plus_sign: old (so others could have extended this one instead of duplicating effort)
  - :heavy_plus_sign: can flag snapshots to be excluded from retention
  - :heavy_minus_sign: miss rollbacks (the whole point)
  - :heavy_minus_sign: require a specific fs structure mixing data and snapshots (I personaly don't
    like it)


### Extra / interesting

- [btrfs-diff-gui](https://github.com/igelbox/btrfs-diff-gui)


### Duplicates with no improvement

The following project should have spent more time investigating what currently existed before
even starting, because, **to my comprehension**, they ended up having less value than the other
previously existing projects (less features, less quality, or both).
Like re-inventing the wheel, but [squared, without a catenary road](https://mathenchant.wordpress.com/2015/07/15/the-lessons-of-a-square-wheeled-trike/).

- [ehazlett/shadow (python)](https://github.com/ehazlett/shadow)
- [lenzenmi/btrsnap (python)](https://github.com/lenzenmi/btrsnap)
- [dcepelik/snap (go)](https://github.com/dcepelik/snap)
- [mmckeen/btrfs-backup (go)](https://github.com/mmckeen/btrfs-backup)
- [DeedleFake/yabs (go)](https://github.com/DeedleFake/yabs)
- [Nonpython/claw (python)](https://github.com/Nonpython/claw)
- [adferrand/rsbtbackup (python)](https://github.com/adferrand/rsbtbackup)
- [pyokagan/btrup](https://github.com/pyokagan/btrup)
- [sjuvonen/tessa](https://github.com/sjuvonen/tessa)
- [pj1031999/pjbackup](https://github.com/pj1031999/pjbackup)
- [fabianmenges/snapd](https://github.com/fabianmenges/snapd)
- [RobWouters/btrsnap.py](https://github.com/RobWouters/btrsnap.py)
- [avishorp/btrfs-snaprotate](https://github.com/avishorp/btrfs-snaprotate)
- [j-szulc/Btrfs-autosnap](https://github.com/j-szulc/Btrfs-autosnap)
- [johannes-mueller/saltoreto](https://github.com/johannes-mueller/saltoreto)
- [cycoe/btrfs-machine](https://github.com/cycoe/btrfs-machine)
- [ArnaudLevaufre/btrfs-simple-snapshots](https://github.com/ArnaudLevaufre/btrfs-simple-snapshots)
- [jf647/btrfs-snap](https://github.com/jf647/btrfs-snap)
- [nachoparker/btrfs-snp](https://github.com/nachoparker/btrfs-snp)
- [nachoparker/btrfs-sync](https://github.com/nachoparker/btrfs-sync)
- [moviuro/butter](https://github.com/moviuro/butter)
- [c0xc/btrfs-snapshot](https://github.com/c0xc/btrfs-snapshot)
- [dodo/btrtime](https://github.com/dodo/btrtime)
- [hunleyd/btrfs-auto-snapsho](https://github.com/hunleyd/btrfs-auto-snapshot)


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
