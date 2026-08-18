#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_IMAGE=""
OUTPUT_DIR="${REPO_ROOT}/debs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) DOCKER_IMAGE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "${DOCKER_IMAGE}" ]]; then
  echo "--image is required" >&2
  exit 2
fi

mkdir -p "${OUTPUT_DIR}"
docker pull "${DOCKER_IMAGE}"

docker run --rm --network none \
  -e DEBIAN_FRONTEND=noninteractive \
  -v "${REPO_ROOT}:/workspace/src:ro" \
  -v "${OUTPUT_DIR}:/workspace/out" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail
    command -v python3 >/dev/null
    command -v dpkg-deb >/dev/null
    export PYTHONDONTWRITEBYTECODE=1
    bash -n /workspace/src/.xgc2/scripts/package_debs.sh
    bash -n /workspace/src/.xgc2/scripts/check_installed_packages.sh
    python3 /workspace/src/xgc2_field_panel/test/test_layout.py
    /workspace/src/.xgc2/scripts/package_debs.sh --output-dir /workspace/out
    shopt -s nullglob
    built_debs=(/workspace/out/*.deb)
    shopt -u nullglob
    if [[ "${#built_debs[@]}" -ne 1 ]]; then
      echo "expected 1 field-panel deb, found ${#built_debs[@]}" >&2
      ls -la /workspace/out >&2 || true
      exit 1
    fi
    /workspace/src/.xgc2/scripts/check_installed_packages.sh --deb-dir /workspace/out
    echo "ci_in_image ok $(python3 --version) $(uname -m)"
  '
