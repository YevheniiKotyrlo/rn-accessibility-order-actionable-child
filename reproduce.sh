#!/usr/bin/env bash
# Exit 1 while the row that experimental_accessibilityOrder names is missing from the accessibility tree a screen
# reader reads (uiautomator dump --compressed), its texts taking its place, although the same row outside an order is
# a node of it; 0 once the ordered row is a node too; 2 when the row outside the order or the ordered row's texts are
# missing, or a step fails.
# Needs adb with one Android device attached (ANDROID_SERIAL picks one of several), node, yarn and a JDK.
set -u

package=com.reproducerapp
control="row without order"
ordered="row in order"
ordered_texts=("third text" "fourth text")

fail_step() {
    echo "step failed: $1"
    exit 2
}

# The path as the platform's own programs take it: Git Bash's /c/... becomes C:/... for adb on Windows.
native_path() {
    if command -v cygpath > /dev/null; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

# Sets the named variable to a device property, without the carriage return adb's shell ends it with.
read_device_property() {
    local value
    value="$(adb shell getprop "$2")" || fail_step "adb shell getprop $2: ${value}"
    printf -v "$1" '%s' "${value//$'\r'/}"
}

# dump_window [--compressed]: the window's accessibility tree. --compressed leaves out the views that are not
# important for accessibility and builds each node's children as a screen reader gets them.
dump_window() {
    adb shell uiautomator dump "$@" /sdcard/order-reproducer.xml > /dev/null 2>&1
    adb exec-out cat /sdcard/order-reproducer.xml 2> /dev/null
    adb shell rm -f /sdcard/order-reproducer.xml
}

# Starts the app afresh and waits for the ordered row's last text.
launch_app() {
    local attempt hierarchy
    adb shell am force-stop "${package}" > /dev/null || fail_step "adb shell am force-stop ${package}"
    adb shell am start -W -n "${package}/.MainActivity" > /dev/null || fail_step "starting ${package}"
    for ((attempt = 1; attempt <= 30; attempt += 1)); do
        hierarchy="$(dump_window)"
        [[ "${hierarchy}" == *"text=\"${ordered_texts[1]}\""* ]] && return 0
        sleep 1
    done
    fail_step "the app showed no \"${ordered_texts[1]}\""
}

# Prints each node of a dump that has a text or a content-desc, in tree order, indented by its depth.
print_nodes() {
    local hierarchy=$1 token depth=0 text desc
    local text_pattern=' text="([^"]*)"' desc_pattern='content-desc="([^"]*)"'
    hierarchy="${hierarchy//<node/$'\n'<node}"
    hierarchy="${hierarchy//<\/node>/$'\n'</node>}"
    while IFS= read -r token; do
        if [[ "${token}" == "<node"* ]]; then
            text=""
            desc=""
            [[ "${token}" =~ ${text_pattern} ]] && text="${BASH_REMATCH[1]}"
            [[ "${token}" =~ ${desc_pattern} ]] && desc="${BASH_REMATCH[1]}"
            if [[ -n "${text}${desc}" ]]; then
                printf '%*s%s\n' $((2 + 2 * depth)) '' "${desc:+content-desc \"${desc}\"}${text:+${desc:+, }text \"${text}\"}"
            fi
            [[ "${token}" == *"/>" ]] || depth=$((depth + 1))
        elif [[ "${token}" == "</node>"* ]]; then
            depth=$((depth - 1))
        fi
    done <<< "${hierarchy}"
}

check_tree() {
    local hierarchy
    launch_app
    hierarchy="$(dump_window --compressed)"
    [[ "${hierarchy}" == *"<hierarchy"* ]] || fail_step "uiautomator dump --compressed gave no tree"
    echo "== the accessibility tree a screen reader reads (uiautomator dump --compressed), nodes with a text or a label"
    print_nodes "${hierarchy}"

    if [[ "${hierarchy}" != *"content-desc=\"${control}\""* ]]; then
        echo "SUMMARY: inconclusive: \"${control}\", outside any order, is not a node either"
        exit 2
    fi
    local text
    for text in "${ordered_texts[@]}"; do
        if [[ "${hierarchy}" != *"text=\"${text}\""* ]]; then
            echo "SUMMARY: inconclusive: the ordered row's \"${text}\" is not a node"
            exit 2
        fi
    done
    if [[ "${hierarchy}" == *"content-desc=\"${ordered}\""* ]]; then
        echo "SUMMARY: \"${ordered}\", which the order names, is a node of the tree, as \"${control}\" is"
        exit 0
    fi
    echo "SUMMARY: \"${ordered}\", which the order names, is not a node of the tree, and its texts take its place;" \
        "\"${control}\", the same row outside an order, is a node"
    exit 1
}

main() {
    local here app
    here="$(cd "$(dirname "$0")" && pwd)"
    app="${here}/ReproducerApp"

    local system node_version java_version
    system="$(uname -sm)"
    node_version="$(node --version 2>&1)" || fail_step "node --version: ${node_version}"
    java_version="$(java -version 2>&1)" || fail_step "java -version: ${java_version}"
    echo "${system}, node ${node_version}, ${java_version%%$'\n'*}"

    local device_state
    device_state="$(adb get-state 2>&1)"
    [[ "${device_state}" == "device" ]] || fail_step "adb get-state: ${device_state}"
    local model release sdk abi
    read_device_property model ro.product.model
    read_device_property release ro.build.version.release
    read_device_property sdk ro.build.version.sdk
    read_device_property abi ro.product.cpu.abi
    echo "device: ${model}, Android ${release} (API ${sdk}), ${abi}"

    local install_output react_native_version
    install_output="$(cd "${app}" && yarn install --frozen-lockfile --non-interactive 2>&1)" ||
        { printf '%s\n' "${install_output}" | tail -n 20; fail_step "yarn install"; }
    react_native_version="$(cd "${app}" && node -p 'require("react-native/package.json").version' 2>&1)" ||
        fail_step "reading react-native's version: ${react_native_version}"
    echo "react-native ${react_native_version}, enableAccessibilityOrder on (MainApplication.kt)"

    echo "== ./gradlew :app:assembleRelease -PreactNativeArchitectures=${abi}"
    local build_output
    build_output="$(cd "${app}/android" && ./gradlew --no-daemon --console=plain :app:assembleRelease \
        "-PreactNativeArchitectures=${abi}" 2>&1)" ||
        { printf '%s\n' "${build_output}" | tail -n 40; fail_step "the release build"; }

    local apk install_result
    apk="$(native_path "${app}/android/app/build/outputs/apk/release/app-release.apk")"
    install_result="$(adb install -r "${apk}" 2>&1)" || fail_step "adb install: ${install_result}"

    check_tree
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
