# opentelemetry-packaging

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

## Building locally

Install build dependencies:

```sh
sudo apt install debhelper devscripts dpkg-dev curl jq
```

Build the source package (no network fetch — this only creates the .dsc):

```sh
dpkg-buildpackage --build=source --no-sign --no-check-builddeps
```

To do a full binary build (fetches upstream artifacts, requires network):

```sh
dpkg-buildpackage --no-sign --no-check-builddeps
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
