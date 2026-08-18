#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PACKAGE="xgc2-field-panel"
ARCHITECTURE="${ARCHITECTURE:-all}"
OUTPUT_DIR=""
ROS_PREFIXES=(/opt/ros/melodic /opt/ros/noetic)

product_version() {
  # mawk (bionic) does not implement POSIX [[:space:]].
  awk '/^version:/ {print $2; exit}' "${REPO_ROOT}/.xgc2/product.yml"
}

VERSION="${PACKAGE_VERSION:-$(product_version)}"
if [[ -z "${VERSION}" ]]; then
  echo "cannot read version from .xgc2/product.yml" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ${0##*/} --output-dir DIR" >&2
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${OUTPUT_DIR}" ]]; then
  echo "--output-dir is required" >&2
  exit 2
fi

BUILD_DIR="$(mktemp -d)"
cleanup() { rm -rf "${BUILD_DIR}"; }
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_DIR}/${PACKAGE}_"*.deb

src="${REPO_ROOT}/xgc2_field_panel"
pkg_root="${BUILD_DIR}/${PACKAGE}"
mkdir -p "${pkg_root}/DEBIAN" "${pkg_root}/usr/share/doc/${PACKAGE}"

for prefix in "${ROS_PREFIXES[@]}"; do
  share="${pkg_root}${prefix}/share/xgc2_field_panel"
  lib="${pkg_root}${prefix}/lib/xgc2_field_panel"
  mkdir -p "${share}/launch" "${share}/web" "${lib}"
  install -m 0644 "${src}/package.xml" "${share}/package.xml"
  install -m 0644 "${src}/launch/panel.launch" "${share}/launch/panel.launch"
  install -m 0644 "${src}/web/index.html" "${share}/web/index.html"
  install -m 0755 "${src}/scripts/field_panel_node" "${lib}/field_panel_node"
  if [[ "${prefix}" == *melodic ]]; then
    sed -i '1s|^#!.*|#!/usr/bin/env python|' "${lib}/field_panel_node"
  fi
done

cat > "${pkg_root}/usr/share/doc/${PACKAGE}/README" <<EOF
${PACKAGE}

Onboard field Web panel. Starts or stops roslaunch. Official ROS messages only.
EOF
chmod 0644 "${pkg_root}/usr/share/doc/${PACKAGE}/README"
install -m 0644 "${REPO_ROOT}/LICENSE" "${pkg_root}/usr/share/doc/${PACKAGE}/copyright"

installed_size="$(du -sk "${pkg_root}" | awk '{print $1}')"
cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${PACKAGE}
Version: ${VERSION}
Section: misc
Priority: optional
Architecture: ${ARCHITECTURE}
Installed-Size: ${installed_size}
Maintainer: XGC2 <apt@example.com>
Depends: python3
Recommends: ros-melodic-rospy | ros-noetic-rospy, ros-melodic-roslaunch | ros-noetic-roslaunch, ros-melodic-geometry-msgs | ros-noetic-geometry-msgs, ros-melodic-std-msgs | ros-noetic-std-msgs, ros-melodic-sensor-msgs | ros-noetic-sensor-msgs
Description: XGC2 onboard field Web panel
 Process helper for roslaunch on the robot. Does not Depend on vehicle or
 algorithm packages.
EOF
chmod 0644 "${pkg_root}/DEBIAN/control"

find "${pkg_root}" -type d -exec chmod 0755 {} +
chmod 0755 "${pkg_root}/DEBIAN"
for prefix in "${ROS_PREFIXES[@]}"; do
  chmod 0755 "${pkg_root}${prefix}/lib/xgc2_field_panel/field_panel_node"
done

fakeroot dpkg-deb --build \
  "${pkg_root}" \
  "${OUTPUT_DIR}/${PACKAGE}_${VERSION}_all.deb" >/dev/null

find "${OUTPUT_DIR}" -maxdepth 1 -type f -name '*.deb' -print | sort
