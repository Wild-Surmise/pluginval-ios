# iOS AUv3 host probe

This simulator app verifies that a separately installed AUv3 appears in the
Audio Toolbox registry, instantiates out of process, and supplies an editor
view controller. It is a starting point for bringing pluginval’s tests to iOS.

With a booted iPhone or iPad simulator and the candidate AUv3’s containing app
installed on that simulator, build and launch the probe. The three arguments
are the component type, subtype, and manufacturer, in that order. The example
uses Gealach Echo.

```sh
app=$(mktemp -d)/PluginvalHostProbe.app
ios-probe/build.sh "$app"
xcrun simctl install "$simulator_id" "$app"
xcrun simctl launch "$simulator_id" com.wildsurmise.pluginval-ios.probe aufx Glch Wsrm
data=$(xcrun simctl get_app_container "$simulator_id" com.wildsurmise.pluginval-ios.probe data)
cat "$data/Documents/probe-result.json"
```

The result appears after the extension returns its editor. Use a fresh
installation of the probe for each attempt so the result is from that launch.
