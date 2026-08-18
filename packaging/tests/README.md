# packaging/tests — integration tests against the LOCAL injector deb

Local, manual-only tests for the `opentelemetry-injector` DEB.
No CI wiring, no Go toolchain — plain shell + Docker, everything pinned to **this
repository's** .deb output.

## Where the injector deb comes from

Every scenario installs `opentelemetry-injector` from a local APT repo built
from `../opentelemetry-injector_*.deb` (the repo's parent directory by default,
overridable with `DEB_DIR`).  The deb is always the one produced by
`debian/rules` (Zig build from source) — never a remote download.

## Layout

| Folder | What it does |
|---|---|
| `metadata/` | Host-side `dpkg-deb` assertions (Provides virtual, file placement). No containers. |
| `lifecycle/` | Container: install/reinstall/remove/purge of `opentelemetry-injector`; `/etc/ld.so.preload` handling; conffile preservation. |

## Prerequisites

- The `.deb` files built by this repo (e.g. `dpkg-buildpackage -us -uc -b`
  after `debian/scripts/get-orig-source.sh`). They end up in the repo's parent
  directory by default; point `DEB_DIR` elsewhere if you keep them elsewhere.
- `dpkg-scanpackages` (in `dpkg-dev`) on the host.
- Docker for the lifecycle scenario (`metadata` needs no Docker).

## Usage

```sh
packaging/tests/run-all.sh            # = metadata + lifecycle
packaging/tests/run-all.sh metadata   # host-side only, no Docker
packaging/tests/run-all.sh lifecycle
```

Or individually:

```sh
packaging/tests/metadata/test-metadata.sh
packaging/tests/lifecycle/test-lifecycle-deb.sh
```

`build-local-repo.sh` is a prerequisite for the lifecycle scenario; the runner
and per-scenario scripts invoke it automatically. The generated repository lives
under `build/` (git-ignored).
