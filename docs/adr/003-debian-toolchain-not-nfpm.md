# ADR-003: Use the standard `debian/` toolchain instead of nfpm

Date: 2026-07-02
Status: Accepted

## Context

The upstream `open-telemetry/opentelemetry-packaging` project (PR #18) builds
`.deb` packages using [nfpm](https://github.com/goreleaser/nfpm) as a Go
library.
nfpm produces valid `.deb` and `.rpm` files programmatically, without requiring
`dpkg-buildpackage`, `debian/` metadata, or the Debian toolchain.

For this Canonical packaging effort, two approaches were considered:

**nfpm** — the approach used upstream.
Packages are built by a Go CLI tool.
No `debian/` directory is required.
CI uses GitHub Actions to build and publish `.deb` files directly.
Works well for self-hosted repositories and GitHub Releases.
However, Launchpad requires source packages in the standard Debian format
(`.dsc` + orig tarball + `debian.tar.xz`, uploaded via `dput`).
nfpm cannot produce this format.

**Standard `debian/` toolchain** — `debhelper`, `dpkg-buildpackage`,
`dpkg-source`.
Produces source packages uploadable to Launchpad.
Required for Ubuntu universe.
Understood by all Ubuntu and Debian infrastructure: Launchpad build farm,
autopkgtest, lintian, `apt-get source`, etc.

## Decision

Use the standard `debian/` toolchain with `debhelper` (compat level 13) and
`dpkg-buildpackage`.

This is the only viable path for Launchpad PPA distribution and for any future
Ubuntu universe submission.
nfpm, while convenient for self-hosted repositories, cannot produce the source
package format that Launchpad requires.

## Consequences

This repository is a parallel implementation to the upstream nfpm-based build.
It shares the package architecture design (virtual `Provides`, vendor-swap
`Conflicts`/`Replaces`, POSIX-only lifecycle scripts, per-language conf.d
drop-ins) but re-implements the build machinery using the Debian toolchain.

Changes to the package architecture upstream (e.g. new languages, new interface
versions, changes to the conf.d contract) need to be reflected here manually.
This is an acceptable maintenance cost given that the upstream design is
stable and well-documented in PR #10.

The nfpm-based upstream build remains the reference for RPM packages and for
non-Launchpad DEB distribution.
This repository produces only DEB packages targeting Ubuntu Noble.
