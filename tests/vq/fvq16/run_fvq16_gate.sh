#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"

candidate="2becebfe747663ea3b896d7d19f4381c32df77db"
expected_tree="21a753da94c3ccbbab0b36dc04cd618f5b0d6547"
expected_blob="54702d71b4c84dce2842813549bd14c57301a383"
expected_candidate_sha256="1590a91275f99f3412bf71a263c0fa61371b106810c6a662c249b7d1b3c89293"
expected_legacy_sha256="02f36d30448b94dfdf386bc43424f1fe0feff9eafd24a768a8c702843a0bf9b2"

actual_tree="$(git rev-parse "${candidate}^{tree}")"
actual_blob="$(git rev-parse "${candidate}:src/process/mod_snow_process.f90")"
[[ "$actual_tree" == "$expected_tree" ]]
[[ "$actual_blob" == "$expected_blob" ]]

git diff --exit-code "$candidate"..HEAD -- src/process/mod_snow_process.f90
printf '%s  %s\n' "$expected_candidate_sha256" src/process/mod_snow_process.f90 | sha256sum -c -
printf '%s  %s\n' "$expected_legacy_sha256" tests/vq/fvq16/B1.10_snow_reference.f90 | sha256sum -c -

rm -rf build/fvq16 .fvq16-artifacts
mkdir -p build/fvq16/o0 build/fvq16/o2 .fvq16-artifacts

common=(
  -std=f2008 -Wall -Wextra -Werror -pedantic
  -fcheck=all -ffpe-trap=invalid,zero,overflow
)
sources=(
  tests/vq/fvq16/fvq16_legacy_support.f90
  tests/vq/fvq16/B1.10_snow_reference.f90
  src/process/mod_snow_process.f90
  tests/vq/fvq16/test_fvq16_snow_scientific.f90
)

gfortran "${common[@]}" -O0 -Jbuild/fvq16/o0 -Ibuild/fvq16/o0 "${sources[@]}" -o build/fvq16/o0/fvq16_snow
gfortran "${common[@]}" -O2 -Jbuild/fvq16/o2 -Ibuild/fvq16/o2 "${sources[@]}" -o build/fvq16/o2/fvq16_snow

build/fvq16/o0/fvq16_snow > .fvq16-artifacts/o0.out
build/fvq16/o2/fvq16_snow > .fvq16-artifacts/o2.out
cmp .fvq16-artifacts/o0.out .fvq16-artifacts/o2.out

sha256sum build/fvq16/o0/fvq16_snow > .fvq16-artifacts/o0-executable.sha256
sha256sum build/fvq16/o2/fvq16_snow > .fvq16-artifacts/o2-executable.sha256
sha256sum .fvq16-artifacts/o0.out > .fvq16-artifacts/output.sha256
printf '%s\n' "$candidate" > .fvq16-artifacts/candidate.txt
printf '%s\n' "$expected_tree" > .fvq16-artifacts/candidate-tree.txt
printf '%s\n' "$expected_blob" > .fvq16-artifacts/candidate-source-blob.txt
printf '%s\n' "$expected_legacy_sha256" > .fvq16-artifacts/legacy-source-sha256.txt

git diff --exit-code "$candidate"..HEAD -- src/process/mod_snow_process.f90
cat .fvq16-artifacts/o0.out
