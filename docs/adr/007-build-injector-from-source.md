# ADR-007: Build the injector from source using Zig

Date: 2026-07-06
Status: Accepted

## Context

ADR-001 established that the initial PPA release would bundle pre-built
upstream binaries, deferring source builds to the Ubuntu universe path.
The `opentelemetry-injector` package currently ships a pre-built
`libotelinject.so` downloaded from GitHub releases.

The injector is written in Zig (not Go, as ADR-001 incorrectly states).
Building from source requires the Zig compiler.

Zig availability in Ubuntu:

- **Ubuntu 26.10 (Stonking/devel)** — Zig 0.14.1 is available as `zig`, and
  Zig 0.15.x is available as `zig0.15`.

The upstream injector declares `minimum_zig_version = "0.15.2"` in
`build.zig.zon`, requiring Zig 0.15+.

## Decision

Build the injector from source using the `zig0.15` package, targeting
Ubuntu 26.10 (devel) initially.

Key choices:

1. **Target release**: Ubuntu 26.10 (stonking/devel), not 24.04.
   This provides Zig 0.15 in the archive without vendoring the compiler.

2. **Zig version**: Use the `zig0.15` package, which meets the upstream
   minimum version requirement (0.15.2). The package installs the binary
   as `/usr/bin/zig0.15`, so `debian/rules` creates a symlink wrapper
   (`debian/.zig-wrapper/zig` → `/usr/bin/zig0.15`) and prepends it to
   `PATH` during the build.

3. **Architecture**: amd64 only for this increment.
   arm64 support can be added later once the build is proven.

4. **Build method**: Use upstream's Makefile (`make ARCH=amd64`), which
   invokes `zig build` with the appropriate flags.

5. **Tests**: Run `make zig-unit-tests` during the build to catch issues
   early, following Debian best practice.

6. **Other components**: Java, Node.js, and .NET packages remain pre-built
   binaries. This ADR covers only the injector.

## Consequences

**Build dependencies change**:

The `opentelemetry-injector` package gains a build dependency on `zig0.15`.
The `Build-Depends` field in `debian/control` must be updated.

**Source tarball structure changes**:

The orig tarball will contain injector source code under `upstream/injector/`
instead of pre-built `.so` files. The `debian/scripts/get-orig-source.sh`
script must be updated to fetch the GitHub source tarball instead of release
binaries.

**`debian/rules` changes**:

- `override_dh_auto_build`: Create a symlink wrapper for `zig` → `zig0.15`,
  prepend it to `PATH`, and run `make ARCH=amd64` in `upstream/injector/`.
- `override_dh_auto_test`: Run `make zig-unit-tests` in `upstream/injector/`
  with the same `PATH` modification.
- `override_dh_auto_install`: Copy from `upstream/injector/so/libotelinject.so`
  instead of `upstream/injector/libotelinject_amd64.so`.

**Ubuntu 24.04 users**:

Users on Ubuntu 24.04 LTS cannot use this package. They can use the upstream
nfpm-built packages from GitHub releases, or wait for a potential backport
if Zig becomes available via a PPA.

**Progress toward universe**:

This is the first component to be built from source, reducing the pre-built
binary footprint. The Java agent, Node.js bundle, and .NET assemblies remain
as future work items for the universe path.

**Lintian errors deferred**:

Lintian errors are not blockers for the PPA but must be resolved before Ubuntu 
universe submission.

For PPA builds, lintian can be skipped with `--no-run-lintian` (sbuild) or
`--no-lintian` (debuild). These issues are tracked for the universe path.
