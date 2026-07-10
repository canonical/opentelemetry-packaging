# ADR-002: Name the source package `opentelemetry`

Date: 2026-07-02
Status: Accepted

## Context

A Debian source package produces one or more binary packages.
The source package name and the binary package names are independent.
We needed to choose a name for the source package that produces the five binary
packages (`opentelemetry`, `opentelemetry-injector`, etc.).

Two options were considered:

**`opentelemetry-packaging`** — mirrors the upstream repository name
(`open-telemetry/opentelemetry-packaging`) and follows a convention sometimes
used in Debian/Ubuntu when a source tree contains only packaging metadata
rather than upstream software.
Examples: `fonts-noto-packaging`, `golang-packaging`.

**`opentelemetry`** — names the source package after the primary user-facing
binary package it produces.
This is the standard Debian convention: the source package for `nginx` is
`nginx`, not `nginx-packaging`.
It means users can run `apt-get source opentelemetry` to retrieve the packaging
source, which is the most intuitive behaviour.

## Decision

Name the source package `opentelemetry`.

The primary goal of this packaging effort is to allow users to run
`apt install opentelemetry`.
Naming the source package `opentelemetry` makes the relationship between the
source and the main binary package obvious, follows standard Debian convention,
and makes `apt-get source opentelemetry` work intuitively.

## Consequences

If the upstream `open-telemetry/opentelemetry-packaging` project ever publishes
its own source package to Debian or Ubuntu under the name `opentelemetry`, a
name conflict would arise.
This is unlikely in the short term — the upstream project uses nfpm rather than
the Debian toolchain — but should be monitored.

If that conflict materialises, renaming the source package to
`opentelemetry-canonical` or similar would be straightforward: it requires
updating `debian/control` and `debian/changelog`, and bumping the package
version.
Binary package names (`opentelemetry`, `opentelemetry-injector`, etc.) would
remain unchanged.
