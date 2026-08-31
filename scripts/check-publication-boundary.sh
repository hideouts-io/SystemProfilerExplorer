#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIRECTORY}/.." && pwd)"
ACTUAL_ROOT="$(git -C "${PROJECT_ROOT}" rev-parse --show-toplevel)"

if [[ "${ACTUAL_ROOT}" != "${PROJECT_ROOT}" ]]; then
    echo "Publication check failed: expected repository root ${PROJECT_ROOT}, found ${ACTUAL_ROOT}." >&2
    exit 1
fi

FORBIDDEN_PATHS_FILE="$(mktemp)"
CANDIDATE_FILES_FILE="$(mktemp)"
USER_PATHS_FILE="$(mktemp)"
PRIVATE_KEYS_FILE="$(mktemp)"

cleanup() {
    rm -f -- \
        "${FORBIDDEN_PATHS_FILE}" \
        "${CANDIDATE_FILES_FILE}" \
        "${USER_PATHS_FILE}" \
        "${PRIVATE_KEYS_FILE}"
}

trap cleanup EXIT

cd "${PROJECT_ROOT}"

git ls-files --cached --others --exclude-standard -z > "${CANDIDATE_FILES_FILE}"

while IFS= read -r -d '' file_path; do
    file_name="$(basename -- "${file_path}")"
    lowercase_file_name="$(printf '%s' "${file_name}" | tr '[:upper:]' '[:lower:]')"

    case "/${file_path}/" in
        */LocalReports/*|*/LocalSnapshots/*|*/DerivedData/*|*/build/*|*/.build/*|*/.codex/*|*/xcuserdata/*)
            printf '%s\n' "${file_path}" >> "${FORBIDDEN_PATHS_FILE}"
            continue
            ;;
    esac

    case "${file_name}" in
        *.spx|*.system-profiler.json|System-Profiler-*.json|*.xcuserstate|.DS_Store)
            printf '%s\n' "${file_path}" >> "${FORBIDDEN_PATHS_FILE}"
            ;;
    esac

    if [[ "${lowercase_file_name}" == "memory.md" ]]; then
        printf '%s\n' "${file_path}" >> "${FORBIDDEN_PATHS_FILE}"
    fi
done < "${CANDIDATE_FILES_FILE}"

if [[ -s "${FORBIDDEN_PATHS_FILE}" ]]; then
    echo "Publication check failed: private or generated artifacts are present:" >&2
    sort -u "${FORBIDDEN_PATHS_FILE}" >&2
    exit 1
fi

scan_pattern() {
    local pattern="$1"
    local output_file="$2"
    local file_path
    local grep_status

    while IFS= read -r -d '' file_path; do
        set +e
        grep -InI -E "${pattern}" "${file_path}" >> "${output_file}"
        grep_status=$?
        set -e

        if [[ ${grep_status} -ne 0 && ${grep_status} -ne 1 ]]; then
            echo "Publication check failed: could not inspect ${file_path}." >&2
            exit 1
        fi
    done < "${CANDIDATE_FILES_FILE}"
}

scan_pattern '/(Users)/[^/]+/|/var/(folders)/' "${USER_PATHS_FILE}"
scan_pattern 'BEGIN[[:space:]].*PRIVATE[[:space:]]KEY' "${PRIVATE_KEYS_FILE}"

if [[ -s "${USER_PATHS_FILE}" ]]; then
    echo "Publication check failed: absolute user-specific paths were found:" >&2
    cat "${USER_PATHS_FILE}" >&2
    exit 1
fi

if [[ -s "${PRIVATE_KEYS_FILE}" ]]; then
    echo "Publication check failed: private-key material was found:" >&2
    cat "${PRIVATE_KEYS_FILE}" >&2
    exit 1
fi

echo "Publication boundary check passed."
