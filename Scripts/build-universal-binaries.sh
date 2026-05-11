#!/bin/bash
# Builds Vendor/unrar/universal/unrar by combining arm64 + x86_64 via lipo.
# Idempotent; safe to run repeatedly.
set -euo pipefail

VENDOR="${SRCROOT:-$(pwd)}/Vendor/unrar"
OUT="${VENDOR}/universal"
mkdir -p "${OUT}"

ARM="${VENDOR}/arm64/unrar"
X64="${VENDOR}/x86_64/unrar"
UNI="${OUT}/unrar"

if [[ -f "${ARM}" && -f "${X64}" ]]; then
  lipo -create "${ARM}" "${X64}" -output "${UNI}"
  chmod +x "${UNI}"
  echo "[universal] arm64 + x86_64 → ${UNI}"
elif [[ -f "${ARM}" ]]; then
  cp "${ARM}" "${UNI}"
  chmod +x "${UNI}"
  echo "[universal] arm64-only fallback → ${UNI}"
elif [[ -f "${X64}" ]]; then
  cp "${X64}" "${UNI}"
  chmod +x "${UNI}"
  echo "[universal] x86_64-only fallback → ${UNI}"
else
  echo "ERROR: no unrar binary found in ${VENDOR}/arm64 or ${VENDOR}/x86_64"
  exit 1
fi

lipo -info "${UNI}"
