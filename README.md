# Pwrake

Parallel workflow extension for Rake
* Author: Masahiro Tanaka

([README in Japanese](https://github.com/masa16/pwrake/wiki/Pwrake.ja)),
([GitHub Repository](https://github.com/masa16/pwrake))

## Features

* Parallelize all tasks; no need to modify Rakefile, no need to use `multitask`.
* Tasks are executed in the given number of worker threads.
* Remote exuecution using SSH.
* Pwrake is an extension to Rake, not patch to Rake: Rake and Pwrake coexist.
* High parallel I/O performance using Gfarm file system.

## Installation

Download source tgz/zip and expand, cd to subdirectory and install:

    $ ruby setup.rb

Or, gem install:

    $ gem install pwrake

## Usage

### Parallel execution using 4 cores at localhost:

    $ pwrake -j 4

### Parallel execution using all cores at localhost:

    $ pwrake -j

### Parallel execution using total 2*2 cores at remote 2 hosts:

1. Share your directory among remote hosts via distributed file system such as NFS, Gfarm.
2. Allow passphrase-less access via SSH in either way:
   * Add passphrase-less key generated by `ssh-keygen`.  (Be careful)
   * Add passphrase using `ssh-add`.
3. Make `hosts` file in which remote host names and the number of cores are listed:

        $ cat hosts
        host1 2
        host2 2

4. Run `pwrake` with an option `--hostfile` or `-F`:

        $ pwrake --hostfile=hosts

## Options

### Pwrake command line options (in addition to Rake option)

    -F, --hostfile FILE              [Pw] Read hostnames from FILE
    -j, --jobs [N]                   [Pw] Number of threads at localhost (default: # of processors)
    -L, --log, --log-dir [DIRECTORY] [Pw] Write log to DIRECTORY
        --ssh-opt, --ssh-option OPTION
                                     [Pw] Option passed to SSH
        --filesystem FILESYSTEM      [Pw] Specify FILESYSTEM (nfs|gfarm)
        --gfarm                      [Pw] FILESYSTEM=gfarm
    -A, --disable-affinity           [Pw] Turn OFF affinity (AFFINITY=off)
    -S, --disable-steal              [Pw] Turn OFF task steal
    -d, --debug                      [Pw] Output Debug messages
        --pwrake-conf [FILE]         [Pw] Pwrake configuation file in YAML
        --show-conf, --show-config   [Pw] Show Pwrake configuration options
        --report LOGDIR              [Pw] Report workflow statistics from LOGDIR to HTML and exit.
        --clear-gfarm2fs             [Pw] Clear gfarm2fs mountpoints left after failure.

### pwrake_conf.yaml

* If `pwrake_conf.yaml` exists at current directory, Pwrake reads options from it.
* Example (in YAML form):

        HOSTFILE: hosts
        LOG_DIR: true
        DISABLE_AFFINITY: true
        DISABLE_STEAL: true
        FAILED_TARGET: delete
        PASS_ENV :
         - ENV1
         - ENV2

* Option list:

        HOSTFILE, HOSTS   default(localhost)|hostname
        LOG_DIR, LOG      nil(default, No log output)|true(dirname="Pwrake%Y%m%d-%H%M%S")|dirname
        LOG_FILE          default="pwrake.log"
        TASK_CSV_FILE     default="task.csv"
        COMMAND_CSV_FILE  default="command.csv"
        GC_LOG_FILE       default="gc.log"
        WORK_DIR          default=$PWD
        FILESYSTEM        default(autodetect)|gfarm
        SSH_OPTION        SSH option
        SHELL_COMMAND     default=$SHELL
        SHELL_RC          Run-Command when shell starts
        PASS_ENV          (Array) Environment variables passed to SSH
        HEARTBEAT         Hearbeat interval in seconds (defulat=240)
        FAILED_TARGET     rename(default)|delete|leave - Treatment of failed target files
        FAILURE_TERMINATION wait(default)|kill|continue - Behavior of other tasks when a task is failed
        QUEUE_PRIORITY          LIHR(default)|FIFO|LIFO|RANK
        NOACTION_QUEUE_PRIORITY FIFO(default)|LIFO|RAND
        SHELL_START_INTERVAL    default=0.012 (sec)
        GRAPH_PARTITION         false(default)|true

* Options for Gfarm system:

        DISABLE_AFFINITY    default=false
        DISABLE_STEAL       default=false
        GFARM_BASEDIR       default="/tmp"
        GFARM_PREFIX        default="pwrake_$USER"
        GFARM_SUBDIR        default='/'
        MAX_GFWHERE_WORKER  default=8
        GFARM2FS_OPTION     default=""
        GFARM2FS_DEBUG      default=false
        GFARM2FS_DEBUG_WAIT default=1

## Note for Gfarm

* `gfwhere-pipe` script (included in Pwrake) is used for file-affinity scheduling.
  This script requires Ruby/FFI (https://github.com/ffi/ffi). Install FFI by

        gem install ffi

## For Graph Partitioning

* Compile and Install METIS 5.1.0 (http://www.cs.umn.edu/~metis/). This requires CMake.

* Install RbMetis (https://github.com/masa16/rbmetis) by

        gem install rbmetis -- \
         --with-metis-include=/usr/local/include \
         --with-metis-lib=/usr/local/lib

## Tested Platform

* Ruby 2.2.2
* Rake 10.4.2
* CentOS 6.7

## Acknowledgment

This work is supported by
* JST CREST, research area: "Development of System Software Technologies for Post-Peta Scale High Performance Computing," and
* MEXT Promotion of Research for Next Generation IT Infrastructure "Resources Linkage for e-Science (RENKEI)."
