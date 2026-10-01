#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
B="$(mktemp -d)"; trap 'rm -rf "$B"' EXIT
for opt in 0 2; do
 "${FC:-gfortran}" -std=f2008 -ffree-line-length-none -fcheck=all -O"$opt" -J"$B" -I"$B" research/rfm/a27/mod_rfm_signed_contact_research.f90 research/rfm/a27/test_signed_contact.f90 -o "$B/test"
 "$B/test" > "$B/o$opt"
done
cmp "$B/o0" "$B/o2";cat "$B/o2"
