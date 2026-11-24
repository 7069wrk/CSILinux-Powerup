BRANCH="main"
REPO_BASE="https://raw.githubusercontent.com/7069wrk/CSILinux-Powerup/${BRANCH}"
PROFILES_CONF="./profiles.conf"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

while IFS='|' read -r profile url fallback backup; do
  [[ "$profile" =~ ^[[:space:]]*(#|$) ]] && continue

  # Use explicit URL from profiles.conf if present, otherwise derive from profile name
  if [[ -n "$url" ]]; then
    raw_url="${url//\$\{BRANCH\}/$BRANCH}"
  else
    manifest_file="${profile//-/_}.txt"
    raw_url="${REPO_BASE}/${manifest_file}"
  fi

  manifest_tmp="$tmp_dir/${profile}.txt"
  if ! curl -fsSL "$raw_url" -o "$manifest_tmp"; then
    echo "=== $profile === [FETCH FAILED: $raw_url]"
    continue
  fi

  echo "=== $profile === ($raw_url)"
  missing=0
  total=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    pkg="$(printf '%s' "${line%%#*}" | xargs)"
    [[ -z "$pkg" ]] && continue
    total=$((total + 1))

    candidate="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    if [[ -z "$candidate" || "$candidate" == "(none)" ]]; then
      echo "  [NON-APT] $pkg"
      missing=$((missing + 1))
    fi
  done < "$manifest_tmp"

  echo "  Total: $total | Non-APT/Missing: $missing"
done < "$PROFILES_CONF"
