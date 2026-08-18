#!/usr/bin/env bash
set -euo pipefail

PACKAGE="xgc2-field-panel"
DEB_DIR=""
DEB_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deb-dir) DEB_DIR="$2"; shift 2 ;;
    --deb) DEB_PATH="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "${DEB_DIR}" && -z "${DEB_PATH}" ]]; then
  echo "--deb-dir or --deb is required" >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "${tmp_dir}"; }
trap cleanup EXIT

find_deb() {
  if [[ -n "${DEB_PATH}" ]]; then
    printf '%s\n' "${DEB_PATH}"
    return 0
  fi
  local match="" path
  shopt -s nullglob
  for path in "${DEB_DIR}"/*.deb; do
    if dpkg-deb --field "${path}" Package | grep -Fxq "${PACKAGE}"; then
      match="${path}"
    fi
  done
  shopt -u nullglob
  if [[ -z "${match}" ]]; then
    echo "missing ${PACKAGE}" >&2
    return 1
  fi
  printf '%s\n' "${match}"
}

deb="$(find_deb)"
dpkg-deb --field "${deb}" Architecture | grep -Fx all >/dev/null
dpkg-deb --field "${deb}" Depends | grep -F "python3" >/dev/null
if dpkg-deb --field "${deb}" Depends | grep -Ei 'xgc2-|unicycle|agilex|estimator'; then
  echo "Debian Depends must not name first-party algorithm packages" >&2
  exit 1
fi

mkdir -p "${tmp_dir}/root"
dpkg-deb --extract "${deb}" "${tmp_dir}/root"

for prefix in /opt/ros/melodic /opt/ros/noetic; do
  test -x "${tmp_dir}/root${prefix}/lib/xgc2_field_panel/field_panel_node"
  test -f "${tmp_dir}/root${prefix}/share/xgc2_field_panel/package.xml"
  test -f "${tmp_dir}/root${prefix}/share/xgc2_field_panel/launch/panel.launch"
  test -f "${tmp_dir}/root${prefix}/share/xgc2_field_panel/web/index.html"
  grep -q 'pkg="xgc2_field_panel"' \
    "${tmp_dir}/root${prefix}/share/xgc2_field_panel/launch/panel.launch"
done

if find "${tmp_dir}/root/lib/systemd/system" -maxdepth 1 -name '*.service' \
  2>/dev/null | grep -q .; then
  echo "field panel must not ship a systemd unit" >&2
  exit 1
fi

echo "Package content check passed"
