#!/bin/bash
set -uo pipefail

BASE_DIR="${HELMREPO_MOUNT_PATH}/artifact/api/v1"

mkdir -p "${BASE_DIR}"

echo "Starting helm repo index watcher, scanning ${BASE_DIR} for helm-local* repos"

# tgz filename + mtime for one repo dir — catches new files AND overwrites with same name
get_tgz_state() {
    local dir="$1"
    for f in "${dir}"/*.tgz; do
        [ -f "$f" ] || continue
        stat -c "%n %Y" "$f"
    done | sort
}

# State is persisted in a hidden file inside the repo's own directory, so it survives
# watcher restarts and each repo is tracked independently. helm repo index only globs
# *.tgz files, so a dotfile here is never picked up as a chart package.
process_repo() {
    local repo_dir="$1"
    local state_file="${repo_dir}/.tgzstate"

    local current
    current="$(get_tgz_state "${repo_dir}")"

    # If index.yaml itself is missing (first run, or removed/corrupted externally),
    # always (re)index regardless of the tgz state bookkeeping below.
    if [ ! -f "${repo_dir}/index.yaml" ]; then
        echo "No index.yaml found for ${repo_dir}, generating helm repo index"
        if helm repo index "${repo_dir}"; then
            echo "${current}" > "${state_file}"
            echo "helm repo index generated for ${repo_dir}"
        else
            echo "ERROR: helm repo index failed for ${repo_dir}"
        fi
        return
    fi

    local known=""
    [ -f "${state_file}" ] && known="$(cat "${state_file}")"

    if [ "${current}" != "${known}" ]; then
        echo "Change detected in ${repo_dir}, regenerating helm repo index"
        if helm repo index "${repo_dir}"; then
            echo "${current}" > "${state_file}"
            echo "helm repo index updated for ${repo_dir}"
        else
            echo "ERROR: helm repo index failed for ${repo_dir}"
        fi
    fi
}

while true; do
    for repo_dir in "${BASE_DIR}"/helm-local*; do
        [ -d "${repo_dir}" ] || continue
        process_repo "${repo_dir}"
    done
    sleep 5
done
