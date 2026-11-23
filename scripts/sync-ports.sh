#!/usr/bin/env bash
# Scans all ports/*/ in this vcpkg registry, checks upstream GitHub repos for
# newer tags, updates vcpkg.json + portfile.cmake, and runs `vcpkg x-add-version --all`.
# Run from the root of the registry repository (locally or via GitHub Actions).

set -euo pipefail

updated=0

for port_dir in ports/*/; do
  port_name="$(basename "$port_dir")"
  portfile="${port_dir}portfile.cmake"
  manifest="${port_dir}vcpkg.json"

  [[ -f "$portfile" && -f "$manifest" ]] || continue

  # 1. Extract non-commented REPO owner/name from vcpkg_from_github(...)
  repo="$(grep -E '^[[:space:]]*REPO[[:space:]]+' "$portfile" | awk '{print $2}' | head -n1 || true)"
  [[ -n "$repo" ]] || continue

  # Skip ports that do not have active REF and SHA512 lines (e.g. HEAD-only ports)
  if ! grep -qE '^[[:space:]]*REF[[:space:]]+' "$portfile" || ! grep -qE '^[[:space:]]*SHA512[[:space:]]+' "$portfile"; then
    echo "[${port_name}] skipped (missing active REF or SHA512 in portfile.cmake)"
    continue
  fi

  # 2. Fetch the latest tag from the upstream GitHub repository
  latest_tag="$(git ls-remote --tags --refs --sort=-v:refname "https://github.com/${repo}.git" \
    | head -n1 | sed 's|.*refs/tags/||')"
  [[ -n "$latest_tag" ]] || continue

  latest_ver="${latest_tag#v}"
  current_ver="$(jq -r '.version // .["version-semver"] // .["version-string"] // empty' "$manifest")"

  if [[ "$latest_ver" == "$current_ver" ]]; then
    echo "[${port_name}] up to date (${current_ver})"
    continue
  fi

  echo "[${port_name}] ${current_ver} -> ${latest_ver} (${repo}@${latest_tag})"

  # 3. Compute SHA512 of the GitHub tag archive
  tarball_url="https://github.com/${repo}/archive/refs/tags/${latest_tag}.tar.gz"
  sha512="$(curl -fsSL "$tarball_url" | sha512sum | awk '{print $1}')"

  # 4. Update vcpkg.json (reset port-version on upstream version bump) and portfile.cmake
  jq --arg ver "$latest_ver" '
    if has("version-semver") then .["version-semver"] = $ver
    elif has("version-string") then .["version-string"] = $ver
    else .["version"] = $ver
    end
    | del(.["port-version"])
  ' "$manifest" > "${manifest}.tmp"
  mv "${manifest}.tmp" "$manifest"

  sed -i -E "s|^([[:space:]]*REF[[:space:]]+)[^[:space:])]+|\1${latest_tag}|" "$portfile"
  sed -i -E "s|^([[:space:]]*SHA512[[:space:]]+)[0-9a-fA-F]+|\1${sha512}|" "$portfile"

  git add "$port_dir"
  updated=1
done

if [[ "$updated" -eq 0 ]]; then
  echo "All ports are already up to date."
  exit 0
fi

# 5. Commit ports/ first so git-tree hashes exist, then update versions/
git commit -m "chore(ports): sync upstream releases"

vcpkg \
  --x-builtin-ports-root="$(pwd)/ports" \
  --x-builtin-registry-versions-dir="$(pwd)/versions" \
  x-add-version --all --verbose

git add versions/
git commit --amend --no-edit
echo "Registry updated successfully."
