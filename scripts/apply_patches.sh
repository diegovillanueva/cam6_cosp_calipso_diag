#!/usr/bin/env bash
# Apply the COSP/CALIPSO/CloudSat and MG2 cloud-top diagnostic patches to a cam_cesm2_1_rel_60 checkout.
# Usage: scripts/apply_patches.sh [--on-minimal [--ctd]] /path/to/cesm2.1.5/components/cam
#   (default)     clean cam_cesm2_1_rel_60 checkout: patches/
#   --on-minimal  checkout that already carries the mg2_limiter_update v1.0.1 patches:
#                 patches/ with patches_on_minimal/micro_mg_cam.F90.patch in place of the standalone one
#   --ctd         with --on-minimal, also apply the cloud-top diagnostics module (patches_ctd/)
# The CAM directory must be the git checkout created by manage_externals/checkout_externals
# for release-cesm2.1.5 (tag cam_cesm2_1_rel_60, see versions.env).
set -euo pipefail

usage="usage: apply_patches.sh [--on-minimal [--ctd]] <CESM_ROOT>/components/cam"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
on_minimal=0
ctd=0
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --on-minimal) on_minimal=1 ;;
        --ctd) ctd=1 ;;
        *) echo "ERROR: unknown option $1; ${usage}" >&2; exit 1 ;;
    esac
    shift
done
cam="${1:?${usage}}"
if [[ "${ctd}" -eq 1 && "${on_minimal}" -eq 0 ]]; then
    echo "ERROR: --ctd needs --on-minimal (patches_ctd/ applies on top of mg2_limiter_update v1.0.1)" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "${repo}/versions.env"

cd "${cam}" || { echo "ERROR: ${cam} not found" >&2; exit 1; }
head="$(git rev-parse HEAD 2>/dev/null)" || {
    echo "ERROR: ${cam} is not a git checkout; run manage_externals/checkout_externals in CESM_ROOT" >&2; exit 1; }
if [[ "${head}" != "${CAM_COMMIT}" ]]; then
    echo "ERROR: CAM HEAD ${head} is not ${CAM_TAG} (${CAM_COMMIT})" >&2
    echo "Check out the tag: git -C ${cam} checkout ${CAM_TAG}" >&2
    exit 1
fi
if [[ "${on_minimal}" -eq 1 && ! -f src/physics/cam/micro_dv_nml.F90 ]]; then
    echo "ERROR: --on-minimal needs the mg2_limiter_update ${MG2_LIMITER_TAG} patches applied first" >&2
    exit 1
fi

patches=()
for p in "${repo}"/patches/*.patch; do
    if [[ "${on_minimal}" -eq 1 && "$(basename "${p}")" == "micro_mg_cam.F90.patch" ]]; then
        p="${repo}/patches_on_minimal/micro_mg_cam.F90.patch"
    fi
    patches+=("${p}")
done

git apply --check "${patches[@]}" || {
    echo "ERROR: patches do not apply; check the state of the CAM tree (git -C ${cam} status)" >&2; exit 1; }
git apply --whitespace=nowarn "${patches[@]}"
if [[ "${ctd}" -eq 1 ]]; then
    git apply --check "${repo}"/patches_ctd/*.patch || {
        echo "ERROR: patches_ctd do not apply; the patches/ set was applied, patches_ctd/ was not" >&2; exit 1; }
    git apply --whitespace=nowarn "${repo}"/patches_ctd/*.patch
fi
echo "Patched files:"
git status --short
