# btrfs-savepoints - Backup and Restore instantly with ease your BTRFS base filesystem

## A tutorial to quickly be up and running

Here I will guide you to your first experience in the world of user friendly and efficient system backups.

**Table of content**
<!-- toc -->

- [Get access to a BTRFS filesystem: three options](#get-access-to-a-btrfs-filesystem-three-options)
  - [1. Use a Virtual Machine with a BTRFS filesystem on `/`](#1-use-a-virtual-machine-with-a-btrfs-filesystem-on-)
  - [2. Use your disk partition formatted to BTRFS (`/` or another one)](#2-use-your-disk-partition-formatted-to-btrfs--or-another-one)
  - [3. Use an image file, mounted with a loopback](#3-use-an-image-file-mounted-with-a-loopback)
- [Install the _btrfs-savepoints_ programs](#install-the-btrfs-savepoints-programs)
- [First configuration : to backup the root filesystem](#first-configuration--to-backup-the-root-filesystem)
  - [Setup a backup BTRFS subvolume](#setup-a-backup-btrfs-subvolume)
  - [Setup the global configuration (telling where to backup)](#setup-the-global-configuration-telling-where-to-backup)
    - [About global configuration, local configuration, and savepoint configuration](#about-global-configuration-local-configuration-and-savepoint-configuration)
    - [Setup the global configuration file to delegate its role to the local configuration file](#setup-the-global-configuration-file-to-delegate-its-role-to-the-local-configuration-file)
    - [Setup a specific savepoint configuration for the root filesystem](#setup-a-specific-savepoint-configuration-for-the-root-filesystem)
  - [Your first backup](#your-first-backup)
  - [Updating the initrams fs](#updating-the-initrams-fs)
  - [Reboot and see the magic happening](#reboot-and-see-the-magic-happening)
- [Meet the restoration GUI](#meet-the-restoration-gui)
  - [If you don't want to mess with your root filesystem, create another one, it is quick](#if-you-dont-want-to-mess-with-your-root-filesystem-create-another-one-it-is-quick)
  - [Create your second backup](#create-your-second-backup)
  - [Your first restoration, with confidence and ease](#your-first-restoration-with-confidence-and-ease)
  - [Your first restoration at boot time](#your-first-restoration-at-boot-time)
- [About this document](#about-this-document)
  - [License: CC-BY-SA](#license-cc-by-sa)
  - [Author: Michael Bideau](#author-michael-bideau)
  - [Made with: Formiko and Vim, plus some helpers/linters](#made-with-formiko-and-vim-plus-some-helperslinters)

<!-- /toc -->


## Get access to a BTRFS filesystem: three options

You have three options to test this program onto a BTRFS filesystem.

In all case you will need the BTRFS binaries to run the commands in this tutorial.  
Ensure it is installed. For example, on a _Debian_ based system, run:

```sh
~> sudo apt install btrfs-progs
```

### 1. Use a Virtual Machine with a BTRFS filesystem on `/`

I highly recommend to run all the following inside a Virtual Machine (with a BTRFS filesystem on
`/`), to ensure you don't mess with your files (even if the risk is low). If you don't want to
provision a VM just for that, that's fine, it is possible to do without it.

### 2. Use your disk partition formatted to BTRFS (`/` or another one)

Your root filesystem might be a BTRFS one. If you aren't sure, run the following command and ensure
the ouptput is `btrfs`:

```sh
~> mount | grep ' on / ' | awk '{print $5}'
btrfs
```

### 3. Use an image file, mounted with a loopback

If you don't have any other filesystem that isn't a BTRFS one, you will need to create one and
mount it. In order to do this, use the following commands:

```sh
# create a big file (put it where you want, I have chosen to put it into /opt for this example)
~> truncate -s 1G /opt/btrfs.img

# format it to btrfs
~> sudo mkfs.btrfs -f /opt/btrfs.img

# mount it
~> [ -d /mnt/toplevel ] || sudo mkdir /mnt/toplevel
~> sudo mount -o loop /opt/btrfs.img /mnt/toplevel

# create a fake root filesystem subvolume
~> sudo btrfs subvolume create /mnt/toplevel/rootfs

# and put something in it
echo 'a content' | sudo tee /mnt/toplevel/rootfs/a_file >/dev/null
```

Note: In this case, some of the commands in the tutorial will require to be modified.

## Install the _btrfs-savepoints_ programs

And obviously, you need the _btrfs-savepoints_ programs to be installed.  
Follow the paragraph [Installation and first run](README.md#installation-and-first-run) in the
README file.


## First configuration : to backup the root filesystem

### Setup a backup BTRFS subvolume

First, you need to choose where you will keep your backups/savepoints (BTRFS snapshots).
It has to be on the same BTRFS top level subvolume as the source (the root filesystem for current
example).
So it cannot be on another partition for example.
I recommend to create another BTRFS subvolume named *backup* (or *savepoints*) at the root of the
top level subvolume, to get the following BTRFS hierarchy :

```text
/ (id: 5)
├── backup
├── rootfs
│   └── ...
├── homes
│   └── ...
├── var
│   └── ...
└── ...
```

For that, first mount the BTRFS top level hierarchy to `/mnt/toplevel` (if not already done above):

```sh
~> sudo mkdir -p /mnt/toplevel
~> sudo mount -t btrfs -o subvol=/ "$(mount | grep ' on / ' | awk '{print $1}')" /mnt/toplevel
```

Then create the backup BTRFS subvolume (you could also have named it `@backup` or whatever) :

```sh
~> sudo btrfs subvolume create /mnt/toplevel/backup
```

Then mount it to `/backup` :

```sh
~> sudo mkdir /backup
~> sudo mount -t btrfs -o subvol=/backup "$(mount | grep ' on / ' | awk '{print $1}')" /backup
```

Congrats, now you have a directory (BTRSF subvolume) to store your future backups/savepoints.

Before any backup can happen, we have to provide a way for *btrfs-sp* to know what to backup and
where.
Here comes the configuration files.


### Setup the global configuration (telling where to backup)

#### About global configuration, local configuration, and savepoint configuration

There are three configuration places to consider :

- the **global configuration file**, at `/etc/btrfs-sp/btrfs-sp.conf`, that stores default paths and
  values, but also where is the *local configuration file*, and where is the *savepoint
  configuration directory*

- the **local configuration file**, that I recommend placing in your backup directory, so at
  `/backup/btrfs-sp/btrfs-sp.local.conf` for example, that overrides the global values

- each **savepoint configuration file** in the **configuration directory**, I also recommend placing
  in your backup directory, so at `/backup/btrfs-sp/conf.d`, and for rootfs backup, it could be
  `/backup/btrfs-sp/conf.d/rootfs`


#### Setup the global configuration file to delegate its role to the local configuration file

To understand that heading, you have to put yourself in the shoes of someone that just restored
happily its entire root filesystem, including the `/etc` directory. Guess what, if that user had
put all its _btrfs-sp_ configuration in the global configuration `/etc/btrfs-sp/btrfs-sp.conf`, then
it just have been replaced with an older version, that might not be up-to-date.

So, in order to prevent side effect on *btrfs-sp* configuration when restoring, I recommend to use a
local configuration file in a BTRFS subvolume that will never be backuped/restored, meaning the one
containing the backups/savepoints (i.e.:  `/backup`), and then telling the global configuration
where is that local configuration file, and to put the "real" configuration inside this last one.

This is what you are offered to do here, in the next command lines.

Create a *btrfs-sp* folder inside the backup subvolume :

```sh
~> sudo mkdir -m 0770 /backup/btrfs-sp
```

Ensure there is a configuration directory :

```sh
~> sudo mkdir -m 0770 /etc/btrfs-sp
```

Copy the global configuration "delegate" example to `/etc/btrfs-sp/btrfs-sp.conf` :

```sh
~> sudo cp examples/deleguate-to-local.global.conf /etc/btrfs-sp/btrfs-sp.conf
```

Note that it just tells where is/will be the local configuration file.


Copy the local configuration example (assuming your are on a desktop) to
`/backup/btrfs-sp/btrfs-sp.local.conf` :

```sh
~> sudo cp examples/examples/desktop.global.conf /backup/btrfs-sp/btrfs-sp.local.conf
```

I am not going to explain every value in that file, but note the following two :

- **SP_DEFAULT_SAVEPOINTS_DIR_BASE** : tells where the backups are going to be stored (by default)
- **SP_DEFAULT_SAVEPOINTS_DIR_BASE_FROM_TOPLEVEL_SUBVOL** same as above, except that the path is
  relative to the BTRFS top level subvolume (id: 5). For example, it would be relative to
  `/mnt/toplevel` if you followed this example (and it will be the same as above in that case).

I recommends also manually adding those two :

- **ENSURE_FREE_SPACE_GB=1.0** : amount of Gigabyte to keep free (float)
- **NO_FREE_SPACE_ACTION=fail** : action to do when there is not enough free space left

Now we have setup all the defaults values.
But *btrfs-sp* still do not know that we want to backup the root filesystem (it could be */srv*, or
*/home*, or any BTRFS subvolume).

Here comes the time to add a specific savepoint configuration for the root filesystem.


#### Setup a specific savepoint configuration for the root filesystem

To backup a new folder (BTRFS subvolume), create a new configuration with the following command :

```sh
~> sudo btrfs-sp add-conf root / /root
```

The arguments are :

- **add-conf** tells *btrfs-sp* to create a new configuration
- **root** is the name of the configuration (it could have been *rootfs*, or any alphanumerical
  word)
- **/** is the path of the currently mounted subvolume that needs to be backuped
- **/root** is the same as above, but relative to the BTRFS top level subvolume (id: 5)

So here you just have to replace `/root` with the path of the root filesystem in the BTRFS
subvolume hierarchy relative to the top level subvolume (id: 5).
For example, if your BTRFS hierarchy looks like this :

```text
/ (id: 5)
├── @rootfs
│   ├── /bin
│   ├── /boot
│   └── ...
├── @homes
├── @var
└── ...
```

Specify `/@rootfs` instead of `/root`.

Check the result with :

```sh
~> sudo btrfs-sp ls-conf
```

Congrats, now you have a new configuration file for the root filesystem, and starting from now, you
can already make backups/savepoints.


### Your first backup

Try your first one with :

```sh
~> sudo btrfs-sp backup --config root --suffix '.my-very-first-one'
```

And check the result with :

```sh
~> sudo btrfs-sp ls --config root
```

Yeah, that's your first instant backup of your root filesystem with *btrfs-sp*. :thumbsup:


### Updating the initrams fs

_Note: if you are using the image file (option 3), skip that part._

Now that you have finished the setup don't forget to update the initramfs with :

```sh
~> sudo update-initramfs -u
```

This way, you will be able to have backups automatically created at boot time, and also to invoke
the restoration GUI, at startup screen (by pressing a key, 'R' by default).


### Reboot and see the magic happening

_Note: if you are using the image file (option 3), skip that part._

Now you can reboot your computer, and open your eyes to notice 3 things :

- **automatic instantaneous backups** before rebooting
- **possibility to enter the restoration GUI** by pressing a key (F6 in *console*, R in *plymouth*)
- **automatic instantaneous backups** at boot

Once you have booted and have a terminal, check that you have 2 new savepoints created with :

```sh
~> sudo btrfs-sp ls --config root
```

The 2 new savepoints should have the following suffixes :

- %datetime%**.reboot.safe**
- %datetime%**.boot**

The one at reboot time got the **.safe** suffix, because of the configuration variable
**SAFE_BACKUP** explained further below. Basically it means that the reboot backup is
considered safer than the boot one, and that will be an important flag for the pruning algorithm.

And if you go look at the real files/folders at `/backup/btrfs-sp/root` you will see that the *boot*
folder/subvolume is just a **symlink** to the *reboot* one. That has nothing to do with the suffix
**.safe** explainned above, but it is a consequence of the chronology/order of the backup.
Because the *boot* backup happened after the *reboot* one, and that **no changes have been made**
to the filesystem in between, the backup **pruning algorithm** have decided that the new one
(i.e.: *boot*) do not bring any value and should be replaced by a symlink to the previous one
(i.e. *reboot*) in order to **minimize the number of active BTRFS snapshots**, ensuring the system's
performances will not be cripled by a large number of BTRFS snapshots.
And thanks to the [COW](https://en.wikipedia.org/wiki/Copy-on-write) mechanism of the BTRFS
filesystem, the analysis of the differences between snapshot is almost instantaneous (up to a few
seconds).


## Meet the restoration GUI

Before going further, you should meet the restoration GUI and do your first restoration. Yes,
backups have to be tested !

### If you don't want to mess with your root filesystem, create another one, it is quick

_Note: if you are using the image file (option 3), skip that part._

If you are not confident to do this with your root filesystem (are you not running that first test
in a Virtual Machine ?), you should redo all the steps above with another subvolume less critical.

I will help you doing so, but in a quicker way, with the following commands :

```sh
~> sudo brtfs subvolume create /testsbuvol
~> sudo btrfs-sp add-conf test /testsbuvol /testsbuvol
~> sudo btrfs-sp backup --config test --suffix '.my-first-test'
```

Check that you have your first test savepoint

```sh
~> sudo btrfs-sp ls --config test
```

### Create your second backup

_Note: if you are using the image file (option 3), replace `/testsbuvol` by `/mnt/toplevel/rootfs`,
and the config is not `test` but `root`._

Now make a change in the test subvolume and take a second backup :

```sh
~> echo 'This is a test content' | sudo tee /testsbuvol/testfile.txt >/dev/null
~> sudo btrfs-sp backup --config test --suffix '.my-2nd-test'
```

Check that you have your second test savepoint

```sh
~> sudo btrfs-sp ls --config test
```

And produce another change in that test subvolume :

```sh
~> echo "I don't like that bad content" | sudo tee /testsbuvol/badfile.txt >/dev/null
```


Now you have backups and want to do a restoration.

First you should meet the restoration GUI without doing any restoration, while your system is
currently running, which is definitively not recommended (or even possible) with the root subvolume.

### Your first restoration, with confidence and ease

_Note: if you are using your root filesystem (option 2), skip that part, and jump to the
[restoration at boot](#your-first-restoration-at-boot-time)._

Say hello to the very basic GUI :

```sh
~> sudo btrfs-sp-restore-gui
```

You can confirm almost all steps except the one where your are presented that the subvolume is going
to be restored with the savepoint you previously selected.  
Take your time, and get used to the few GUI steps.

Then, when you are ready, select the *test* configuration, then select the 2nd backup, and confirm
the restoration.

Check the result with :

```sh
~> sudo btrfs-sp ls --config test
```

And you should see 2 new savepoints :

- %datetime%**.before-restoring-from-**%datetime%
- %datetime%**.after-restoration-is-equals-to-**%datetime%

The files should now have reverted to only `testfile.txt` and `badfile.txt` should have disappeared.

Congrats, you have done your very first instantaneous restoration of a complete BTRFS
filesystem/subvolume ! :tada:

How do you feel ? :muscle:

Now moving to a more realistic case ...


### Your first restoration at boot time

_Note: if you are using the image file (option 3), skip that part._

Now reboot again, and ensure that a savepoint is created at *reboot* time.
At startup time, look at the messages, and when your are asked if you want to enter the *btrfs-sp*
restauration GUI press the key ('*F6*' in console, '*R*' in plymouth).
Hopefully the GUI will show up and fits the screen size, and offer you the same experience as
before, even now it is running in an initram context (very limited).
This time try to restore the *test* subvolume to its first savepoint.
Before exiting the GUI, check that the restoration actually happened by checking that 2 new
savepoints have been created for the *test* configuration.
Now exit the GUI and finished to boot.

Have you seen how smooth and instantaneous that was ?
You can doubt it would be that fast with an entire filesystem like the root one, but I guaranty you
it will be, regardless of the number of files in that subvolume !

Now imagine doing the same with your root filesystem. That would be exactly as easy.  
Welcome to the user friendly paradigm :wink:

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
