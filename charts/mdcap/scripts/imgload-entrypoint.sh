#!/bin/bash
set -uo pipefail

IMAGES_DIR="${IMGLOAD_MOUNT_PATH}/artifact/api/v1/imgload"
DONE_DIR="${IMAGES_DIR}/.loaded"
TMP_DIR="${IMAGES_DIR}/.tmp"
REGISTRY_ADDR="localhost:5000"

mkdir -p "${IMAGES_DIR}" "${DONE_DIR}" "${TMP_DIR}"

echo "Starting image loader, watching ${IMAGES_DIR}"

# Each release is an immutable pair, uploaded as:
#   <name>-<tag>.tar.gz  — docker save | gzip archive
#   <name>-<tag>.txt     — newline separated list of image:tag refs bundled in the archive
# Once a <name>-<tag> has been successfully loaded, a marker in DONE_DIR skips it on future scans.
process_version() {
    local tarfile="$1"
    local base textfile marker tmptar

    base=$(basename "${tarfile}" .tar.gz)
    textfile="${IMAGES_DIR}/${base}.txt"
    marker="${DONE_DIR}/${base}.done"

    [ -f "${marker}" ] && return

    if [ ! -f "${textfile}" ]; then
        echo "WARNING: Missing companion file ${textfile} for ${tarfile}, skipping for now"
        return
    fi

    echo "Loading images ${base} from ${tarfile}"

    # docker-archive source requires a seekable (uncompressed) file for efficient
    # per-image random access. Decompress once on the PVC (not /tmp, which may be
    # a small node-local or memory-backed filesystem) and reuse it for every tag.
    tmptar="${TMP_DIR}/${base}.tar"
    if ! gunzip -c "${tarfile}" > "${tmptar}"; then
        echo "ERROR: Failed to decompress ${tarfile}"
        rm -f "${tmptar}"
        return
    fi

    local failed=0
    while IFS= read -r tag || [ -n "${tag}" ]; do
        [ -z "${tag}" ] && continue
        echo "${tag}" | grep -Eq "^\s*#" && continue
        tag=$(echo "${tag}" | xargs)

        echo "Pushing ${tag} -> ${REGISTRY_ADDR}/${tag}"
        if ! skopeo copy "docker-archive:${tmptar}:${tag}" "docker://${REGISTRY_ADDR}/${tag}" --dest-tls-verify=false; then
            echo "ERROR: Failed to push ${tag}"
            failed=1
        fi
    done < "${textfile}"

    rm -f "${tmptar}"

    if [ "${failed}" -eq 0 ]; then
        touch "${marker}"
        echo "Successfully loaded images ${base}"
    else
        echo "One or more images failed for ${base}, will retry next scan"
    fi
}

while true; do
    for tarfile in "${IMAGES_DIR}"/*.tar.gz; do
        [ -f "${tarfile}" ] || continue
        process_version "${tarfile}"
    done
    sleep 30
done
