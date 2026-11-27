#!/usr/bin/env bash
set -uo pipefail

OUT_FILE="${1:-./installed-apps-audit.txt}"

{
  echo "=== AUDIT TIMESTAMP: $(date '+%Y-%m-%d %H:%M:%S') ==="
  echo "=== HOST: $(hostname) ==="
  echo ""

  echo "--- APT / DPKG INSTALLED PACKAGES (MANUAL vs AUTO) ---"
  if command -v apt-mark >/dev/null 2>&1; then
    echo "[MANUAL]"
    apt-mark showmanual 2>/dev/null | sort -u
    echo "[AUTO]"
    apt-mark showauto 2>/dev/null | sort -u
  elif command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null | awk '$4 == "installed" {print $1}' | sort -u
  fi
  echo ""

  echo "--- SNAP PACKAGES ---"
  if command -v snap >/dev/null 2>&1; then
    snap list 2>/dev/null || true
  fi
  echo ""

  echo "--- FLATPAK PACKAGES ---"
  if command -v flatpak >/dev/null 2>&1; then
    flatpak list --columns=application,name,version,origin,installation 2>/dev/null || true
  fi
  echo ""

  echo "--- PYTHON PACKAGES (PIP / PIPX) ---"
  if command -v pipx >/dev/null 2>&1; then
    echo "[PIPX]"
    pipx list --short 2>/dev/null || true
  fi
  for py_pip in pip3 pip; do
    if command -v "$py_pip" >/dev/null 2>&1; then
      echo "[$py_pip list]"
      "$py_pip" list --format=freeze 2>/dev/null || true
    fi
  done
  echo ""

  echo "--- NON-APT / CUSTOM EXECUTABLES IN PATH & /opt ---"
  declare -A seen_paths=()
  IFS=':' read -ra path_dirs <<< "${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
  for dir in "${path_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' bin; do
      [[ -x "$bin" && ! -d "$bin" ]] || continue
      real_bin="$(readlink -f "$bin" 2>/dev/null || echo "$bin")"
      [[ -n "${seen_paths[$real_bin]:-}" ]] && continue
      seen_paths["$real_bin"]=1

      pkg_owner=""
      if command -v dpkg-query >/dev/null 2>&1; then
        pkg_owner="$(dpkg-query -S "$real_bin" 2>/dev/null | head -n 1 || true)"
      fi

      if [[ -n "$pkg_owner" ]]; then
        origin="apt/dpkg ($pkg_owner)"
      elif [[ "$real_bin" == /snap/* ]]; then
        origin="snap"
      elif [[ "$real_bin" == /var/lib/flatpak/* || "$real_bin" == "$HOME/.local/share/flatpak/*" ]]; then
        origin="flatpak"
      elif [[ "$real_bin" == "$HOME/.local/bin/"* || "$real_bin" == "$HOME/.local/pipx/"* ]]; then
        origin="user-local / pipx / pip"
      elif [[ "$real_bin" == /usr/local/* ]]; then
        origin="manual / source / pip-system (/usr/local)"
      elif [[ "$real_bin" == /opt/* ]]; then
        origin="manual / vendor (/opt)"
      else
        origin="other ($real_bin)"
      fi

      printf "%-35s -> %-28s [%s]\n" "$(basename "$bin")" "$real_bin" "$origin"
    done < <(find "$dir" -maxdepth 1 -type f -o -type l 2>/dev/null -print0)
  done | sort -u

  if [[ -d /opt ]]; then
    echo ""
    echo "--- /opt TOP-LEVEL DIRECTORIES ---"
    ls -la /opt 2>/dev/null || true
  fi
} > "$OUT_FILE"

echo "Audit saved to: $OUT_FILE"
