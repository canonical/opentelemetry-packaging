# opentelemetry

Debian packaging for the OpenTelemetry auto-instrumentation suite,
targeting Ubuntu Noble (24.04 LTS).
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
  rules                  dh build rules; fetches upstream artifacts at build time
  tests/control          DEP-8 autopkgtests run by Launchpad
  opentelemetry-injector.postinst   Appends libotelinject.so to /etc/ld.so.preload
  opentelemetry-injector.prerm      Removes libotelinject.so from /etc/ld.so.preload
  *.install              File-to-package mappings for dh_install
  *.conffiles            User-editable config files preserved on upgrade

packaging/common/        Config files, conf.d drop-ins, lifecycle scripts
  injector/              injector.conf, default_env.conf
  java/                  java.conf (conf.d drop-in), otel-sdk-config.yaml
  nodejs/                nodejs.conf (conf.d drop-in), otel-sdk-config.yaml
  dotnet/                dotnet.conf (conf.d drop-in), otel-sdk-config.yaml
  scripts/               postinstall-injector.sh, preuninstall-injector.sh

scripts/
  fetch-artifacts.sh     Downloads latest upstream releases at build time

.github/workflows/
  build-and-upload.yml   CI: build source package, sign, dput to Launchpad
```

## Building and testing locally

This section walks through a full local build and install cycle on Ubuntu Noble.
You need an internet connection — the build fetches upstream release artifacts
from GitHub at build time.

### Prerequisites

Install the build tools:

```sh
sudo apt install debhelper devscripts dpkg-dev curl jq unzip
```

`unzip` is needed by the fetch script to unpack the .NET instrumentation zip.
`curl` and `jq` fetch and parse the GitHub Releases API responses.

### 1. Build the binary packages

Run `dpkg-buildpackage` from the repository root.
The `-us -uc` flags skip signing (not needed for local use).

```sh
dpkg-buildpackage -us -uc
```

This will:
1. Call `scripts/fetch-artifacts.sh` to download the latest upstream releases
   (injector `.so`, Java agent JAR, Node.js bundle, .NET binaries).
2. Stage everything under `debian/tmp/`.
3. Run `dh_install` to split the staged files into the five binary packages.
4. Produce `.deb` files one directory above the repo root.

The first run takes a couple of minutes depending on network speed.
Subsequent builds reuse nothing — `debian/tmp/` is always wiped — so
artifacts are always at the latest upstream release.

Once done, list what was built:

```sh
ls ../*.deb
```

You should see something like:

```
../opentelemetry_0.1.0_all.deb
../opentelemetry-injector_0.1.0_amd64.deb
../opentelemetry-java-autoinstrumentation_0.1.0_all.deb
../opentelemetry-nodejs-autoinstrumentation_0.1.0_all.deb
../opentelemetry-dotnet-autoinstrumentation_0.1.0_amd64.deb
```

### 2. Inspect a package before installing

`debc` lists every file that will be installed by each package:

```sh
debc ../opentelemetry-injector_0.1.0_amd64.deb
```

`dpkg-deb --info` shows the package metadata (version, dependencies,
Provides, etc.):

```sh
dpkg-deb --info ../opentelemetry-injector_0.1.0_amd64.deb
```

### 3. Install the packages locally

Create a minimal local APT repository from the built `.deb` files, then
install from it.
This is the recommended approach because `dpkg -i` does not resolve
inter-package dependencies (the metapackage depends on `opentelemetry-injector1`,
which is a virtual package that must be found in an APT index).

```sh
# Create the local repo directory and index it.
mkdir -p /tmp/otel-local-repo
cp ../*.deb /tmp/otel-local-repo/
cd /tmp/otel-local-repo
dpkg-scanpackages . | gzip -c > Packages.gz

# Add it as an APT source (pinned to local so it overrides nothing from
# Ubuntu's own repositories).
echo "deb [trusted=yes] file:///tmp/otel-local-repo ./" \
  | sudo tee /etc/apt/sources.list.d/otel-local.list

sudo apt update
sudo apt install opentelemetry
```

To install a single package instead of the full suite:

```sh
sudo apt install opentelemetry-injector
```

### 4. Verify the installation

Check that the injector `.so` is registered in `/etc/ld.so.preload`:

```sh
grep libotelinject /etc/ld.so.preload
```

Check the conf.d drop-ins installed by the language packages:

```sh
ls /etc/opentelemetry/injector/conf.d/
```

Check the declarative config templates:

```sh
ls /etc/opentelemetry/
```

Verify that `dpkg` records the correct metadata (Provides, Depends, etc.):

```sh
dpkg -s opentelemetry-injector
dpkg -s opentelemetry
```

### 5. Run the DEP-8 autopkgtests locally

Install `autopkgtest`:

```sh
sudo apt install autopkgtest
```

Run the tests using the `null` virtualisation driver (runs directly on your
machine, no VM or container needed — only use this on a throwaway system or
VM since the tests install packages):

```sh
sudo autopkgtest ../*.deb -- null
```

Or, if you have a spare LXD container or VM and want an isolated environment,
use the `lxd` driver:

```sh
sudo autopkgtest ../*.deb -- lxd ubuntu:noble
```

### 6. Clean up

Remove the local APT source and uninstall:

```sh
sudo apt remove opentelemetry opentelemetry-injector \
  opentelemetry-java-autoinstrumentation \
  opentelemetry-nodejs-autoinstrumentation \
  opentelemetry-dotnet-autoinstrumentation
sudo rm /etc/apt/sources.list.d/otel-local.list
sudo apt update
```

Remove the built packages:

```sh
cd /path/to/repo
rm -f ../*.deb ../*.dsc ../*.tar.xz ../*.buildinfo ../*.changes
```

### Troubleshooting

**`fetch-artifacts.sh` fails with a 404 or rate-limit error.**
GitHub's unauthenticated API is limited to 60 requests per hour.
Set a personal access token to raise the limit:

```sh
GITHUB_TOKEN=ghp_yourtoken dpkg-buildpackage -us -uc
```

Then add token support to `scripts/fetch-artifacts.sh` by passing
`--header "Authorization: Bearer $GITHUB_TOKEN"` to the `curl` calls.

**`apt install opentelemetry` says "Unable to locate package".**
Re-run `dpkg-scanpackages` and `sudo apt update` — the local repo index
may be stale if you rebuilt the packages.

**The metapackage installs but `opentelemetry-injector1` is unsatisfied.**
This means the `Provides: opentelemetry-injector1` field in
`opentelemetry-injector` was not picked up by APT.
Confirm the Packages index was regenerated after the latest build:

```sh
cat /tmp/otel-local-repo/Packages.gz | zcat | grep -A5 "Package: opentelemetry-injector"
```

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

- Switch source format to `3.0 (quilt)` with explicit orig tarballs
  (no network fetch at build time on Ubuntu buildd infrastructure).
- Full `debian/copyright` audit of all bundled Node.js modules and
  .NET managed assemblies.
- Build all components from source (injector, Java agent, Node.js
  bundle, .NET native library).
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
