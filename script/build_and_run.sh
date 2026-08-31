#!/usr/bin/env bash

set -euo pipefail

APP_NAME="SystemProfilerExplorer"
BUNDLE_IDENTIFIER="com.netctl.SystemProfilerExplorer"
PROJECT_NAME="SystemProfilerExplorer.xcodeproj"
SCHEME_NAME="SystemProfilerExplorer"
PROCESS_NAME="SystemProfilerExplorer"
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIRECTORY="${PROJECT_ROOT}/.build/RunDerivedData"
APP_BUNDLE="${DERIVED_DATA_DIRECTORY}/Build/Products/Debug/${APP_NAME}.app"
APP_BINARY="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

if [[ $# -eq 0 ]]; then
    MODE="run"
elif [[ $# -eq 1 ]]; then
    MODE="$1"
else
    echo "Usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
fi

if pgrep -x "${PROCESS_NAME}" >/dev/null; then
    pkill -TERM -x "${PROCESS_NAME}"
fi

xcodebuild \
    -project "${PROJECT_ROOT}/${PROJECT_NAME}" \
    -scheme "${SCHEME_NAME}" \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_DIRECTORY}" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    build

if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "Build succeeded without creating the expected app bundle at ${APP_BUNDLE}." >&2
    exit 1
fi

codesign --force --sign - --timestamp=none "${APP_BUNDLE}"

open_app() {
    /usr/bin/open -n "${APP_BUNDLE}"
}

case "${MODE}" in
    run)
        open_app
        ;;
    --debug|debug)
        exec lldb -- "${APP_BINARY}"
        ;;
    --logs|logs)
        open_app
        exec /usr/bin/log stream --info --style compact --predicate "process == \"${PROCESS_NAME}\""
        ;;
    --telemetry|telemetry)
        open_app
        exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"${BUNDLE_IDENTIFIER}\""
        ;;
    --verify|verify)
        open_app
        sleep 2

        if ! pgrep -x "${PROCESS_NAME}" >/dev/null; then
            echo "${APP_NAME} did not remain running after launch." >&2
            exit 1
        fi

        echo "${APP_NAME} is running."
        ;;
    *)
        echo "Usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
