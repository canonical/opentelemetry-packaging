# versions.mk — pinned upstream component versions
#
# To upgrade a component:
#   1. Update the version here.
#   2. Run debian/scripts/get-orig-source.sh to download the new artifacts and
#      regenerate opentelemetry_<SUITE_VERSION>.orig.tar.gz.
#   3. Bump the Debian revision in debian/changelog (e.g. -0ubuntu1 ->
#      -0ubuntu2), or bump SUITE_VERSION if this is a new upstream release.
#   4. Rebuild with dpkg-buildpackage -us -uc.

# Suite version — the upstream version field in debian/changelog.
# Increment the patch when any component version changes.
SUITE_VERSION := 0.1.0

# opentelemetry-injector
# https://github.com/open-telemetry/opentelemetry-injector/releases
INJECTOR_VERSION := 0.9.0

# opentelemetry-java-instrumentation
# https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases
JAVA_VERSION := 2.29.0

# @opentelemetry/auto-instrumentations-node (npm)
# https://www.npmjs.com/package/@opentelemetry/auto-instrumentations-node
NODEJS_VERSION := 0.77.0

# opentelemetry-dotnet-instrumentation
# https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases
DOTNET_VERSION := 1.15.0
