#!/usr/bin/env bash
set -euo pipefail

probe_dir=$(cd "$(dirname "$0")" && pwd)
out_app=${1:?usage: ios-probe/build.sh /path/to/PluginvalHostProbe.app}
module_cache=$(mktemp -d "${TMPDIR:-/tmp}/pluginval-probe-modules.XXXXXX")
trap 'rm -rf "$module_cache"' EXIT
mkdir -p "$out_app"
cp "$probe_dir/Info.plist" "$out_app/Info.plist"
xcrun --sdk iphonesimulator swiftc -parse-as-library -module-cache-path "$module_cache" \
  -target "$(uname -m)-apple-ios16.0-simulator" \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  "$probe_dir/HostProbe.swift" -o "$out_app/PluginvalHostProbe"
codesign --force --sign - "$out_app"
