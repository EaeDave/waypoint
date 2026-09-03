#!/usr/bin/env bash
set -euo pipefail

repository="${WAYPOINT_GITHUB_REPOSITORY:-EaeDave/waypoint}"
release_base_url="${WAYPOINT_RELEASE_BASE_URL:-https://github.com/${repository}/releases/latest/download}"
archive_name="waypoint-linux-x86_64.tar.gz"
install_base="${WAYPOINT_INSTALL_PREFIX:-${HOME}/.local}"

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'Waypoint Linux installer can only run on Linux.\n' >&2
  exit 1
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
  printf 'Waypoint releases currently support Linux x86_64 only.\n' >&2
  exit 1
fi
for command in curl tar sha256sum install; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "${command}" >&2
    exit 1
  fi
done

work_directory="$(mktemp -d)"
staging_directory=""
cleanup() {
  rm -rf "${work_directory}"
  if [[ -n "${staging_directory}" ]]; then
    rm -rf "${staging_directory}"
  fi
}
trap cleanup EXIT

curl --fail --location --proto '=https' --tlsv1.2 \
  "${release_base_url}/${archive_name}" \
  --output "${work_directory}/${archive_name}"
curl --fail --location --proto '=https' --tlsv1.2 \
  "${release_base_url}/SHA256SUMS" \
  --output "${work_directory}/SHA256SUMS"
(
  cd "${work_directory}"
  sha256sum --check --ignore-missing SHA256SUMS
)

version="$(tar -xOf "${work_directory}/${archive_name}" ./usr/share/waypoint/VERSION)"
if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Release contains an invalid version: %s\n' "${version}" >&2
  exit 1
fi

install_root="${install_base}/lib/waypoint-${version}"
staging_directory="${install_root}.tmp.$$"
mkdir -p "${staging_directory}" "${install_base}/bin" "${install_base}/share/applications" \
  "${install_base}/share/icons/hicolor/scalable/apps" "${HOME}/.config/systemd/user"
tar -xzf "${work_directory}/${archive_name}" -C "${staging_directory}"
rm -rf "${install_root}"
mv "${staging_directory}" "${install_root}"
staging_directory=""
ln -sfn "waypoint-${version}" "${install_base}/lib/waypoint-current"

for executable in waypoint waypointd waypointctl; do
  ln -sfn "${install_base}/lib/waypoint-current/usr/bin/${executable}" \
    "${install_base}/bin/${executable}"
done
install -m 0644 "${install_root}/usr/share/applications/waypoint.desktop" \
  "${install_base}/share/applications/waypoint.desktop"
install -m 0644 "${install_root}/usr/share/icons/hicolor/scalable/apps/waypoint.svg" \
  "${install_base}/share/icons/hicolor/scalable/apps/waypoint.svg"
install -m 0644 "${install_root}/usr/share/systemd/user/waypointd.service" \
  "${HOME}/.config/systemd/user/waypointd.service"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${install_base}/share/applications" >/dev/null 2>&1 || true
fi
if command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload; then
  systemctl --user enable --now waypointd.service
else
  printf 'Could not start the user service. Run waypointd manually before opening Waypoint.\n' >&2
fi

plugin_source="${install_root}/usr/share/waypoint/omarchy-waypoint"
if [[ -d "${plugin_source}" ]] && command -v omarchy >/dev/null 2>&1; then
  plugin_target="${HOME}/.config/omarchy/plugins/io.waypoint.bar"
  mkdir -p "$(dirname "${plugin_target}")"
  ln -sfn "${plugin_source}" "${plugin_target}"
  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins || true
    omarchy plugin enable io.waypoint.bar || true
  fi
fi

printf 'Waypoint %s installed in %s.\n' "${version}" "${install_root}"
if [[ ":${PATH}:" != *":${install_base}/bin:"* ]]; then
  printf 'Add %s/bin to PATH before running waypoint.\n' "${install_base}"
fi
