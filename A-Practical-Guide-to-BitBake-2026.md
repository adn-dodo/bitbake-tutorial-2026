# A Practical Guide to BitBake

## Updated for BitBake 2.18 and Python 3.14

**Contents**

1.  [Preface](#1-preface)
2.  [BitBake](#2-bitbake)
3.  [Setup BitBake](#3-setup-bitbake)
4.  [Create a project](#4-create-a-project)
5.  [The first recipe](#5-the-first-recipe)
6.  [Classes and functions](#6-classes-and-functions)
7.  [BitBake layers](#7-bitbake-layers)
8.  [Share and reuse configurations](#8-share-and-reuse-configurations)
9.  [Using variables](#9-using-variables)
10. [Overrides, operators, and task flags](#10-overrides-operators-and-task-flags)
11. [Task dependencies and ordering](#11-task-dependencies-and-ordering)
12. [Fetching and unpacking sources](#12-fetching-and-unpacking-sources)
13. [Patching sources](#13-patching-sources)
14. [Configuring, compiling, and installing](#14-configuring-compiling-and-installing)
15. [Task outputs and cross-recipe dependencies](#15-task-outputs-and-cross-recipe-dependencies)
16. [Stamps, signatures, and incremental builds](#16-stamps-signatures-and-incremental-builds)
17. [Providers and selecting recipes](#17-providers-and-selecting-recipes)
18. [Events, hooks, and diagnostics](#18-events-hooks-and-diagnostics)
19. [Multiple configurations](#19-multiple-configurations)
20. [Advanced metadata and layer selection](#20-advanced-metadata-and-layer-selection)
21. [Summary](#21-summary)

## 1. Preface

### 1.1 About this tutorial

BitBake is used mainly by OpenEmbedded and the Yocto Project to build Linux distributions, and it has a fairly steep learning curve. This tutorial exists to flatten that curve.

It covers the major user-facing BitBake concepts through runnable standalone
examples, from the smallest project to signatures, providers, events and
multiconfig. It is not an exhaustive catalog of every variable, fetcher backend
or internal API; the versioned manual remains the reference for those details.

### 1.2 Target of this tutorial

The tutorial builds the smallest possible project and extends it step by step, to show and explain how BitBake actually works.

No Yocto or BitBake knowledge is assumed. You should be comfortable opening
a Linux terminal, changing directories with `cd`, editing a text file, and
reading command output. The examples introduce small shell and Python
functions as they are needed; you do not need to write a build system first.

The learning path is: print a message, reuse tasks, combine layers, process
source files, compile a tiny host program, then investigate dependencies and
rebuild decisions. The final result is a set of small standalone experiments,
not a Linux image to boot on a board.

### 1.3 Acknowledgments

The learning sequence is inspired by Harald Achitz’s original “A Practical Guide to BitBake.” Issues for this edition's accompanying example repository can be reported at the [repository issue tracker](https://github.com/RedaMaher/bitbake-tutorial-2026/issues).


## 2. BitBake

### 2.1 What is BitBake

BitBake is, at its core, a Python program: driven by configuration you write, it executes tasks you define for specified targets, called recipes.

### 2.1.1 Config, tasks and recipes

Configuration, tasks, and recipes are written in BitBake’s own small language — variables plus shell or Python code. Since BitBake actually executes that code, it could in theory be used for things other than building software, though that’s probably not a great idea.

BitBake was built for building software, so it has features suited to that: it can resolve dependencies and put tasks into the right order. Building software packages also tends to repeat the same kinds of steps — downloading and extracting source, running configure, running make, writing a log message — and BitBake gives you a way to abstract, encapsulate, and reuse that work in a configurable way.

### 2.2 Yocto, OpenEmbedded, Poky, and BitBake

These names refer to different parts of the ecosystem, not four interchangeable
build commands:

| Name | Role | Needed for this tutorial? |
|---|---|---|
| Yocto Project | The wider project providing tools, documentation, and practices for creating custom Linux systems. It is not one ready-made Linux distribution. | No checkout is needed; we use its BitBake manual. |
| OpenEmbedded (OE) | The community and build framework whose metadata describes how to build software and Linux systems. | No OE layers are used here. |
| OpenEmbedded-Core (OE-Core) | A shared core of recipes, classes, and configuration, including much of the toolchain, packaging, and image-building policy. | No; we write a few small teaching classes instead. |
| Poky | A reference integration associated with Yocto, combining BitBake, OE-Core, and reference distribution metadata. Many Yocto guides start from a Poky checkout. | No; do not follow a Poky setup step for this standalone guide. |
| BitBake | The engine that reads metadata, resolves dependencies, and schedules tasks. | Yes; Chapter 3 installs it by itself. |

Think of BitBake as the engine and metadata as its instructions. BitBake
does not infer "compile a program" from a recipe filename: a recipe or class
must define and connect the tasks. In a full OE build, existing classes supply
much of that behavior. Here we keep it visible by defining the tasks ourselves.

For example, `bitbake first` will select the recipe named `first` and request
its default task, `do_build`. Our first version of that task only prints a
message. Later, `bitbake hello-host` will follow a task chain to fetch, patch,
compile, and stage a tiny program. Neither target creates a Linux image.

### 2.3 A small glossary

Use this as a reference rather than a list to memorize. Each concept gets a
working example later.

| Term | Meaning here | First example |
|---|---|---|
| Metadata | The configuration, variable assignments, and task definitions that BitBake reads. | [Chapter 4](#4-create-a-project) |
| Recipe | A `.bb` file describing a buildable item, such as `first_0.1.bb`. | [Chapter 5](#5-the-first-recipe) |
| Target | The name requested on a command line, such as `first`; it usually selects a recipe, though aliases also exist. | [Chapter 5](#5-the-first-recipe) |
| Task | A registered unit of shell or Python work, such as `do_build`. A function is not automatically a scheduled task. | [Chapters 5-6](#5-the-first-recipe) |
| Class | A `.bbclass` file providing metadata that recipes can reuse with `inherit`. | [Chapter 6](#6-classes-and-functions) |
| Layer | A directory grouping related metadata, conventionally named `meta-...`. Layers are not sequential build stages. | [Chapter 7](#7-bitbake-layers) |
| Datastore | BitBake's collection of variables and flags for a particular configuration, recipe, or task; Python accesses it as `d`. | [Chapters 6 and 9](#6-classes-and-functions) |
| Dependency | A prerequisite relationship; the scheduler must complete the prerequisite before the dependent task. | [Chapter 11](docs/ch11.md) |
| Stamp | A record of successful task execution used to decide whether a task is current, not a copy of its output. | [Chapter 6](#65-why-a-requested-task-can-be-skipped) |
| Signature | A hash representing a task's code and tracked inputs, used by the configured signature policy to detect changes. | [Chapter 16](docs/ch16.md) |

## 3. Setup BitBake

BitBake is available at [github.com/openembedded/bitbake](https://github.com/openembedded/bitbake). This tutorial was tested with Python 3.14.4 and BitBake 2.18.0 on Ubuntu 26.04 — if you hit a problem with a different combination, please report it at the [repository issue tracker](https://github.com/RedaMaher/bitbake-tutorial-2026/issues). When BitBake is used inside a full Yocto/OpenEmbedded build it is normally bundled with the layers and started through the project’s own setup script; here we install the standalone `bitbake-2.18.0` release directly, so the engine underneath stays visible.

Download the tagged [2.18.0 release](https://github.com/openembedded/bitbake/archive/refs/tags/2.18.0.zip) and extract it.

### 3.1 The installation of BitBake

The installation is very simple:

- Add the extracted folder’s `bin` directory to `PATH`.
- Add its `lib` directory to `PYTHONPATH`.

We can do this by running:

    export PATH="/path/to/bitbake-2.18.0/bin:$PATH"
    export PYTHONPATH="/path/to/bitbake-2.18.0/lib:$PYTHONPATH"

These commands configure BitBake for the current terminal session. If you open a new terminal, you must run them again.

If you have this tutorial repository on disk, you can use its
[bbenv.include](bbenv.include) helper **instead of** the two exports above.
From the tutorial repository root, set the absolute path to your extracted
BitBake release and source the helper:

```bash
export BITBAKE_ROOT_DIR=/path/to/bitbake-2.18.0
source ./bbenv.include
```

Replace `/path/to/bitbake-2.18.0` with your real directory. The helper checks
for `bin` and `lib`, then adds them to `PATH` and `PYTHONPATH`. Source it in
the terminal where you will run the exercises; `bash bbenv.include` cannot
configure its parent shell. Without `BITBAKE_ROOT_DIR`, the helper looks for
a directory named `bitbake` next to itself. It does not download BitBake or
select a chapter's build directory.

First we check that everything works and BitBake is installed. To do that, run:

    bitbake --version

Expected output:

    BitBake Build Tool Core version 2.18.0

#### 3.1.1 Ubuntu permission check

On Ubuntu, check whether the user namespace operation required by modern BitBake is allowed:

    unshare --user --map-root-user true

If the command finishes silently, continue normally. If it reports “write failed /proc/self/uid_map: Operation not permitted”, Ubuntu’s AppArmor policy is blocking the operation. Only in that case, apply this temporary workaround:

    echo 0 | sudo tee /proc/sys/kernel/apparmor_restrict_unprivileged_userns

Then run the unshare check again. This command temporarily relaxes a system-wide Ubuntu security restriction until the next reboot; it is not a BitBake setting and should not be used on systems where the check already succeeds.

### 3.2 The BitBake documentation

From the extracted folder you can build the manual yourself with `make html DOC=bitbake-user-manual` (run from its `doc` directory), or read it online. Use the versioned [BitBake 2.18 User Manual](https://docs.yoctoproject.org/bitbake/2.18/) so it matches the version used here.

## 4. Create a project

### 4.1 BitBake project layout

We will create:

    bbTutorial/
    ├── build/
    │   └── conf/
    │       └── bblayers.conf
    └── meta-tutorial/
        ├── classes/
        │   └── base.bbclass
        └── conf/
            ├── bitbake.conf
            └── layer.conf

The `build` directory is where we run BitBake. `meta-tutorial` is a **layer** — a folder of related configuration, recipes, classes, and append files, conventionally prefixed `meta-`.

### 4.2 The smallest possible project

First create the directories:

    mkdir -p "$HOME/bbTutorial/build/conf"
    mkdir -p "$HOME/bbTutorial/meta-tutorial/classes"
    mkdir -p "$HOME/bbTutorial/meta-tutorial/conf"

#### 4.2.1 The required config files

First a description of the needed files, then a short description of their content.

**build/conf/bblayers.conf**

The first file BitBake expects is `conf/bblayers.conf` in its working directory, which is our build directory. For now we create it with this content:

    BBPATH := "${TOPDIR}"
    BBFILES ?= ""
    BBLAYERS = "${TOPDIR}/../meta-tutorial"

**meta-tutorial/conf/layer.conf**

Each layer needs a `conf/layer.conf` file. For now we create it with this content:

    BBPATH .= ":${LAYERDIR}"
    BBFILES += "${LAYERDIR}/recipes-*/*/*.bb"

**meta-tutorial/classes/base.bbclass and meta-tutorial/conf/bitbake.conf**

For now, these files can be taken from the BitBake installation directory. They’re located in the folders bitbake-2.18.0/classes and bitbake-2.18.0/conf. Simply copy them into the tutorial project.

#### 4.2.2 Some notes on the created files

**build/conf/bblayers.conf**

Add the current working directory to `BBPATH` by assigning it to `TOPDIR` — `TOPDIR` is set internally by BitBake to the current working directory. Initialize `BBFILES` as empty; recipes will be added later. Add the path of our `meta-tutorial` layer to `BBLAYERS` — when it runs, BitBake searches every listed layer directory for further configuration.

**meta-tutorial/conf/layer.conf**

`LAYERDIR` is a variable BitBake passes to the layer it loads; we append this path to `BBPATH`. `BBFILES` tells BitBake where recipes are — we append nothing yet, since we have none, but that changes later. `.=` and `+=` append a value to a variable, without or with a separating space.

**conf/bitbake.conf**

For now we take this file’s variables as they are.

**classes/base.bbclass**

A `.bbclass` file holds shared functionality. Our `base.bbclass` provides some logging functions we’ll use later, and a `build` task that does nothing — not very useful yet, but required, since `build` is the task BitBake runs by default when no other task is specified. We’ll change this task later.

#### 4.2.3 BitBake search path

Some file paths BitBake looks for are relative to `BBPATH`: if we tell BitBake to search for a path, it checks every directory listed in `BBPATH` (which, like `PATH`, can hold several directories separated by `:`).

We’ve added `TOPDIR` and `LAYERDIR` to `BBPATH`, so `classes/base.bbclass` and `conf/bitbake.conf` could live in either — but we put them in `meta-tutorial`. The build directory should never hold general files, only build-specific ones like a `local.conf`, which we’ll use later.

### 4.3 The first run

In a terminal, change into the build directory we just created — that’s our working directory. We always run BitBake from there, so it can find the relative `conf/bblayers.conf` file.

    cd "$HOME/bbTutorial/build"
    bitbake

If the setup is correct, BitBake reports:

    Nothing to do.  Use 'bitbake world' to build everything, or run 'bitbake --help' for usage information.

BitBake 2.18.0 returns exit status **1** for this no-target invocation.
Here the message confirms configuration was found; the nonzero status means
no work was requested, not that a build task failed. If you run these steps
in a script with `set -e`, handle this expected status rather than treating
it as a successful build.

Not very useful on its own, but a good start — and a good moment to introduce a useful flag, verbose debug output:

    bitbake -vDDD world

Representative lines from the output are:

    Loading cache...done.
    Loaded 0 entries from dependency cache.
    DEBUG: collating packages for "world"
    DEBUG: Target list: []
    NOTE: Resolving any missing task queue dependencies
    DEBUG: Resolved 0 extra dependencies

You’ll see a stream of NOTE: and DEBUG: lines. Progress formatting can differ
between an interactive terminal and redirected output. `-vDDD` enables very
detailed output, and `world` asks BitBake to build every eligible recipe.
Since the project has no recipes yet, there are no build tasks to run;
unlike the no-target invocation, this empty `world` request exits with
status 0. The useful part here is observing how BitBake parses the
configuration. We add the first recipe in the next chapter.

Notice that BitBake also created a `tmp` directory alongside `conf/`.

The completed [ch04 snapshot](ch04) is a reference for the project you just
created, not a second directory that BitBake needs to load. Continue editing
your own `bbTutorial` through Chapter 9. Each `chNN` snapshot shows the
expected metadata at the **end** of that chapter;
[Section 9.3](#93-compare-your-project-with-the-completed-snapshot) shows how
to compare the finished project without comparing generated build output.

## 5. The first recipe

BitBake needs recipes before it can do useful work. Check the current recipe list:


    bitbake -s

After the cache/parsing messages, BitBake 2.18.0 prints a table with four columns:

    Recipe Name          Latest Version        Preferred Version       Required Version
    ===========          ==============        =================       ================

The list is empty — we haven’t created a recipe yet.
The examples below abbreviate column spacing; compare names and values,
not the number of spaces.

### 5.1 The cache location

BitBake caches parsed metadata to make later commands faster. BitBake 2.18’s copied `bitbake.conf` already defines `CACHE`, so there is nothing to add here.

### 5.2 Adding a recipe location to the tutorial layer

BitBake finds recipes through `BBFILES`, which we already set in `meta-tutorial/conf/layer.conf`:

    BBFILES += "${LAYERDIR}/recipes-*/*/*.bb"

This means: look inside directories named `recipes-*`, then inside a recipe directory, and load files ending in `.bb`.

### 5.3 Create the first recipe and task

Recipe files follow the pattern `name_version.bb`. Create the directory:

    mkdir -p "$HOME/bbTutorial/meta-tutorial/recipes-tutorial/first"

Create `$HOME/bbTutorial/meta-tutorial/recipes-tutorial/first/first_0.1.bb`:




    DESCRIPTION = "I am the first recipe"
    PR = "r1"

    do_build () {
        echo "first: some shell script running as build"
    }

List the recipes and build `first`:

    cd "$HOME/bbTutorial/build"
    bitbake -s
    bitbake first

`bitbake -s` now shows:

    Recipe Name          Latest Version        Preferred Version       Required Version
    ===========          ==============        =================       ================
    first                       :0.1-r1

and the build summary should say every attempted task succeeded. The task log is at:

    build/tmp/work/first-0.1-r1/temp/log.do_build

and should contain:

    DEBUG: Executing shell function do_build
    first: some shell script running as build
    DEBUG: Shell function do_build finished

## 6. Classes and functions

### 6.1 Create the mybuild class

A `.bbclass` holds reusable metadata, so a task doesn’t have to be copied into every recipe that needs it. Create `$HOME/bbTutorial/meta-tutorial/classes/mybuild.bbclass`:

    addtask build

    mybuild_do_build () {
        echo "running mybuild_do_build."
    }

    EXPORT_FUNCTIONS do_build

`EXPORT_FUNCTIONS do_build` exposes `mybuild_do_build` as `do_build` to any recipe that inherits the class.

### 6.2 Use mybuild with the second recipe

    mkdir -p "$HOME/bbTutorial/meta-tutorial/recipes-tutorial/second"

Create `$HOME/bbTutorial/meta-tutorial/recipes-tutorial/second/second_1.0.bb`:


    DESCRIPTION = "I am the second recipe"
    PR = "r1"

    inherit mybuild

    def pyfunc(o):
        print(dir(o))

    python do_mypatch () {
        bb.note("running mypatch")
        pyfunc(d)
    }

    addtask mypatch before do_build

This recipe shows three kinds of reuse: `inherit mybuild` pulls in the class’s metadata, `do_mypatch` is a Python task, and `pyfunc` is a plain Python helper the task calls. `d` is BitBake’s datastore — the variables visible in the current metadata context.

### 6.3 Exploring recipes and tasks


    bitbake -s

should now show:

    Recipe Name          Latest Version        Preferred Version       Required Version
    ===========          ==============        =================       ================
    first                       :0.1-r1
    second                      :1.0-r1

List a recipe’s tasks with:

    bitbake -c listtasks second

### 6.4 Executing tasks or building the world

    bitbake second
    bitbake -c mypatch second
    bitbake world

`bitbake second` runs the default build task and its predecessors; `-c mypatch` requests `do_mypatch` explicitly; `bitbake world` builds every recipe visible to the configuration. Task logs live under `build/tmp/work/<recipe>-<version>-<revision>/temp/`.

### 6.5 Why a requested task can be skipped

After `bitbake second`, the explicit `-c mypatch` command normally reports
`1 didn't need to be rerun`. That is success, not a missing task: a **stamp**
under `build/tmp/stamps` records that the task completed, so BitBake considers
it current and reuses the result. The existing `log.do_mypatch` is still the
evidence of its last execution; a skipped task does not write a new log.

The copied base class marks `do_build[nostamp] = "1"`, so build itself runs
each time, while `do_mypatch` can stay current. A stamp is not a backup or
an output-existence check. Do not delete outputs and expect BitBake to notice.
For now, recognize the skip message; Chapter 11 introduces controlled reruns,
and [Chapter 16](docs/ch16.md) explains signatures and input changes. The
minimal configuration used here does not yet enable the hashing policy from
Chapter 10, so do not assume every metadata edit will invalidate a stamp.

## 7. BitBake layers

A typical BitBake project has more than one layer, each covering a specific topic, and different build targets can combine layers differently. Layers let you extend, configure, and even partially override content from another layer, which is what makes them reusable.

### 7.1 Adding an additional layer

Create its directory:

    mkdir -p "$HOME/bbTutorial/meta-two/conf"

Create `$HOME/bbTutorial/meta-two/conf/layer.conf`:

    BBPATH .= ":${LAYERDIR}"
    BBFILES += "${LAYERDIR}/recipes-*/*/*.bb"

Then add it to `$HOME/bbTutorial/build/conf/bblayers.conf`:

    BBPATH := "${TOPDIR}"
    BBFILES ?= ""
    BBLAYERS = " \
        ${TOPDIR}/../meta-tutorial \
        ${TOPDIR}/../meta-two \
    "

### 7.2 The bitbake-layers command

    bitbake-layers show-layers

At this exact stage, expect the table header but no layer rows. The
directories are already listed in `BBLAYERS`, but `show-layers` reports
registered **layer collections**, which we have not named yet. This is not
a missing-directory error. Section 7.3 adds those collection names; rerun
the command afterwards to see both rows. If you start from the completed
`ch07` snapshot, the names are already configured.

Other useful subcommands: `show-recipes`, `show-cross-depends`, `show-appends`, `flatten`, `show-overlayed`.

### 7.3 Extending the layer configuration

Add to `meta-tutorial/conf/layer.conf`:

    BBFILE_COLLECTIONS += "tutorial"
    BBFILE_PATTERN_tutorial = "^${LAYERDIR}/"
    BBFILE_PRIORITY_tutorial = "5"

Add to `meta-two/conf/layer.conf`:

    BBFILE_COLLECTIONS += "two"
    BBFILE_PATTERN_two = "^${LAYERDIR}/"
    BBFILE_PRIORITY_two = "5"
    LAYERVERSION_two = "1"

bitbake-layers show-layers should now list both layer collections with priority 5:

    layer       path                                            priority
    ===================================================================
    tutorial    /home/user/bbTutorial/build/../meta-tutorial      5
    two         /home/user/bbTutorial/build/../meta-two           5

Your absolute prefix and column spacing will differ. The `build/../`
component comes from our `${TOPDIR}/../meta-...` assignments: `..` means the
parent directory, so this is the same layer directory, not an extra copy.

At this stage, BitBake can also warn that no .bb files match BBFILE_PATTERN_two. That is expected because meta-two is still empty; Chapter 8 adds its first recipe.

### 7.4 Layer compatibility

At this point BitBake 2.18 will warn that these layers have no declared layer-series compatibility.

#### 7.4.1 Layer series core name

Add to `meta-tutorial/conf/layer.conf`:

    LAYERSERIES_CORENAMES = "bitbakeguide"

#### 7.4.2 Layer series compatibility

Also in `meta-tutorial/conf/layer.conf`:

    LAYERVERSION_tutorial = "1"
    LAYERSERIES_COMPAT_tutorial = "bitbakeguide"

Add to `meta-two/conf/layer.conf`:

    LAYERSERIES_COMPAT_two = "bitbakeguide"

The project-defined series name must match in LAYERSERIES_CORENAMES and each layer’s LAYERSERIES_COMPAT entry.

### 7.5 Layer dependencies

Add to `meta-two/conf/layer.conf`:

    LAYERDEPENDS_two = "tutorial"

This tells BitBake that `meta-two` requires the layer collection named `tutorial`.

## 8. Share and reuse configurations

Besides classes and configuration files, BitBake lets you reuse and extend metadata through class inheritance, `.bbappend` files, and include files. This chapter adds a class in `meta-two` that builds a configure-then-build chain on top of `mybuild`, then extends an existing recipe from another layer.

### 8.1 Class inheritance

    mkdir -p "$HOME/bbTutorial/meta-two/classes"

Create `$HOME/bbTutorial/meta-two/classes/confbuild.bbclass`:

    inherit mybuild

    confbuild_do_configure () {
        echo "running confbuild_do_configure."
    }

    addtask do_configure before do_build
    EXPORT_FUNCTIONS do_configure

Create the third recipe:

    mkdir -p "$HOME/bbTutorial/meta-two/recipes-base/third"

`$HOME/bbTutorial/meta-two/recipes-base/third/third_0.1.2.bb`:

    DESCRIPTION = "I am the third recipe"
    PR = "r1"

    inherit confbuild

In the terminal, build the recipe:

    cd "$HOME/bbTutorial/build"
    bitbake third

Both `do_configure` and `do_build` should succeed.

### 8.2 bbappend files

Replace the existing `BBFILES` assignment in `meta-two/conf/layer.conf` so it also picks up append files:

    BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
                ${LAYERDIR}/recipes-*/*/*.bbappend"

Keep this as one continued assignment, replacing the earlier `.bb`-only
assignment rather than adding a duplicate. The `.bb` pattern remains so
the layer's own recipes are still discovered; the new pattern also finds
the `.bbappend` files.

In the terminal, create the append file's directory:

    mkdir -p "$HOME/bbTutorial/meta-two/recipes-base/first"

Create `$HOME/bbTutorial/meta-two/recipes-base/first/first_0.1.bbappend`:

    python do_patch () {
        bb.note("first:do_patch")
    }

    addtask patch before do_build

Its filename matches `first_0.1.bb`, so BitBake merges this into that recipe — this is how one layer customizes a recipe owned by another without editing the original.


    bitbake-layers show-appends
    bitbake -c listtasks first
    bitbake first

### 8.3 Include files

Both directives search relative to `BBPATH`: `include file` parses it if present and continues if it’s absent; `require file` parses it and fails if it’s absent.

#### 8.3.1 Add a local.conf for inclusion

This standalone tutorial deliberately uses `build/local.conf`. A typical
Yocto/OE build uses `build/conf/local.conf` instead. The difference comes
from the include path in the project's metadata, not a rule that BitBake
automatically searches both locations:

| Project | Directive in its configuration | File found through the build directory in `BBPATH` |
|---|---|---|
| This tutorial | `require local.conf` | `build/local.conf` |
| Typical Yocto/OE layout | `include conf/local.conf` | `build/conf/local.conf` |

Keep the tutorial's location for these exercises. Moving the file under
`build/conf` without changing the directive below would leave the required
file missing. Later chapter snapshots follow the same tutorial convention.

Add to `meta-tutorial/conf/bitbake.conf`:

    require local.conf
    include conf/might_exist.conf

In the terminal, try building the recipe:

    cd "$HOME/bbTutorial/build"
    bitbake first

BitBake reports that the required `local.conf` is missing. Create an empty one:

    touch "$HOME/bbTutorial/build/local.conf"
    bitbake first

The missing, optional `conf/might_exist.conf` never causes an error.

## 9. Using variables

Variables are what make BitBake recipes and classes configurable instead of hard-coded: a class can define a task that reads a variable, and each recipe that inherits it supplies its own value instead of editing the class itself.

### 9.1 Global variables

#### 9.1.1 Define global variables

Add to `$HOME/bbTutorial/build/local.conf`:

    MYVAR = "hello from MYVAR"

BitBake 2.18 warns if there is no whitespace around `=`, so keep the spaces.

#### 9.1.2 Accessing global variables

    mkdir -p "$HOME/bbTutorial/meta-two/recipes-vars/myvar"

Create `$HOME/bbTutorial/meta-two/recipes-vars/myvar/myvar_0.1.bb`:

    DESCRIPTION = "Show access to global MYVAR"
    PR = "r1"

    do_build () {
        echo "myvar_sh: ${MYVAR}"
    }

    python do_myvar_py () {
        print("myvar_py:" + d.getVar('MYVAR'))
    }

    addtask myvar_py before do_build

Shell tasks expand a variable as `${MYVAR}`; Python tasks read it from the datastore with `d.getVar()`.

    cd "$HOME/bbTutorial/build"
    bitbake myvar

Each task writes its own log file under `build/tmp/work/myvar-0.1-r1/temp/`: `log.do_myvar_py` should contain

    myvar_py:hello from MYVAR

and `log.do_build` should contain

    myvar_sh: hello from MYVAR

#### 9.1.3 Inspect a variable before running a task

From the same build directory, ask BitBake for the recipe's parsed
environment and select the variable you want:

```bash
bitbake -e myvar | grep '^MYVAR='
```

Expect:

```text
MYVAR="hello from MYVAR"
```

`-e myvar` shows the datastore after configuration, classes, and recipe
metadata have been read; it does not execute the recipe's build tasks.
This is different from `echo "$MYVAR"` in your terminal, which reads a
shell variable rather than BitBake's datastore. The `^` in the `grep`
pattern matches the start of a line, so you select the final assignment
rather than every mention of the variable.

To investigate where a value came from, save the full dump:

```bash
bitbake -e myvar > myvar.env
```

Open `myvar.env` in your editor and find the final `MYVAR=` assignment.
The preceding comments show its assignment history and source locations.
Use this workflow whenever an unexpected value reaches a task. Do not
source the dump as a shell setup script; it is inspection output.
Remove it when finished:

```bash
rm myvar.env
```

### 9.2 Local variables

Create `$HOME/bbTutorial/meta-two/classes/varbuild.bbclass`:

    varbuild_do_build () {
        echo "build with args: ${BUILDARGS}"
    }

    addtask build
    EXPORT_FUNCTIONS do_build

The class knows the variable’s name but not its value.

    mkdir -p "$HOME/bbTutorial/meta-two/recipes-vars/varbuild"

Create `$HOME/bbTutorial/meta-two/recipes-vars/varbuild/varbuild_0.1.bb`:

    DESCRIPTION = "Demonstrate variable usage \
        for setting up a class task"
    PR = "r1"

    BUILDARGS = "my build arguments"

    inherit varbuild

In the terminal, build the recipe:

    cd "$HOME/bbTutorial/build"
    bitbake varbuild

Its log should contain:

    build with args: my build arguments

Inspect the input independently of that task log:

```bash
bitbake -e varbuild | grep '^BUILDARGS='
```

Expect `BUILDARGS="my build arguments"`. Here the assignment belongs to the
`varbuild` recipe; it does not set `BUILDARGS` for every recipe in the layer.
The `MYVAR` assignment in `local.conf`, by contrast, is available through
the shared configuration, though an individual recipe can override it.

### 9.3 Compare your project with the completed snapshot

You now have the same set of examples as [ch09](ch09). From the **tutorial
repository root**, not your project's build directory, compare the layers
and configuration:

```bash
diff -ru ch09/meta-tutorial "$HOME/bbTutorial/meta-tutorial"
diff -ru ch09/meta-two "$HOME/bbTutorial/meta-two"
diff -u ch09/build/conf/bblayers.conf "$HOME/bbTutorial/build/conf/bblayers.conf"
diff -u ch09/build/local.conf "$HOME/bbTutorial/build/local.conf"
```

If you chose another project location, substitute it for `$HOME/bbTutorial`.
`diff` is read-only: status 0 means identical, 1 means differences were found,
and a higher status indicates a comparison error such as a missing path.
With different files, `-` lines are from the snapshot and `+` lines are from
your project. Review differences rather than automatically replacing your work.
Harmless whitespace or assignment ordering can differ; focus on missing files,
values, task definitions, and include paths.

At earlier checkpoints, substitute that chapter's `chNN` path and compare
only the files and layers introduced so far: `meta-two` appears in Chapter 7
and `local.conf` in Chapter 8. Do not compare or copy the whole `build`
directory: it also holds machine-specific logs, caches, outputs, and stamps.

To try the completed example independently, enter `ch09/build` and run
`bitbake myvar varbuild`. Your own project's outputs remain separate.
From Chapter 10, the guide uses these completed snapshots for experiments
and starts each chapter with a list of changes. You may use that list to
continue extending your own project instead.

## 10. Overrides, operators, and task flags

[Continue with Chapter 10](docs/ch10.md): assignment timing, conditional
overrides, anonymous Python, and task directory/stamp flags. The runnable
snapshot is [ch10](ch10).

## 11. Task dependencies and ordering

[Continue with Chapter 11](docs/ch11.md): task registration, graph inspection,
and explicit dependencies across recipes. Snapshot: [ch11](ch11).

## 12. Fetching and unpacking sources

[Continue with Chapter 12](docs/ch12.md): explicit fetch/unpack tasks, local
sources, a checksum-pinned remote archive, and offline operation.
Snapshot: [ch12](ch12).

## 13. Patching sources

[Continue with Chapter 13](docs/ch13.md): an explicit patch task and
cross-layer file search. Snapshot: [ch13](ch13).

## 14. Configuring, compiling, and installing

[Continue with Chapter 14](docs/ch14.md): a host compiler, out-of-tree build,
and staged installation driven by a tutorial class. Snapshot: [ch14](ch14).

## 15. Task outputs and cross-recipe dependencies

[Continue with Chapter 15](docs/ch15.md): published artifacts and the
differences between direct, build-time and runtime task dependency flags.
Snapshot: [ch15](ch15).

## 16. Stamps, signatures, and incremental builds

[Continue with Chapter 16](docs/ch16.md): measured task reuse, file checksums,
explicit variable dependencies and signature comparisons. Snapshot: [ch16](ch16).

## 17. Providers and selecting recipes

[Continue with Chapter 17](docs/ch17.md): virtual targets, implementation and
version preferences, ambiguity and missing-provider diagnostics.
Snapshot: [ch17](ch17).

## 18. Events, hooks, and diagnostics

[Continue with Chapter 18](docs/ch18.md): event-handler contexts, task hooks,
logging, locks, explicit failures and recovery. Snapshot: [ch18](ch18).

## 19. Multiple configurations

[Continue with Chapter 19](docs/ch19.md): isolated configuration datastores
and a verified artifact dependency across configurations. Snapshot: [ch19](ch19).

## 20. Advanced metadata and layer selection

[Continue with Chapter 20](docs/ch20.md): deferred inheritance, custom recipe
variants, masking, optional layer appends and competing recipe priorities.
Snapshot: [ch20](ch20).

## 21. Summary

You now have a standalone project demonstrating the major stages of BitBake:

| Stage | Concepts and chapters |
|---|---|
| Discover metadata | Configuration, layers, recipes, classes, includes and appends (4–8); masking, priorities and dynamic appends (20) |
| Finalize recipes | Variables, assignment timing, overrides and anonymous Python (9–10); deferred inheritance and variants (20) |
| Select targets | Build/runtime providers and preferred versions (15, 17) |
| Construct the graph | Task registration, ordering, direct/dependency task flags and cross-configuration edges (11, 15, 19) |
| Execute work | Explicit fetch, unpack, patch, configure, compile and install tasks (12–14); hooks, locks, events and diagnostics (18) |
| Reuse work | Parse caches, stamps, file checksums, variable dependencies and signature comparisons (16) |

Chapters 10–20 have detailed text under [docs](docs), cumulative snapshots
under their respective `chNN` directories, and executable checks under
[tests](tests). The [README](README.md) explains prerequisites and how to run
all checks. The [reviewed roadmap](ROADMAP-Advanced-Chapters.md) records the
completed scope.

The engine supplies parsing, dependency resolution, scheduling, fetcher APIs
and signatures. Our small classes supply the source/build task chain and
artifact contracts. OE-Core normally adds much more: cross-toolchains,
sysroots, packaging, images and shared-state-cache policy. These examples
do not pretend to implement those systems.

To continue, change one input, predict its effect on the datastore or graph,
then inspect the output, task log and signature difference. Prefer this
evidence to deleting a build directory whenever something is surprising.
