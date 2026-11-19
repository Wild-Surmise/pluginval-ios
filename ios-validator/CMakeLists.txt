juce_add_gui_app(pluginval_ios
    PRODUCT_NAME "pluginval iOS"
    BUNDLE_ID com.wildsurmise.pluginval-ios
    COMPANY_NAME "Wild Surmise"
    TARGETED_DEVICE_FAMILY "1,2"
    PLIST_TO_MERGE [[
        <plist version="1.0"><dict>
            <key>UIApplicationSceneManifest</key>
            <dict><key>UIApplicationSupportsMultipleScenes</key><false/></dict>
            <key>UILaunchScreen</key><dict/>
        </dict></plist>]])

target_sources(pluginval_ios PRIVATE
    Main.cpp
    ../source/PluginTests.cpp
    ../source/TestUtilities.cpp
    ../source/tests/BasicTests.cpp)

target_compile_features(pluginval_ios PRIVATE cxx_std_20)
target_compile_definitions(pluginval_ios PRIVATE
    JUCE_PLUGINHOST_AU=1
    JUCE_USE_CURL=0
    JUCE_WEB_BROWSER=0
    PLUGINVAL_IOS_VERSION="${PROJECT_VERSION}")
target_link_libraries(pluginval_ios PRIVATE juce::juce_audio_processors)
