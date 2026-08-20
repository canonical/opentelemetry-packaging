# opentelemetry-injector

Debian packaging for the OpenTelemetry LD_PRELOAD automatic instrumentation
injector, targeting Ubuntu Stonking (26.10).
Produces a package that can be distributed via a Launchpad PPA or
(after a full license audit and source build) Ubuntu universe.

## Package

| Binary package | Description |
|---|---|
| `opentelemetry-injector` | LD_PRELOAD-based injector that activates language agents |

## Installing from the PPA

```sh
sudo add-apt-repository ppa:observability/opentelemetry
sudo apt update
sudo apt install opentelemetry-injector
```

## Repository layout

```
debian/                  Standard Debian packaging metadata
  control                Source package + opentelemetry-injector binary stanza
  rules                  dh build rules; builds injector from source with Zig
  packaging/             Config files and lifecycle scripts
    common/
      injector/          injector.conf, default_env.conf
      scripts/           postinstall-injector.sh, preuninstall-injector.sh
  scripts/
    get-orig-source.sh   Downloads injector source, assembles orig tarball
  tests/control          DEP-8 autopkgtests run by Launchpad
  tests/preload-management   Lifecycle test: /etc/ld.so.preload management
  tests/config-handling      Lifecycle test: conffile handling across remove/purge
  opentelemetry-injector.postinst   Appends libotelinject.so to /etc/ld.so.preload
  opentelemetry-injector.prerm      Removes libotelinject.so from /etc/ld.so.preload
  *.install              File-to-package mappings for dh_install
  source/options         extend-diff-ignore rules for upstream/ binary tree
  source/format          3.0 (quilt)

.github/workflows/
  build-and-upload.yml   CI: build source package, sign, dput to Launchpad

docs/adr/
  007-build-injector-from-source.md
```

The `upstream/` directory (the unpacked orig tarball contents) is never
committed to git — it is a build artefact produced by `get-orig-source.sh`
and consumed by `debian/rules` at build time.

## Building and testing locally

This section walks through a full local build and install cycle.

### How it works

This package uses the `3.0 (quilt)` Debian source format.
The orig tarball (`opentelemetry-injector_<version>.orig.tar.gz`) contains the
injector source tree downloaded at the version pinned in `debian/changelog`:

- **Injector**: Source code (built from source using Zig during package build)

The `debian/` layer (config files, build rules, maintainer scripts) sits on
top of that.

At build time `debian/rules` builds the injector from source and copies
the result into the package staging area.
**No network access is required during the build itself.**
Network access is only needed when generating the orig tarball
(`debian/scripts/get-orig-source.sh`), which maintainers run locally before
uploading to Launchpad.

**Note:** Building the injector from source requires Zig >= 0.15, which is
available in Ubuntu 26.10 (Stonking) but not in earlier releases. See ADR-007
for details.

### Prerequisites

```sh
sudo apt install debhelper devscripts dpkg-dev curl
```

### 1. Check the component version

The injector version is the upstream version field in `debian/changelog`.
To upgrade, bump it there and re-run step 2.

```
opentelemetry-injector (0.11.0-0ubuntu1) stonking; urgency=medium
                      ^^^^^
```

### 2. Generate the orig tarball

This downloads the injector source and assembles
`opentelemetry-injector_<version>.orig.tar.gz` one directory above the
repo root.
Run once per version, or whenever you change the version in `debian/changelog`.

```sh
debian/scripts/get-orig-source.sh
```

### 3. Build with sbuild (recommended)

sbuild builds in an isolated environment matching Launchpad's build farm.
Ubuntu Stonking uses the `unshare` backend — no chroot directory is needed;
sbuild uses a tarball instead.

#### One-time setup

Install the required tools:

```sh
sudo apt install sbuild mmdebstrap
sudo sbuild-adduser $USER
```

Log out and back in for the group membership to take effect.

Configure sbuild to use the unshare backend.
Create `~/.config/sbuild/config.pl` if it does not exist and add:

```perl
$chroot_mode = "unshare";
```

Create the stonking base tarball.
This is downloaded once and reused for all subsequent builds:

```sh
mkdir -p ~/.cache/sbuild
mmdebstrap --mode=unshare \
    --variant=buildd \
    --components=main,universe \
    --include=fakeroot,build-essential,eatmydata \
    stonking \
    ~/.cache/sbuild/stonking-amd64.tar.zst \
    http://archive.ubuntu.com/ubuntu
```

`--components=main,universe` is required because `zig0.15` (needed to build
the injector from source) lives in `universe`.

#### Build the package

```sh
sbuild --dist=stonking
```

### 4. Alternative: build with dpkg-buildpackage

If you have Zig >= 0.15 installed locally (e.g., on Ubuntu 26.10), you can
build directly without sbuild.

First, unpack the orig tarball:

```sh
tar -xzf ../opentelemetry-injector_0.11.0.orig.tar.gz --strip-components=1 --wildcards '*/upstream'
```

Then build:

```sh
dpkg-buildpackage -us -uc
```

`debian/rules` builds the injector from source then copies it into `debian/tmp/`.

Once done:

```sh
ls ../*.deb
```

Expected output:

```
../opentelemetry-injector_0.11.0-0ubuntu1_amd64.deb
```

### 5. Inspect the package before installing

`dpkg-deb -c` lists every file the package will install:

```sh
dpkg-deb -c ../opentelemetry-injector_0.11.0-0ubuntu1_amd64.deb
```

`dpkg-deb -I` shows the package metadata (version, Provides, Depends, etc.):

```sh
dpkg-deb -I ../opentelemetry-injector_0.11.0-0ubuntu1_amd64.deb
```

### 6. Install the package locally

A plain `dpkg -i` won't resolve virtual package dependencies
(`opentelemetry-injector1` etc.).
Create a minimal local APT repository instead:

```sh
mkdir -p /tmp/otel-local-repo
cp ./*.deb /tmp/otel-local-repo/
(cd /tmp/otel-local-repo && dpkg-scanpackages . | gzip -c > Packages.gz)

echo "deb [trusted=yes] file:///tmp/otel-local-repo ./" \
  | sudo tee /etc/apt/sources.list.d/otel-local.list

sudo apt update
sudo apt install opentelemetry-injector
```

### 7. Verify the installation

```sh
grep libotelinject /etc/ld.so.preload
ls /etc/opentelemetry/injector/conf.d/
dpkg -s opentelemetry-injector
```

### 8. Run the DEP-8 autopkgtests locally

```sh
sudo apt install autopkgtest
```

On the host directly (use only on a throwaway VM):

```sh
sudo autopkgtest ../*.deb -- null
```

In an isolated LXD container:

```sh
sudo autopkgtest -U ../*.deb -- lxd ubuntu-daily:stonking
```

### 9. Clean up

```sh
sudo apt remove opentelemetry-injector
sudo rm /etc/apt/sources.list.d/otel-local.list
sudo apt update
rm -f ../*.deb ../*.dsc ../*.tar.* ../*.buildinfo ../*.changes
```

### Upgrading the injector version

1. Bump the upstream version in `debian/changelog`
   (e.g. `0.11.0-0ubuntu1` → `0.11.0-0ubuntu2` for a packaging-only change,
   or `0.12.0-0ubuntu1` for a new upstream release).
2. Run `debian/scripts/get-orig-source.sh` to download the new source.
3. Rebuild with `dpkg-buildpackage -us -uc`.

### Troubleshooting

**`dpkg-source: error: aborting due to unexpected upstream changes`**
Your `debian/changelog` version doesn't match the orig tarball in the parent
directory. Re-run `debian/scripts/get-orig-source.sh` and retry.

**`apt install opentelemetry-injector` says "Unable to locate package".**
Re-run `dpkg-scanpackages` from inside the repo directory and `sudo apt update`:

```sh
( cd /tmp/otel-local-repo && dpkg-scanpackages . | gzip -c > Packages.gz )
sudo apt update
```

## Versioning

Package versions follow the Ubuntu convention `<upstream>-<debian>ubuntu<ubuntu>`:

- `0.11.0` — the upstream version, taken from `debian/changelog` and matching
  the upstream injector release it packages.
- `-0` — the Debian revision; `0` because this package has never been in Debian.
- `ubuntu1` — the Ubuntu packaging revision; incremented for each packaging-only
  change within the same upstream version.

So the first release is `0.11.0-0ubuntu1`.
A packaging-only fix to that release would be `0.11.0-0ubuntu2`.
A new upstream version would be `0.2.0-0ubuntu1`.

## Relationship to upstream

This repository is a parallel Canonical implementation targeting the
Launchpad/Ubuntu toolchain.
The upstream injector lives at
[open-telemetry/opentelemetry-injector](https://github.com/open-telemetry/opentelemetry-injector).

## Path to Ubuntu universe

The following work is required before submitting to Ubuntu universe:

- `lintian --pedantic` clean output.
- NEW queue submission via a Debian Developer sponsor.

## Placeholders

The following values must be filled in before the first PPA upload:

- `TODO@canonical.com` in `debian/control`, `debian/changelog`, and
  `.github/workflows/build-and-upload.yml` — replace with the actual
  Canonical team email that matches the Launchpad-registered GPG key.
- `TODO-team/opentelemetry` in `.github/workflows/build-and-upload.yml`
  and this README — replace with the actual Launchpad PPA identifier.
- GitHub Actions secrets `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE`.
- GitHub Actions variables `LAUNCHPAD_PPA`, `DEBEMAIL`, `DEBFULLNAME`.
