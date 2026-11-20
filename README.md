# Android: a row that `experimental_accessibilityOrder` names drops out of the accessibility tree when it is actionable but not focusable

React Native 0.90.0-nightly-20261120-bbfd39149, from the [React Native reproducer template](https://github.com/react-native-community/reproducer-react-native). `MainApplication.kt` turns on the `enableAccessibilityOrder` feature flag, which the canary and experimental flags turn on. `ReproducerApp/App.tsx` renders two identical rows: a `View` with `accessible={false}`, an `accessibilityLabel` and the `activate` accessibility action, holding two texts.

- "row without order" sits in a plain container;
- "row in order" sits in a container whose `experimental_accessibilityOrder` is `['row-in-order']`, the row's `nativeID`.

Both rows should be nodes of the accessibility tree, as React Native's accessibility delegate takes a view that offers the click action as an accessibility element.

## Steps

1. Build and install the release APK: `cd ReproducerApp && yarn install && cd android && ./gradlew assembleRelease && adb install -r app/build/outputs/apk/release/app-release.apk`.
2. Open the app and read the tree a screen reader gets: `adb shell uiautomator dump --compressed /sdcard/tree.xml && adb exec-out cat /sdcard/tree.xml`.
3. "row without order" is a node holding "first text" and "second text". "row in order" is not a node: "third text" and "fourth text" sit directly in its container.

Scripted: `./reproduce.sh`, with one Android device attached, builds and installs the app, starts it and prints the nodes with a text or a label from `uiautomator dump --compressed`. It exits 1 while "row in order" is missing and its texts take its place although "row without order" is a node, 0 once "row in order" is a node too, and 2 when "row without order" or the ordered row's texts are missing, or a step fails.
