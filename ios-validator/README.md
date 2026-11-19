# pluginval on iOS Simulator

This AU-only host runs pluginval’s existing strictness 1–3 tests from
`source/tests/BasicTests.cpp`. It scans the system Audio Unit registry, exercises
cold and warm opens, reads plug-in info and programs, saves and restores state,
and runs the audio processing and automation checks. The processing tests run at
44.1 and 48 kHz with 64- and 512-sample blocks. iOS hosts the installed AUv3 in a
separate extension process.

Build with CMake and Xcode. The app targets iOS 16 or later and uses the active
Xcode simulator SDK.

```sh
cmake -S . -B build-ios -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build build-ios --config Release --target pluginval_ios
```

Boot an iPhone or iPad simulator and install the candidate’s simulator `.app`
with its embedded AUv3 extension. Pass the simulator UDID, the validator app,
and the candidate’s registered Audio Unit selector. The example uses Gealach
Echo.

```sh
xcrun simctl install "$simulator_id" "$candidate_app"
validator='build-ios/ios-validator/pluginval_ios_artefacts/Release/pluginval iOS.app'
codesign --force --sign - "$validator"
python3 ios-validator/run-simulator.py "$simulator_id" "$validator" \
  'AudioUnit:Effects/aufx,Glch,Wsrm'
```

Pass `--device-set <path>` when the simulator is in a custom CoreSimulator
device set.

The app writes a JSON report to `Documents/pluginval-result.json`. The wrapper
prints the report and exits nonzero on a test failure, app exit, or timeout.
Use [the Swift host probe](../ios-probe/README.md) to check extension discovery
and editor presentation independently. The current validator target runs without
plugin editor tests or desktop validators such as `auval`.
