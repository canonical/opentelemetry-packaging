# opentelemetry

Debian packaging for the OpenTelemetry auto-instrumentation suite,
targeting Ubuntu Stonking (26.10).
Produces packages that can be distributed via a Launchpad PPA or
(after a full license audit and source build) Ubuntu universe.

## Packages

| Binary package | Description |
|---|---|
| `opentelemetry-injector` | LD_PRELOAD-based injector that activates language agents |
| `opentelemetry-java-autoinstrumentation` | OpenTelemetry Java agent JAR |
| `opentelemetry-nodejs-autoinstrumentation` | OpenTelemetry Node.js auto-instrumentation |
| `opentelemetry-dotnet-autoinstrumentation` | OpenTelemetry .NET Automatic Instrumentation |
| `opentelemetry` | Metapackage — installs the full suite |

## Installing from the PPA

```sh
sudo add-apt-repository ppa:observability/opentelemetry
sudo apt update
sudo apt install opentelemetry
```

## Repository layout

```
debian/                  Standard Debian packaging metadata
  control                Source package + 5 binary package stanzas
  rules                  dh build rules; copies from unpacked orig (no network)
  versions.mk            Pinned upstream component versions
  packaging/             Config files, conf.d drop-ins, lifecycle scripts
    common/
      injector/          injector.conf, default_env.conf
      java/              java.conf (conf.d drop-in), otel-sdk-config.yaml
      nodejs/            nodejs.conf (conf.d drop-in), otel-sdk-config.yaml
      dotnet/            dotnet.conf (conf.d drop-in), otel-sdk-config.yaml
      scripts/           postinstall-injector.sh, preuninstall-injector.sh
  scripts/
    get-orig-source.sh   Downloads pinned upstream releases, assembles orig tarball
  tests/control          DEP-8 autopkgtests run by Launchpad
  opentelemetry-injector.postinst   Appends libotelinject.so to /etc/ld.so.preload
  opentelemetry-injector.prerm      Removes libotelinject.so from /etc/ld.so.preload
  *.install              File-to-package mappings for dh_install
  *.conffiles            User-editable config files preserved on upgrade
  source/options         extend-diff-ignore rules for upstream/ binary tree
  source/lintian-overrides   Overrides for expected prebuilt-binary warnings

.github/workflows/
  build-and-upload.yml   CI: build source package, sign, dput to Launchpad

docs/adr/                Architecture Decision Records
  001-ppa-first-universe-later.md
  002-source-package-name.md
  003-debian-toolchain-not-nfpm.md
  004-quilt-format-pinned-orig.md
  005-bundle-nodejs-node-modules.md
  006-dep8-autopkgtests.md
  007-build-injector-from-source.md
```

The `upstream/` directory (the unpacked orig tarball contents) is never
committed to git — it is a build artefact produced by `get-orig-source.sh`
and consumed by `debian/rules` at build time.

## Building and testing locally

This section walks through a full local build and install cycle.

### How it works

This package uses the `3.0 (quilt)` Debian source format.
The orig tarball (`opentelemetry_<version>.orig.tar.gz`) contains upstream
artifacts downloaded at pinned versions from `debian/versions.mk`:

- **Injector**: Source code (built from source using Zig during package build)
- **Java agent**: Pre-built JAR
- **Node.js**: Pre-built npm bundle
- **.NET**: Pre-built assemblies

The `debian/` layer (config files, build rules, maintainer scripts) sits on
top of that.

At build time `debian/rules` builds the injector from source and copies
the other artifacts from the unpacked orig into the package staging area.
**No network access is required during the build itself.**
Network access is only needed when generating the orig tarball
(`debian/scripts/get-orig-source.sh`), which maintainers run locally before
uploading to Launchpad.

**Note:** Building the injector from source requires Zig >= 0.14, which is
available in Ubuntu 26.10 (Stonking) but not in earlier releases. See ADR-007
for details.

### Prerequisites

```sh
sudo apt install debhelper devscripts dpkg-dev curl jq unzip
```

### 1. Pin the component versions

Open `debian/versions.mk` and check the pinned versions.
To upgrade a component, update its version line and re-run step 2.

```
INJECTOR_VERSION := 0.9.0
JAVA_VERSION     := 2.29.0
NODEJS_VERSION   := 0.77.0
DOTNET_VERSION   := 1.15.0
```

### 2. Generate the orig tarball

This downloads the pinned upstream artifacts and assembles
`opentelemetry_<SUITE_VERSION>.orig.tar.gz` one directory above the repo root.
It needs to be run once per version, or whenever you change a version in
`debian/versions.mk`.

```sh
debian/scripts/get-orig-source.sh
```

The script downloads:
- Source tarball for the injector (built from source during package build)
- `opentelemetry-javaagent.jar` from the Java instrumentation releases
- `auto-instrumentations-node-<version>.tgz` from the npm registry
- Four .NET zips (glibc/musl × amd64/arm64) from the dotnet-instrumentation releases

The resulting tarball contains an `upstream/` directory with the injector
source tree and pre-built artifacts for other components.
It is not committed to git.

### 3. Build with sbuild (recommended)

sbuild builds packages in a clean chroot, ensuring all build dependencies
are correctly declared. This is the recommended method and closely matches
how Launchpad builds packages.

#### One-time setup: create a stonking chroot

```sh
sudo apt install sbuild schroot debootstrap
sudo sbuild-createchroot \
    --include=eatmydata \
    stonking \
    /srv/chroot/stonking-amd64 \
    http://archive.ubuntu.com/ubuntu
sudo sbuild-adduser $USER
# Log out and back in for group membership to take effect
```

The chroot is created with only the `main` component. Zig is in `universe`,
so you need to enable it:

```sh
sudo sbuild-shell stonking-amd64-sbuild
```

Inside the chroot:

```sh
echo "deb http://archive.ubuntu.com/ubuntu stonking universe" >> /etc/apt/sources.list
apt update
exit
```

#### Build the package

```sh
sbuild -d stonking -c stonking-amd64-sbuild --no-clean-source --no-run-lintian
```

The `--no-clean-source` flag preserves the source tree for debugging if the
build fails. Built packages appear in the current directory.

The `--no-run-lintian` flag skips lintian checks. We will fix these later.

### 4. Alternative: build with dpkg-buildpackage

If you have Zig >= 0.14 installed locally (e.g., on Ubuntu 26.10), you can
build directly without sbuild.

First, unpack the orig tarball:

```sh
tar -xzf ../opentelemetry_0.1.0.orig.tar.gz --strip-components=1 --wildcards '*/upstream'
```

Then build:

```sh
dpkg-buildpackage -us -uc
```

`debian/rules` builds the injector from source, copies other artifacts from
the unpacked `upstream/` tree into `debian/tmp/`, then `dh_install` splits
them into the five binary packages.

Once done:

```sh
ls ../*.deb
```

Expected output:

```
../opentelemetry_0.1.0-0ubuntu1_all.deb
../opentelemetry-injector_0.1.0-0ubuntu1_amd64.deb
../opentelemetry-java-autoinstrumentation_0.1.0-0ubuntu1_all.deb
../opentelemetry-nodejs-autoinstrumentation_0.1.0-0ubuntu1_all.deb
../opentelemetry-dotnet-autoinstrumentation_0.1.0-0ubuntu1_amd64.deb
```

### 5. Inspect a package before installing

`dpkg-deb -c` lists every file the package will install:

```sh
dpkg-deb -c ../opentelemetry-injector_0.1.0-0ubuntu1_amd64.deb
```

`dpkg-deb -I` shows the package metadata (version, Provides, Depends, etc.):

```sh
dpkg-deb -I ../opentelemetry-injector_0.1.0-0ubuntu1_amd64.deb
```

Alternatively, `debc` (from `devscripts`) can show all packages from the last
build at once — run it without arguments from inside the source tree after
`dpkg-buildpackage` completes:

```sh
debc
```

### 6. Install the packages locally

A plain `dpkg -i` won't resolve virtual package dependencies
(`opentelemetry-injector1` etc.).
Create a minimal local APT repository instead:

```sh
mkdir -p /tmp/otel-local-repo
cp ../*.deb /tmp/otel-local-repo/
(cd /tmp/otel-local-repo && dpkg-scanpackages . | gzip -c > Packages.gz)

echo "deb [trusted=yes] file:///tmp/otel-local-repo ./" \
  | sudo tee /etc/apt/sources.list.d/otel-local.list

sudo apt update
sudo apt install opentelemetry
```

### 7. Verify the installation

```sh
grep libotelinject /etc/ld.so.preload
ls /etc/opentelemetry/injector/conf.d/
dpkg -s opentelemetry-injector
dpkg -s opentelemetry
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
sudo autopkgtest ../*.deb -- lxd ubuntu:stonking
```

### 9. Clean up

```sh
sudo apt remove opentelemetry opentelemetry-injector \
  opentelemetry-java-autoinstrumentation \
  opentelemetry-nodejs-autoinstrumentation \
  opentelemetry-dotnet-autoinstrumentation
sudo rm /etc/apt/sources.list.d/otel-local.list
sudo apt update
rm -f ../*.deb ../*.dsc ../*.tar.* ../*.buildinfo ../*.changes
```

### Upgrading a component version

1. Update the version in `debian/versions.mk`.
2. Run `debian/scripts/get-orig-source.sh` to download the new artifacts.
3. Bump `SUITE_VERSION` in `debian/versions.mk` if this is a new suite release,
   or just the Ubuntu revision in `debian/changelog`
   (e.g. `0.1.0-0ubuntu1` → `0.1.0-0ubuntu2`) for a packaging-only change.
4. Add a `debian/changelog` entry with `dch`.
5. Rebuild with `dpkg-buildpackage -us -uc`.

### Troubleshooting

**`dpkg-source: error: aborting due to unexpected upstream changes`**
The orig tarball is out of sync with the working tree.
Re-run `debian/scripts/get-orig-source.sh` and retry.

**`apt install opentelemetry` says "Unable to locate package".**
Re-run `dpkg-scanpackages` from inside the repo directory and `sudo apt update` — the local repo index
may be stale:

```sh
( cd /tmp/otel-local-repo && dpkg-scanpackages . | gzip -c > Packages.gz )
sudo apt update
```

**The metapackage installs but `opentelemetry-injector1` is unsatisfied.**
The `Provides` field was not picked up by APT.
Confirm the index was regenerated:

```sh
zcat /tmp/otel-local-repo/Packages.gz | grep -A5 "Package: opentelemetry-injector"
```

## Versioning

Package versions follow the Ubuntu convention `<upstream>-<debian>ubuntu<ubuntu>`:

- `0.1.0` — the upstream version (our suite-level version, not tied to any
  individual component release).
- `-0` — the Debian revision; `0` because this package has never been in Debian.
- `ubuntu1` — the Ubuntu packaging revision; incremented for each packaging-only
  change within the same upstream version.

So the first release is `0.1.0-0ubuntu1`.
A packaging-only fix to that release would be `0.1.0-0ubuntu2`.
A new upstream version would be `0.2.0-0ubuntu1`.

## Relationship to upstream

This repository is a parallel Canonical implementation targeting the
Launchpad/Ubuntu toolchain.
The package architecture (virtual interface-versioned `Provides`,
vendor-swappable language packages, POSIX-only lifecycle scripts) follows
the design documented in the upstream
[opentelemetry-packaging](https://github.com/open-telemetry/opentelemetry-packaging)
repository (PR #10 and PR #18), which uses nfpm as its build tool.

## Path to Ubuntu universe

The following work is required before submitting to Ubuntu universe:

- Full `debian/copyright` audit of all bundled Node.js modules and
  .NET managed assemblies.
- Build remaining components from source (Java agent, Node.js bundle,
  .NET native library) — the injector is already built from source
  (see ADR-007).
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
