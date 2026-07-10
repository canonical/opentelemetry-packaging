# ADR-001: Distribute via Launchpad PPA first, with Ubuntu universe as a future goal

Date: 2026-07-02
Status: Accepted

## Context

The OpenTelemetry auto-instrumentation packages need to be distributed to Ubuntu
users.
Two channels were considered:

**Launchpad PPA** — a maintainer-controlled APT repository hosted by Canonical.
Packages are built by Launchpad's build farm and served at
`ppa.launchpad.net`.
Users add it with `add-apt-repository ppa:<team>/<name>`.
Requirements are relatively light: a GPG-signed source upload, a valid
`debian/` directory, and passing `dpkg-buildpackage`.
Notably, network access is permitted during the build, and pre-built binary
artifacts may be bundled in the orig tarball.

**Ubuntu universe** — the community-maintained component of the official Ubuntu
archive.
Packages in universe are available to all Ubuntu users without adding any
extra repository.
Requirements are significantly stricter: all software must be built entirely
from source on Launchpad's buildd infrastructure (no network access, no
pre-built binaries), a full `debian/copyright` audit of every bundled
dependency is required, `lintian` must report no errors or warnings, and the
package must go through a NEW queue review by an Ubuntu archive admin.

## Decision

Start with a Launchpad PPA.
Work toward Ubuntu universe inclusion as a follow-on effort.

The PPA approach allows us to:
- Ship packages to users quickly without the full source-build requirement.
- Bundle pre-built upstream artifacts (Java JAR, Node.js bundle, .NET
  assemblies, injector `.so`) directly in the orig tarball.
- Iterate on the packaging without blocking on archive admin review.

## Consequences

Packages will not be available to users without first adding the PPA.
This is an acceptable trade-off for the initial release.

The following work is deferred to the universe path and must not be forgotten:

- Build all components from source:
  - `opentelemetry-injector` — requires a Go build environment.
  - Java agent — requires Maven and the full Java build toolchain.
  - Node.js bundle — requires npm and a reproducible bundle build.
  - .NET assemblies and native profiler — requires the .NET SDK.
- Full `debian/copyright` audit of all bundled Node.js transitive dependencies
  and .NET managed assemblies.
- `lintian --pedantic` clean output (the current `source-is-missing` and
  `source-contains-prebuilt-windows-binary` overrides must be resolved, not
  just suppressed).
- NEW queue submission via a Debian Developer or Ubuntu Core Developer sponsor.
- Switch to a build process that does not require network access (the orig
  tarball approach already satisfies this for the source package; the binary
  build must also be network-free).
