# A Practical Guide to BitBake — 2026 Edition

A practical standalone BitBake tutorial updated and tested with:

* BitBake 2.18.0
* Python 3.14.4
* Ubuntu 26.04

The tutorial starts with the smallest possible BitBake project and introduces
recipes, tasks, classes, layers, `.bbappend` files, configuration includes, and
variables step by step. Advanced chapters cover source processing, host builds,
dependency graphs, signatures, providers, events, multiconfig, and metadata
selection. No Poky, OE-Core, cross-toolchain, package build, or image build is
required.

## Read the Tutorial

[Read the complete tutorial](A-Practical-Guide-to-BitBake-2026.md)

## Practical Examples

The chapter directories contain the completed project at each stage of the tutorial:

* `ch04` — Minimal BitBake project
* `ch05` — First recipe
* `ch06` — Classes and functions
* `ch07` — Multiple layers
* `ch08` — Class inheritance, append files, and includes
* `ch09` — Global and recipe-local variables
* [ch10](ch10) — Overrides, operators, and task flags ([chapter](docs/ch10.md))
* [ch11](ch11) — Task dependencies and ordering ([chapter](docs/ch11.md))
* [ch12](ch12) — Fetching and unpacking sources ([chapter](docs/ch12.md))
* [ch13](ch13) — Patching sources ([chapter](docs/ch13.md))
* [ch14](ch14) — Configuring, compiling, and installing ([chapter](docs/ch14.md))
* [ch15](ch15) — Task outputs and cross-recipe dependencies ([chapter](docs/ch15.md))
* [ch16](ch16) — Stamps, signatures, and incremental builds ([chapter](docs/ch16.md))
* [ch17](ch17) — Providers and selecting recipes ([chapter](docs/ch17.md))
* [ch18](ch18) — Events, hooks, and diagnostics ([chapter](docs/ch18.md))
* [ch19](ch19) — Multiple configurations ([chapter](docs/ch19.md))
* [ch20](ch20) — Advanced metadata and layer selection ([chapter](docs/ch20.md))

Each chapter contains its own `build` directory and the layers required for that
stage. The advanced snapshots are cumulative, so earlier targets remain
available. Chapter 21 is the summary; it needs no separate project snapshot.

If you type the early chapters into your own `bbTutorial` directory, use
the corresponding snapshot as an end-of-chapter checkpoint. The guide's
[comparison workflow](A-Practical-Guide-to-BitBake-2026.md#93-compare-your-project-with-the-completed-snapshot)
compares only layers and configuration, not generated outputs. Chapters
10-20 each begin with a change summary for students continuing their own project.

## Using the Examples

First install BitBake 2.18.0 as explained in the tutorial.

You can then enter a chapter’s build directory and run BitBake:

```bash
cd ch05/build
bitbake -s
bitbake first
```

Always run BitBake commands from the chapter’s `build` directory.

From Chapter 8 onward, this standalone project's local settings are in
`build/local.conf`, not Yocto/OE's usual `build/conf/local.conf`. Our explicit
`require local.conf` directive determines that location; see
[Section 8.3.1](A-Practical-Guide-to-BitBake-2026.md#831-add-a-localconf-for-inclusion).

The optional [bbenv.include](bbenv.include) helper, introduced in
[Chapter 3](A-Practical-Guide-to-BitBake-2026.md#31-the-installation-of-bitbake),
can configure the current terminal when BitBake is stored elsewhere.
Run this from the tutorial repository root, replacing the example path:

```bash
export BITBAKE_ROOT_DIR=/path/to/bitbake-2.18.0
source ./bbenv.include
```

Source the helper rather than executing it, and repeat the setup in each
new terminal. It configures search paths; you still need to enter the chosen
chapter's build directory.

## Host prerequisites and verification

Use BitBake 2.18.0 with a supported Python version and UTF-8 locale. The original
setup chapter explains the host/user-namespace requirements. The advanced
examples need Bash and ordinary Linux utilities; source patching needs `patch`,
and Chapter 14 needs a host C compiler, libc development headers and `make`.
On Ubuntu, `build-essential patch` supplies those build prerequisites.
The optional remote-archive exercise additionally needs `wget`, `tar`, `gzip`
and internet access.

After putting BitBake's `bin` directory on `PATH`, run from this repository root:

```bash
bash tests/check-all.sh             # all Chapters 10–20; no remote downloads
bash tests/check-all.sh 14 16       # selected chapters
bash tests/check-ch12.sh --network  # opt-in pinned archive and checksum tests
```

The checks verify exact artifacts, task edges, skip/rerun counts and expected
failure diagnostics, not just successful parsing. Deliberate failures and
forced-task warnings are part of the exercises. Test configuration changes are
temporary; build outputs, logs, downloads and caches stay inside the chapter's
ignored build directories. Do not run two checks for the same chapter
concurrently.

The completed [roadmap](ROADMAP-Advanced-Chapters.md) explains the scope and the
boundary between BitBake mechanisms and OpenEmbedded build policy.

## Acknowledgment

This edition follows the learning sequence of Harald Achitz’s original [A Practical Guide to BitBake](https://a4z.noexcept.dev/docs/BitBake/guide.html).

The examples and instructions were updated and validated for BitBake 2.18.0 and Python 3.14.4 by Adn Elkawas.
