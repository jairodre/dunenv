# dunenv: start the DUNE software on a Fermilab gpvm with one command

`dunenv` opens the SL7 container on a DUNE gpvm (`dunegpvm01`...`15`) and sets up the
DUNE software inside it: `dunesw` (LArSoft + DUNE code), any extra UPS products you
need, optionally your own compiled code (an MRB area), and your grid access (token,
JUSTIN, Rucio). Everything you may want to change is in one file, `dunenv.ini`, and
short commands edit it for you.

**Contents**
1. [Why a container?](#1-why-a-container)
2. [Before you start](#2-before-you-start)
3. [Install](#3-install)
4. [Your first session](#4-your-first-session)
5. [Choosing a dunesw version](#5-choosing-a-dunesw-version)
6. [Everyday commands](#6-everyday-commands)
7. [Extra UPS products](#7-extra-ups-products)
8. [Your own compiled code (MRB areas)](#8-your-own-compiled-code-mrb-areas)
9. [The config file](#9-the-config-file)
10. [What setup does, step by step](#10-what-setup-does-step-by-step)
11. [Troubleshooting](#11-troubleshooting)
12. [Files](#12-files)

---

## 1. Why a container?

The gpvms run AlmaLinux 9 (EL9), but the DUNE software releases distributed through
UPS (`setup dunesw ...`) are built for Scientific Linux 7 (SL7). Fermilab provides an SL7
container image, run with Apptainer, so the SL7 software works on the EL9 machine. Your
home, `/exp/dune/app`, `/exp/dune/data`, `/pnfs/dune` and `/cvmfs` are all visible
inside it.

You can tell which one you are in from the prompt:

```
[you@dunegpvm01:AL9 ~]$          <- the gpvm itself (EL9): no DUNE software here
[you@dunegpvm01:SL7 ~]$          <- inside the SL7 container: DUNE software works here
```

(The `AL9` / `SL7` tag is shown in green once dunenv is installed.)

The environment lives only in that container shell. Type `exit` to leave. A new
terminal starts from the gpvm again, so run `dunenv start` once per terminal.

## 2. Before you start

You need:

* A Fermilab computing account with DUNE membership, so you can log in to the gpvms.
* A Kerberos ticket and an ssh login. From your laptop:
  ```bash
  kinit <username>@FNAL.GOV
  ssh <username>@dunegpvm01.fnal.gov
  ```
* Somewhere to work: `/exp/dune/app/users/<username>` for code,
  `/exp/dune/data/users/<username>` for files. Keep your home (`/nashome`) small; it has
  a low quota.

## 3. Install

You do this once, logged in to a gpvm.

1. Put the `dunenv` folder in your home, e.g. `~/dunenv`, with at least `dunenv` and
   `dunenv.sh` inside. `dunenv.ini` is created automatically the first time you run it.
2. Make the program executable:
   ```bash
   chmod +x ~/dunenv/dunenv
   ```
3. Make the `dunenv` command available in every new terminal. This adds one line to
   your `~/.bash_profile` (do it **once**; running it again adds the line twice):
   ```bash
   echo 'source ~/dunenv/dunenv.sh' >> ~/.bash_profile
   source ~/.bash_profile        # load it into the terminal you have open now
   ```
   To undo this later, delete that line from `~/.bash_profile`.
4. Look at the settings:
   ```bash
   dunenv list
   ```
   The file ships with one example local environment, `pana`, which is the author's own
   compiled code. You don't need it, so remove it with `dunenv rm pana`. That only
   removes the entry from `dunenv.ini`; no files are deleted.

## 4. Your first session

**Just dunesw, nothing else.** Use any released version (see [section 5](#5-choosing-a-dunesw-version)):

```bash
dunenv start -v v10_17_01d00 -q e26:prof
```

What you will see:

1. `=== Entering FNAL SL7 container ===`, then the prompt changes.
2. `Setting up dunesw ...`, which can take a minute or more the first time while `/cvmfs` caches files.
3. The UPS products `metacat`, `rucio` and `justin`.
4. **Token (htgettoken).** The first time, it prints a URL. Open it in a browser and log in
   with your Fermilab identity. Later runs reuse the stored token and skip this step.
5. **JUSTIN.** The first time on a machine, `justin time` prints a URL to authorize the
   computer. The setup stops there and says so. Open the URL, approve, then in the
   **same** shell run:
   ```bash
   dunenv justin
   ```
6. `dunenv ready: env=none  dunesw v10_17_01d00 -q e26:prof`, then you are moved to `/exp/dune/app/users/<you>`.

Check that it worked:

```bash
dunenv status          # container, dunesw version, local env, Rucio account
which lar              # should print a path under /cvmfs/larsoft.opensciencegrid.org
lar --version
```

**Don't need grid access today?** Skip steps 4–5 with `--no-grid`:

```bash
dunenv start -v v10_17_01d00 -q e26:prof --no-grid
```

**Make it your default**, so a plain `dunenv start` does the same:

```bash
dunenv set version v10_17_01d00
dunenv set qualifier e26:prof
dunenv start
```

**Not sure?** Run `dunenv` alone for a menu. When you're done, it prints the short command
that repeats your choices next time. Add `-n` to any `start` to see what would run without
running it.

## 5. Choosing a dunesw version

A UPS product is selected by **version** and **qualifier**:

* Version: `vMM_mm_pp` plus an optional suffix, e.g. `v10_17_01d00`. Use the one your
  analysis, production or tutorial asks for.
* Qualifier: compiler plus build type. `e26` is the compiler set; `prof` is the optimized
  build you normally use; `debug` has debug symbols. Most current releases use `e26:prof`.

To list the versions that exist, open a bare container, load UPS, and ask it:

```bash
dunenv shell
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
ups list -aK+ dunesw | tail -20       # version + qualifiers, newest at the end
exit
```

These UPS commands work in any container shell where UPS is loaded (after
`setup_dune.sh`, or after any `dunenv start` / `dunenv setup`).

### What a release contains: `ups depend`

`ups depend` prints the full dependency tree of a release: every package it pulls in, with
the exact version and qualifier.

```bash
# the whole tree of one release
ups depend dunesw v10_26_00d05 -q e26:prof

# only some packages, with the version this release uses
ups depend dunesw v10_26_00d05 -q e26:prof | grep -E "dunereco|protoduneana"

# which top-level package brings a package in (here: dunereco, via duneana)
ups depend dunesw v10_26_00d05 -q e26:prof | awk '/^\|__/{p=$1} /__dunereco /{print p "  ->  " $0}'
```

In the tree, `|__name` is directly under dunesw and `|  |__name` is one level deeper.
Use this to find the version to check out with `mrb g -t`, or to write in a `product_deps` file.

### Versions of one package

```bash
ups list -aK+ dunereco | grep v10_26          # every installed dunereco v10_26*, with qualifiers
ups list -aK+ dunereco v10_26_00d05           # is this exact version installed?
```

### What a package needs to *build* (MRB areas)

`ups depend` shows what a package *declares* in its `ups/product_deps`. What it really
needs at build time is in its CMake file:

```bash
grep -n "find_package" /path/to/area/srcs/protoduneana/CMakeLists.txt
```

Use the full path when no local environment is set up (`$MRB_SOURCE` is then empty).
A package that appears in `find_package` but not in `ups depend` is a missing
declaration. If you also check that package out in the same MRB area, the build fails
(see [section 8](#8-your-own-compiled-code-mrb-areas)).

If you ask for a version or qualifier that doesn't exist, setup stops with
`setup dunesw failed` and leaves you in the container shell, so you can try again with
`dunenv setup -v ... -q ...`.

## 6. Everyday commands

On the gpvm:

```bash
dunenv                          # menu: environment, normal/build container, grid yes/no
dunenv start                    # default version + packages + token/JUSTIN/Rucio
dunenv start -v VER -q QUAL     # a specific dunesw
dunenv start NAME               # + your local build NAME (section 8)
dunenv start NAME build         # same, in the build container
dunenv NAME build               # short form: a known name or "build" implies start
dunenv shell [build]            # container only, nothing set up
dunenv list [-v]                # defaults, packages, your local builds
dunenv rebuild NAME [--clean]   # recompile your local build NAME (build machines only, section 8.3)
dunenv rebuild NAME -p PKG      # add package PKG to it, then recompile from scratch
```

Inside the container:

```bash
dunenv setup [NAME] [options]   # set up this shell (e.g. after "dunenv shell")
dunenv justin                   # finish token/JUSTIN/Rucio after the browser step
dunenv status [-v]              # what is set up (-v: every active UPS product)
exit                            # leave the container
```

The **build container** is the same image without `/pnfs/dune` mounted. Use it for compiling.

Options for `start` and `setup`:

| Option | Meaning |
|---|---|
| `-v VERSION -q QUAL` | dunesw version and qualifier (for a local build: only picks between its builds) |
| `-p "name ver -q qual"` | extra UPS product, this run only (repeatable) |
| `--no-grid` / `--grid` | skip / force the token + JUSTIN + Rucio step |
| `--dev` | also run `mrbsetenv`, needed before compiling with `mrb i` |
| `-n`, `--dry-run` | show the plan and the generated script; run nothing |

## 7. Extra UPS products

Anything you would set up with `setup <name> <version> -q <qual>` can be added, written
exactly as you would type it after `setup`. A name alone sets up the current version.
`{version}` and `{qualifier}` are replaced by the active dunesw ones.

```bash
dunenv start -p "duneprototypes {version} -q {qualifier}"     # this run only
dunenv pkg add ifdhc                                          # every setup
dunenv pkg add "duneprototypes {version} -q {qualifier}"      # every setup, matching dunesw
dunenv pkg add ifdhc --env NAME                               # only with local build NAME
dunenv pkg rm ifdhc [--env NAME]
dunenv pkg list [--env NAME]
```

Typing `setup <name> ...` by hand in the container also still works. Use the config for
products you need every time, and the terminal for one-off tests.

Keep `rucio` and `justin` in the default list, because the grid step uses them. If you
don't want grid access at all, turn it off: `dunenv set grid no`.

## 8. Your own compiled code (MRB areas)

When you develop LArSoft/DUNE code, you build it in an **MRB area**: a folder that holds
`srcs/` (your checked-out code), `build_slf7.x86_64/` (where it compiles) and
`localProducts_<project>_<version>_<qual>/` (where the result is installed).

The steps, in the order you'll need them:

1. **Create** the area for a release: `dunenv new` (8.1).
2. **Find and register** an area you already have, so dunenv knows it by a short name (8.2).
3. **Start** it to run your code, or to recompile after editing (8.3).
4. **Manage** registered areas: default, remove, extra settings (8.4).

### 8.1 Create a new MRB area: `dunenv new`

`dunenv new` runs the usual MRB recipe for you in a folder **you** create. It
never creates the folder itself.

```bash
ssh <you>@dunebuild02.fnal.gov                       # the build runs only on a build machine
mkdir /exp/dune/app/users/$USER/protoDUNE/dev_v10_26_00d05
cd    /exp/dune/app/users/$USER/protoDUNE/dev_v10_26_00d05
dunenv new pana26 . --project protoduneana -v v10_26_00d05 -q e26:prof -p protoduneana -p duneprototypes -n   # look first
dunenv new pana26 . --project protoduneana -v v10_26_00d05 -q e26:prof -p protoduneana -p duneprototypes      # then run
dunenv pana26                                        # use it
```

It opens the build container, runs these steps, and closes the container at the end:

| Step | What | Stops when |
|---|---|---|
| 1 | `setup dunesw <ver> -q <qual>` | the release isn't in UPS (and lists the close ones) |
| 2 | check the `<ver>` tag on GitHub for every package | a tag is missing. Nothing has been created yet |
| 3 | `export MRB_PROJECT=<project>`, `mrb newDev -v <ver> -q <qual>`, `source localProducts_<project>_<ver>_<qual>/setup` | `mrb newDev` fails |
| 4 | `cd srcs`, then `mrb g -t <ver> <pkg>` for each package, in order (default: only `protoduneana`; add more with `-p` or in `[newdev]`) | a checkout fails |
| 5 | check that this is a build machine (`dunebuild*.fnal.gov`) | it isn't |
| 6 | `cd $MRB_BUILDDIR`, `mrb z`, `mrbsetenv`, `mrb i -j 20`, `mrbslp` | the build fails |
| 7 | register the area as `[env:pana26]` | - |

Before anything starts, it also checks on the host:
* the folder exists, and is empty or a half-finished area of the *same* project/release;
* the machine is a build machine.

The build-machine check runs again inside the container right before `mrb i`. On a
dunegpvm the build is always refused; there is no flag to force it.

Every finished step is skipped on the next run, so after a failure you fix the cause and
run the **same command** again. The whole output is also saved in
`<folder>/dunenv_new_<date>_<time>.log`.

| Option | Meaning |
|---|---|
| `-v VER` | release (required) |
| `-q QUAL` | qualifier (default: `[defaults] qualifier`) |
| `--project P` | `MRB_PROJECT` name (default: `[newdev] project`) |
| `-p PKG` | a code package to download into `srcs/` (`mrb g -t <ver> PKG`) and compile. Give one `-p` per package (`-p protoduneana -p duneprototypes`). When used, these replace the `[newdev] packages` list for this run |
| `-j N` | build jobs (default: `[newdev] jobs`) |
| `--no-build` | stop after `mrb g`, e.g. to copy your own modules into `srcs/` first. Allowed on a gpvm |
| `--build-only` | only steps 1, 5, 6 (and 7) for an area prepared with `--no-build` |
| `-n` | print the checks and the full script; run nothing |

#### `--project` and `-p` are not the same thing

In the examples here both say `protoduneana`, only because the area was named after the
package it builds. They are two separate settings:

* `--project` is only a **name for the whole area**. It becomes `MRB_PROJECT` and the
  folder name `localProducts_<project>_<ver>_<qual>`. It doesn't check out or build anything.
* `-p` names a **package**: a code repository that is checked out into `srcs/` with
  `mrb g -t <ver> <package>` and compiled. Repeat it to check out several.

So in

```bash
dunenv new nbana . --project protoduneana -v v10_26_00d05 -q e26:prof -p protoduneana
```

the first `protoduneana` names the area and the second one checks out the protoduneana code.
This is the same as leaving `-p` out, because `protoduneana` is the default package list.
With more packages:

```bash
# area named "protoduneana", with protoduneana + duneprototypes checked out
dunenv new nbana . --project protoduneana -v v10_26_00d05 -q e26:prof -p protoduneana -p duneprototypes
```

#### Which packages can go after `-p`

`dunenv` checks every `-p` package for the tag
`<ver>` on `https://github.com/DUNE/<package>.git` before it creates anything
(`[newdev] repo_url`). So `-p` works for DUNE repositories (`dune*`, `protoduneana`)
that are tagged with the *same version as dunesw*. To list them, ask `ups depend` for
the packages whose version is exactly that release:

```bash
# packages of this release with version v10_26_00d05 = candidates for -p
ups depend dunesw v10_26_00d05 -q e26:prof | grep -oE "__[a-z_0-9]+ v10_26_00d05" | sed 's/^__//' | sort -u

# confirm one candidate has the tag on GitHub (prints a line if it does)
git ls-remote --tags https://github.com/DUNE/dunereco.git refs/tags/v10_26_00d05
```

LArSoft packages (`larreco`, `larsim`, ...) have their own versions (e.g. `v10_17_01`)
and live under `github.com/LArSoft`, so they fail this check. Check those out by hand
with `mrb g -t <their version> <package>` in `srcs/`, after `--no-build`.

Check out only the packages you'll edit. A package that another checked-out package
needs but doesn't declare can break the build (see *Check out only what you change* below).

Two-step version, to add your own modules before compiling:

```bash
dunenv new pana26 . --project protoduneana -v v10_26_00d05 -q e26:prof --no-build
#   ... copy / cherry-pick your modules into srcs/protoduneana ...
dunenv new pana26 . --project protoduneana -v v10_26_00d05 -q e26:prof --build-only
```

`--build-only` is meant for this first build of an area prepared with `--no-build`. Once
an area is built and registered, recompile it with `dunenv rebuild` (8.3): no project,
version or folder to remember.

Defaults are in the `[newdev]` section of `dunenv.ini`: `project`, `packages`, `jobs`,
`build_hosts`, `repo_url`.

**Check out only what you change.** Every package you don't check out comes already built
from cvmfs. Checking out more makes the build longer, and can break it when a package's
dependencies are declared incompletely. Example: protoduneana v10_26_00d05 needs dunereco
in its `CMakeLists.txt` (`find_package( dunereco ...)`), but its `ups/product_deps` doesn't
list it. With both checked out, mrb configures protoduneana first and CMake stops with
`Could not find a package configuration file provided by "dunereco"`. Fixes:

* You don't change dunereco: don't check it out (the default package list is only `protoduneana`).
* You do change it: add `dunereco v10_26_00d05` to the product list in
  `srcs/protoduneana/ups/product_deps`, run `mrb uc`, then build.

To spot this kind of problem, compare `find_package` with `ups depend`
([section 5](#what-a-package-needs-to-build-mrb-areas)).

### 8.2 Find and register an existing area

An area made by `dunenv new` is registered automatically. Areas you made by hand, or
before you had dunenv, need registering once:

```bash
dunenv scan                       # MRB areas under /exp/dune/app/users/$USER, and whether they're registered
dunenv add myana /exp/dune/app/users/$USER/myana_area --desc "My analysis modules"
dunenv list                       # registered areas with their release
```

* You don't give a version: it is read from the `localProducts_*` folder name, so each
  area always runs with the dunesw it was compiled against.
* `dunenv add` is a shortcut for writing this block in `dunenv.ini`; writing it by hand is equivalent:
  ```ini
  [env:myana]
  desc = My analysis modules
  area = /exp/dune/app/users/you/myana_area
  ```

### 8.3 Start it, and recompile after edits

Run your code:

```bash
dunenv start myana                # dunesw + your build (source localProducts_*/setup + mrbslp)
dunenv myana                      # same, short form
```

Recompile with `dunenv rebuild`. It reads everything from the registered area (folder,
project, version, qualifier), so it works from any folder, even days later:

```bash
ssh <you>@dunebuild02.fnal.gov    # rebuilds run only on build machines
dunenv rebuild myana              # incremental
dunenv rebuild myana --clean      # from scratch
dunenv rebuild myana -j 30        # other job count; works with --clean too
dunenv rebuild myana -p duneprototypes   # add a package to srcs/, then build from scratch
dunenv rebuild myana -n           # show what would run; run nothing
```

| Command | Runs | Use it when |
|---|---|---|
| `dunenv rebuild myana` | `mrbsetenv`, `make install -j 20`, `mrbslp` | **Edits inside existing module folders.** You changed `.cc` / `.h` files, or the module folder's own `CMakeLists.txt`, e.g. adding a missing library to `cet_build_plugin(XXXXX::Module ...)`. Only what changed recompiles. This is the everyday case |
| `dunenv rebuild myana --clean` | `mrb z`, `mrbsetenv`, `mrb i -j 20`, `mrbslp` | **New folders.** You added a new folder with new code, plus its `add_subdirectory(...)` line in the `CMakeLists.txt` one level up (the file that lists the subfolders). Also use it when the build folder is confused (odd CMake cache errors, stale libraries), when the incremental build stops with "no Makefile", or after adding a new package to `srcs/` by hand (run `mrb uc` first). Everything recompiles, so it takes much longer |
| `dunenv rebuild myana -p PKG` | tag check, `mrb g -t <version> PKG`, `mrb uc`, then the same as `--clean` | **New packages.** You want to edit a package you didn't check out when the area was made. One `-p` per package (`-p duneprototypes -p dunereco`). See below |
| `-j N` | the same, with N parallel jobs | Not a mode, just the job count. Default: `jobs` in `[newdev]` (20) |

All modes:
* open a fresh build container, set up the area's dunesw, and end with `mrbslp`, so the
  next `dunenv myana` uses the new build;
* refuse to run off a build machine (`build_hosts` in `[newdev]`). This is checked on the
  host and again inside the container;
* save the full output in `<area>/dunenv_rebuild_<date>_<time>.log`.

Adding a module folder you forgot, step by step (new folder, so `--clean`):

```bash
cp -r ~/my_module_dir <area>/srcs/protoduneana/protoduneana/MyModule
#   add "add_subdirectory(MyModule)" to the CMakeLists.txt one level up
dunenv rebuild myana --clean      # on dunebuild02
```

Later edits to that module's `.cc` / `.h` files or to its own `CMakeLists.txt`:
`dunenv rebuild myana`.

Adding a package to an area you already built (e.g. it has only protoduneana and you now
also need to change duneprototypes):

```bash
dunenv rebuild myana -p duneprototypes -n    # look first
dunenv rebuild myana -p duneprototypes       # on dunebuild02
```

* As with the other rebuild modes, nothing to remember: the package is checked out at
  the area's own version (`v10_26_00d05` for an area of that release).
* Which packages are possible, and how to check their tag, is in
  [8.1](#which-packages-can-go-after--p): DUNE packages with the dunesw version.
* A package already in `srcs/` is skipped (the summary lists it), so after a failure you
  fix the cause and run the **same command** again.
* Watch for undeclared dependencies. If the new package is needed by one you already
  have, but not listed in its `ups/product_deps`, the build fails (the dunereco case in
  8.1, *Check out only what you change*).
* The description shown by `dunenv list` stays as it was. Change it with
  `dunenv set desc "..." --env myana`.

`dunenv rebuild` must be started from the gpvm or build-machine shell, not from inside a
container. If you're already in a set-up container on a build machine (e.g. after
`dunenv myana build --dev`), do the same by hand:
`cd $MRB_BUILDDIR; make install -j20`.

Asking an area for another release (`-v`) stops with a list of the builds it has. To move
to a new release, create a new area (8.1).

### 8.4 Manage registered areas

* `dunenv set env myana` makes it the default for a plain `dunenv start`; `dunenv set env none` goes back.
* `dunenv rm myana` forgets it (the area itself is untouched).
* Optional keys in its `[env:myana]` block: `packages` (extra UPS products for this area
  only), `after` (commands run after `mrbslp`, e.g. `cd $MRB_TOP`), `version`/`qualifier`
  (only when the area holds several `localProducts_*` folders).

## 9. The config file

`dunenv edit` opens `dunenv.ini` in `$EDITOR` (vim if unset). Comments go on their own
lines. Indented lines continue the value above them (that's how the package lists work).
`${USER}` and `${HOME}` are expanded.

| Section | What it holds |
|---|---|
| `[defaults]` | `version`, `qualifier`, `env` (default local build or `none`), `grid` (yes/no), `workdir` (where setup ends), `packages`, `ups_setup`, `profile` |
| `[exports]` | variables exported before UPS starts (`UPS_OVERRIDE`, MetaCat URLs, certificates) |
| `[grid]` | `token_cmd` (the htgettoken command), `rucio_account` |
| `[container]` | apptainer path, image, mounted folders for the normal (`binds`) and build (`build_binds`) containers |
| `[newdev]` | defaults for `dunenv new`: `project`, `packages`, `jobs`, `build_hosts`, `repo_url`. `dunenv rebuild` uses `jobs` and `build_hosts` too, and `repo_url` with `-p` |
| `[env:<name>]` | one per local build (section 8) |

Settable from the command line: `dunenv set KEY VALUE` for `[defaults]`, or
`dunenv set KEY VALUE --env NAME` for a local build.

## 10. What setup does, step by step

1. Export the `[exports]` variables.
2. `source setup_dune.sh` (UPS), then `setup dunesw <version> -q <qualifier>`.
3. Set up the UPS products: `[defaults] packages`, then the local build's, then `-p`.
4. Local build, if any: `source localProducts_*/setup` (plus `mrbsetenv` with `--dev`), then `mrbslp`.
5. `source ~/.bash_profile` (your aliases and functions).
6. Grid (unless `--no-grid`): `htgettoken`, then `justin time`. If JUSTIN needs browser
   authorization, the step stops here (run `dunenv justin` after the browser). Otherwise:
   `justin get-token`, `RUCIO_ACCOUNT=justinreadonly`, `rucio whoami`.
7. Print `dunenv ready: ...` and `cd` to `workdir`.

## 11. Troubleshooting

| You see | Meaning / fix |
|---|---|
| `dunenv: command not found` | The `.bash_profile` line from [install](#3-install) is missing or not loaded yet: `source ~/.bash_profile`, or call it as `~/dunenv/dunenv` |
| `setup dunesw failed` | That version/qualifier doesn't exist. List them ([section 5](#5-choosing-a-dunesw-version)), then `dunenv setup -v ... -q ...` |
| `JUSTIN authorization is required` | Open the printed URL, approve, then `dunenv justin` in the same shell |
| Under `=== JUSTIN / Rucio ===`: `Cannot connect to the Rucio server`, after lines like `ConnectionError: HTTPSConnectionPool(host='dune-rucio.fnal.gov', port=443) ... /auth/x509_proxy ... SSLError ... TLSV1_ALERT_UNKNOWN_CA` | Not a dunenv problem. The JUSTIN / Rucio side rejected the credentials this time. Run the step again in the same shell: `dunenv justin`. It usually works on the next try |
| htgettoken asks for a browser login every time | Normal after the stored token expires; log in again |
| `This step changes the current shell, so it must be sourced` | You ran `~/dunenv/dunenv setup` directly. Use the `dunenv` command (the shell function) instead |
| `setup runs inside the SL7 container` | You are on the gpvm itself: use `dunenv start` |
| `environment 'X' has no build for ...` | That local build was compiled with another dunesw: drop `-v/-q`, or make a new MRB area for the new version and `dunenv add` it |
| `no localProducts_*/setup in ...` | The `area` path of that local build is wrong or the area was never built |
| `builds with -j N only run on dunebuild*` | `dunenv new` / `dunenv rebuild` were started on a gpvm: `ssh <you>@dunebuild02.fnal.gov` and run it there |
| `run 'dunenv rebuild' on the host` | You started it inside a container. `exit`, then run it again, or build by hand: `cd $MRB_BUILDDIR; make install -j20` |
| `has no Makefile ... use --clean` | The build folder was never built or was emptied by `mrb z`: `dunenv rebuild NAME --clean` |
| `WARNING setup <pkg> failed` | That UPS product/version doesn't exist; the rest of the setup continues |
| `lar` not found after setup | Scroll up: dunesw setup failed earlier. `dunenv status` shows what is active |
| Prompt still shows `Apptainer>` | The shell wasn't started by `dunenv`; run `source ~/dunenv/dunenv.sh` |

Not sure what a command will do? Add `-n`: it prints the full script that would run.

## 12. Files

| File | Role |
|---|---|
| `dunenv` | Python program (3.6+). Reads `dunenv.ini`, builds the setup script, starts the container. Never changes your shell itself |
| `dunenv.sh` | Bash file. It is read as the container shell's startup file: it runs the setup that `dunenv start` passed in, defines the `dunenv` command (which applies `setup`/`justin` to your current shell), and sets the `[user@host:os dir]$` prompt |
| `dunenv.ini` | Your settings, created on the first run |
