# versions.mk — pinned upstream component versions
#
# To upgrade a component:
#   1. Update the version here.
#   2. Run debian/scripts/get-orig-source.sh to download the new artifacts and
#      regenerate opentelemetry-injector_<SUITE_VERSION>.orig.tar.gz.
#   3. Bump the Debian revision in debian/changelog (e.g. -0ubuntu1 ->
#      -0ubuntu2), or bump SUITE_VERSION if this is a new upstream release.
#   4. Rebuild with dpkg-buildpackage -us -uc.

# Suite version — the upstream version field in debian/changelog.
# Increment when the injector version changes.
SUITE_VERSION := 0.1.0

# opentelemetry-injector
# https://github.com/open-telemetry/opentelemetry-injector/releases
INJECTOR_VERSION := 0.9.0
