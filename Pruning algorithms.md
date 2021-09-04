# btrfs-savepoints - Backup and Restore instantly with ease your BTRFS base filesystem

## Retention strategies and pruning algorithms

There are two main pruning algorithms available and both can be combined.

**Table of content**
<!-- toc -->

- [Pruning by differences: replace duplicates by a symlink](#pruning-by-differences-replace-duplicates-by-a-symlink)
- [Pruning with a retention strategy based on numbers of savepoints plus prioritizing safer ones](#pruning-with-a-retention-strategy-based-on-numbers-of-savepoints-plus-prioritizing-safer-ones)
  - [Retention strategy](#retention-strategy)
  - [Priorization of the safest backups/savepoints](#priorization-of-the-safest-backupssavepoints)
- [About this document](#about-this-document)
  - [License: CC-BY-SA](#license-cc-by-sa)
  - [Author: Michael Bideau](#author-michael-bideau)
  - [Made with: Formiko and Vim, plus some helpers/linters](#made-with-formiko-and-vim-plus-some-helperslinters)

<!-- /toc -->

## Pruning by differences: replace duplicates by a symlink

The first algorithm, compares the newly created savepoint with the previous one.
If no differences are found, the new one is deleted and replaced with a symlink to the previous one.

This way you can trigger the backuping as much as you want, the number of snapshot isn't going to
grow, if there is no files changes.

Very fast and efficient technique.

Note that there are two ways of comparing the snapshots :

- one is with the *btrfs send/receive*, which it the quickest but not the smartest (only ignoring
  the differences of times and properties changed), and

- another one is with an external tool of your choice
  (i.e.: [btrfs-diff-sh](https://github.com/mbideau/btrfs-diff-sh))
  that is able to filter differences in a more specific way, with what is specified in the
  configuration variable **DIFF_IGNORE_PATTERNS**.

The behaviour is the following: if that variable is not empty and there is an external utility
defined (either **btrfs-diff** exists in the *PATH*, or the variable **BTRFS_DIFF_BIN** is set to an
executable binary) then the later is used, else the raw *btrfs send/receive* is used.


## Pruning with a retention strategy based on numbers of savepoints plus prioritizing safer ones

The second one is way more complex and it takes a little time to understand the way it works.
I'll do my best to explain it.


### Retention strategy

First, it looks like a basic retention scheme of X number of backup of each type retained, and it is
exactly that in a way.
The tricky part is that the X do not represent an absolute amount, but more a relative amount.

This case is easier to explain with an example.

Consider a month of activity, with some days without activity :

```text
# happy new year
2021-01-01
2021-01-02
# Sunday no computer
2021-01-04
# holidays skying (in Europe) with no computer
# back home
2021-01-17
2021-01-18
2021-01-19
2021-01-20
2021-01-21
# do not work on Friday
# then do construction in your apartment
2021-01-25
2021-01-26
2021-01-27
2021-01-28
# no work on Friday
```

Now consider the following basic retention strategy : keep 5 days, keep 4 weeks.

The savepoints kept with a typical algorithm would be :

- 5 days : 2021-01-01, 2021-01-02, 2021-01-04
- 4 weeks: (2021-01-04 again), 2021-01-21, 2021-01-28

It thinks in this way : I keep all daily backup in the last 5 days (absolute timing), and one
backup for each of the last 4 weeks (absolute timing again).

But our algorithm do its accounting totally differently (though it is not spectacular here):

- 5 days : 2021-01-01, 2021-01-02, 2021-01-04, **2021-01-17, 2021-01-18**
- 4 weeks: 2021-01-21, 2021-01-28

It thinks in this way: I keep all daily backup until I got 5 (the limit), regardless of their date,
then one for each of last 4 weeks after the last daily backup (relative accounting).

In other words : it keeps accounting for the lowest unit of time (i.e.: days) until it has reached
its limit (i.e.: 5), then it starts accounting for the upper one (i.e.: weeks), and so on.


Now a more obvious example of absolute accounting and relative accounting (may be there is a name
for it, if so please tell me).

Imagine you let your old computer abandoned in a corner for one year, (that's bad, sell it or give
it to someone that actually needs it), and one day you decide to boot it up again, and do a new
backup/savepoint.

The traditional absolute accounting will delete every older existing snapshots, because none match
the retention strategy of 5 days, 4 weeks, 6 months.  
With the relative accounting, the today's new backup will count for one daily backup, then the
previous one 1 year ago will account for the second daily backup, and up until 5 daily backups, then
it will starts counting for weeks, and so on. At the end, our relative algorithm will almost retain
all the previously existing backups/savepoints.

That's not the best algorithm out there, but that's one that is simple enough to be predictable and
gives good enough results.  
For more advanced technique, if that's offering a real advantage I would consider them.  
PS: I have thought about using an exponential distance that would have almost the same effect than
the one implemented, but that's less predictable (at least for my brain), and is more complex to
prioritize safer backups.


### Priorization of the safest backups/savepoints

When the pruning algorithm needs to keep only one backup for a unit of time, for example keep one
backup for yesterday even if there are one for each our, it always choose the oldest one... but
not only : it will choose the oldest **safest** one, or if no safe backup, the _unsafe_ oldest one.

Wait what is a _safe backup_ ?
> It is just a backup with the **.safe** suffix. Yes, that simple.  
  It allows for a very useful and pragmatical feature that I have seen nowhere else.

What backups/savepoints should be considered safe (and so having the **.safe** suffix) ?  
> Any backups/savepoints that happened when the filesystem is/was unmounted properly before.  
  So at reboot time, or shutdown time, mostly.  
  Boot time is only safe if the computer was properly rebooted/shutdown before, but that's hard to
  tell so I recommend avoiding it.  

What is the use of the safe VS unsafe backups ?  
> Because safe backups guaranty you that the filesystem was clean (filesystem remounted read-only)
and no service where running, you can assume it was in a coherent state, and you can restore it with
strong confidence that you will recover a fully functioning system.  

> With unsafe backup (taken when system was online and filesystem mounted read-write), you have no
guaranty that the backup was not taken in the middle of an operation. If the service concerned by
that half backuped operation do not handle transactional operations and a way to prunes ones that
are not committed, if you restore your system with that unsafe backup, that service might not work
anymore, or produce unpredictable results. So you might end up with a malfunctioning system.


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
