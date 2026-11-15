#!/usr/bin/env bash

set -euo pipefail

shopt -s nullglob
archives=(components/*.tar.gz)
if [[ ${#archives[@]} -eq 0 ]]; then
  printf 'No ARM component archives found under components/.\n' >&2
  exit 1
fi

json_escape() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' <<< "$1" | tr -d '\n'
}

separator=''
{
  printf '{\n'
for archive in "${archives[@]}"; do
  component="$(basename "${archive%.tar.gz}")"
  version_member="$(tar -tzf "$archive" | awk '$0 == "component_version" || $0 == "./component_version" || $0 ~ /\/component_version$/ { if (!found++) print }')"
  if [[ -z "$version_member" ]]; then
    printf 'Missing component_version in %s\n' "$archive" >&2
    exit 1
  fi

  version="$(tar -xOzf "$archive" "$version_member" | tr -d '\r\n')"
  if [[ -z "$version" ]]; then
    printf 'Empty component_version in %s\n' "$archive" >&2
    exit 1
  fi

  printf '%s  "%s": {"version": "%s"}' \
    "$separator" "$(json_escape "$component")" "$(json_escape "$version")"
  separator=$',\n'
done
  printf '\n}\n'
} > components_metadata.json
