#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIRECTORY}/.." && pwd)"
ACTUAL_ROOT="$(git -C "${PROJECT_ROOT}" rev-parse --show-toplevel)"

if [[ "${ACTUAL_ROOT}" != "${PROJECT_ROOT}" ]]; then
    echo "Release build failed: expected repository root ${PROJECT_ROOT}, found ${ACTUAL_ROOT}." >&2
    exit 1
fi

VERSION="$(sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*//p' "${PROJECT_ROOT}/project.yml" | tr -d '"')"
BUILD_NUMBER="$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*//p' "${PROJECT_ROOT}/project.yml" | tr -d '"')"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Release build failed: MARKETING_VERSION must be a semantic version; found ${VERSION}." >&2
    exit 1
fi

if [[ ! "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    echo "Release build failed: CURRENT_PROJECT_VERSION must be an integer; found ${BUILD_NUMBER}." >&2
    exit 1
fi

RELEASE_TEMP_DIRECTORY="$(mktemp -d /tmp/SystemProfilerExplorer.release.XXXXXX)"

if [[ "${RELEASE_TEMP_DIRECTORY}" != /tmp/SystemProfilerExplorer.release.* ]]; then
    echo "Release build failed: temporary directory is outside the expected release namespace." >&2
    exit 1
fi

cleanup() {
    rm -rf -- "${RELEASE_TEMP_DIRECTORY}"
}

trap cleanup EXIT

DERIVED_DATA_DIRECTORY="${RELEASE_TEMP_DIRECTORY}/DerivedData"
STAGING_DIRECTORY="${RELEASE_TEMP_DIRECTORY}/staging"
BUILT_APP="${DERIVED_DATA_DIRECTORY}/Build/Products/Release/SystemProfilerExplorer.app"
STAGED_APP="${STAGING_DIRECTORY}/SystemProfilerExplorer.app"
EXECUTABLE="${STAGED_APP}/Contents/MacOS/SystemProfilerExplorer"
INFO_PLIST="${STAGED_APP}/Contents/Info.plist"
DIST_DIRECTORY="${PROJECT_ROOT}/dist"
ARCHIVE_NAME="SystemProfilerExplorer-${VERSION}-macOS-universal.zip"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"
ARCHIVE_PATH="${DIST_DIRECTORY}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${DIST_DIRECTORY}/${CHECKSUM_NAME}"

cd "${PROJECT_ROOT}"

"${SCRIPT_DIRECTORY}/check-publication-boundary.sh"

xcodebuild \
    -project SystemProfilerExplorer.xcodeproj \
    -scheme SystemProfilerExplorer \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_DIRECTORY}" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    test

xcodebuild \
    -project SystemProfilerExplorer.xcodeproj \
    -scheme SystemProfilerExplorer \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_DIRECTORY}" \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    build

if [[ ! -d "${BUILT_APP}" ]]; then
    echo "Release build failed: expected application bundle was not created at ${BUILT_APP}." >&2
    exit 1
fi

mkdir -p -- "${STAGING_DIRECTORY}" "${DIST_DIRECTORY}"
ditto "${BUILT_APP}" "${STAGED_APP}"
codesign --force --sign - --timestamp=none "${STAGED_APP}"

plutil -lint "${INFO_PLIST}" >/dev/null
codesign --verify --deep --strict --verbose=2 "${STAGED_APP}"

ARCHITECTURES="$(lipo -archs "${EXECUTABLE}")"

if [[ " ${ARCHITECTURES} " != *" arm64 "* || " ${ARCHITECTURES} " != *" x86_64 "* ]]; then
    echo "Release build failed: expected arm64 and x86_64 slices; found ${ARCHITECTURES}." >&2
    exit 1
fi

BUNDLE_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "${INFO_PLIST}")"
BUNDLE_BUILD="$(plutil -extract CFBundleVersion raw -o - "${INFO_PLIST}")"
MINIMUM_SYSTEM_VERSION="$(plutil -extract LSMinimumSystemVersion raw -o - "${INFO_PLIST}")"

if [[ "${BUNDLE_VERSION}" != "${VERSION}" ]]; then
    echo "Release build failed: bundle version ${BUNDLE_VERSION} does not match ${VERSION}." >&2
    exit 1
fi

if [[ "${BUNDLE_BUILD}" != "${BUILD_NUMBER}" ]]; then
    echo "Release build failed: bundle build ${BUNDLE_BUILD} does not match ${BUILD_NUMBER}." >&2
    exit 1
fi

if [[ "${MINIMUM_SYSTEM_VERSION}" != "13.0" ]]; then
    echo "Release build failed: expected macOS 13.0 minimum; found ${MINIMUM_SYSTEM_VERSION}." >&2
    exit 1
fi

rm -f -- "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${STAGED_APP}" "${ARCHIVE_PATH}"

(
    cd "${DIST_DIRECTORY}"
    shasum -a 256 "${ARCHIVE_NAME}" > "${CHECKSUM_NAME}"
)

echo "Release archive: ${ARCHIVE_PATH}"
echo "Checksum file: ${CHECKSUM_PATH}"
echo "Architectures: ${ARCHITECTURES}"
echo "Minimum macOS: ${MINIMUM_SYSTEM_VERSION}"
echo "Version: ${BUNDLE_VERSION} (${BUNDLE_BUILD})"
echo "Signature: ad hoc; Developer ID signing and notarization are required before public distribution."
