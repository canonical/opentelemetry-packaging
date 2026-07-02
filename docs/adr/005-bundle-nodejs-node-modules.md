# ADR-005: Bundle Node.js `node_modules` directly in the package

Date: 2026-07-02
Status: Accepted

## Context

The `opentelemetry-nodejs-autoinstrumentation` package delivers
`@opentelemetry/auto-instrumentations-node` and all of its transitive npm
dependencies to the target system.
Three approaches were considered:

**Use system packages for Node.js dependencies** — depend on Ubuntu-packaged
versions of each npm module.
Rejected immediately: the vast majority of the transitive dependencies of
`@opentelemetry/auto-instrumentations-node` are not packaged in Ubuntu.
Packaging hundreds of npm modules would be an enormous effort and would likely
be out of date.

**Treat as a pre-built upstream artifact** — download the npm tarball at a
pinned version, unpack it into the package, and ship the full `node_modules`
tree as-is.
This is analogous to how the Java agent JAR is handled: it is a self-contained
upstream release artifact.

**Use system `npm` to install at build time** — run `npm install` during the
package build to produce the `node_modules` tree.
Rejected because it requires network access at build time and produces
non-reproducible output (npm resolves transitive dependency versions at
install time unless a lockfile is present, and the npm registry is an
external dependency).

## Decision

Bundle the `node_modules` tree by downloading the versioned npm tarball from
the npm registry in `debian/scripts/get-orig-source.sh` and unpacking it
in `debian/rules`.

The npm registry serves tarballs at a stable, versioned URL:
`https://registry.npmjs.org/@opentelemetry/auto-instrumentations-node/-/auto-instrumentations-node-<version>.tgz`.
The tarball is stored in the orig as
`upstream/nodejs/auto-instrumentations-node-<version>.tgz` and unpacked into
`/usr/lib/opentelemetry/nodejs/node_modules/@opentelemetry/auto-instrumentations-node/`
during the package build.

## Consequences

**Package size**: the Node.js package is the largest of the five, as it
contains the full transitive dependency tree.
This is acceptable for a PPA.

**Debian policy**: bundling a large `node_modules` tree violates Debian's
preference for using system-packaged libraries.
This is a known blocker for Ubuntu universe (see ADR-001), where all
dependencies must be separately packaged or have an approved exemption.

**Security updates**: a CVE in any transitive Node.js dependency requires
re-generating the orig tarball at a new version and re-uploading the source
package.
There is no mechanism for individual dependency updates short of a full rebuild.
This is consistent with how the Java agent JAR (which also bundles many
dependencies) is handled.

**npm registry availability**: `get-orig-source.sh` depends on the npm registry
being available when a maintainer runs it.
The orig tarball is the result of that fetch; the build itself has no npm
dependency.
