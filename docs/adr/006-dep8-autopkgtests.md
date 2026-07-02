# ADR-006: Use DEP-8 autopkgtests for package testing

Date: 2026-07-02
Status: Accepted

## Context

Three levels of testing were considered for verifying that the built packages
are correct:

**No automated tests** — rely on manual verification after install.
Rejected: provides no safety net for regressions and gives Launchpad nothing
to run after a build.

**Integration tests with Testcontainers** (the approach used in upstream PR #18)
— spin up Docker/Podman containers, install the packages, run a Java/Node.js/
.NET application, and assert that telemetry is emitted.
This is comprehensive end-to-end testing.
However, it requires Docker or Podman on the test host, is slow, and cannot be
run by Launchpad's autopkgtest infrastructure without a container-capable
virtualisation driver.

**DEP-8 autopkgtests** (`debian/tests/control`) — the standard Debian/Ubuntu
test mechanism.
Tests are declared in `debian/tests/control` and run by `autopkgtest` after
the package is built.
Launchpad runs these automatically on every upload.
Tests can use the `null` driver (run on the host), `lxd`, `qemu`, or other
virtualisation backends.
Required for Ubuntu universe.

## Decision

Use DEP-8 autopkgtests declared in `debian/tests/control` using the
`Test-Command:` inline form (no separate test script files).

Tests cover:

- **File presence**: verify that each package installs the expected files to
  the expected paths.
- **`/etc/ld.so.preload`**: verify the injector's postinst adds the `.so` path.
- **Binary validity**: `objdump -f` on the injector `.so` to confirm it is a
  valid ELF shared library.
- **JAR validity**: `file` on the Java agent JAR to confirm it is a valid Java
  archive.
- **conf.d correctness**: verify that each language package installs a conf.d
  drop-in pointing to the correct agent path, and that the path actually
  exists.
- **Metapackage**: verify the metapackage causes the injector to be installed.

Testcontainers-based end-to-end instrumentation tests (asserting that
telemetry is actually emitted) are deferred.
They can be added as a separate CI job outside of `debian/tests/control` if
needed.

## Consequences

The `Test-Command:` inline form was chosen over separate test script files
to keep all test logic in a single file and avoid lintian
`missing-runtime-test-file` warnings.

Tests run with `Depends: <package>` only — they do not require internet access
or a container runtime.
This makes them suitable for Launchpad's autopkgtest infrastructure and for
local runs with `autopkgtest ../*.deb -- null`.

The tests do not verify that auto-instrumentation actually injects into a
running process and produces telemetry.
That level of testing is a future addition and would require the `lxd` or
`qemu` autopkgtest driver to run a real application.
