#!/usr/bin/env bash
# EXPERIMENTAL ONLY. Not a replacement for either qualified incumbent gate.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-shared-irr-XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
fail() { echo "SHARED_IRR_FAIL $*" >&2; exit 1; }
ROOT_TEST=tests/f-app07/test_mc_irr01_allocated_root_restart.f90
SENSOR_TEST=tests/f-app07/test_mc_irr01_allocated_sensor_restart.f90
python3 tools/performance/irrigation_build_identity.py "$BUILD/identity.json" > "$BUILD/sources"
COMMON=(-std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
started=$SECONDS
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  objects=()
  while IFS= read -r source; do
    obj="$OUT/$(echo "$source" | tr '/' '_' | sed 's/\.f90$/.o/')"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done < "$BUILD/sources"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/legacy/b1_10_port/headcalc.f90 -o "$OUT/headcalc_legacy.o" || fail "headcalc O$opt"
  objects+=("$OUT/headcalc_legacy.o")
  find "$OUT" -maxdepth 1 -type f \( -name '*.o' -o -name '*.mod' -o -name '*.smod' \) -print0 | sort -z | xargs -0 sha256sum > "$OUT/common.sha256"
  for case in root sensor; do
    sha256sum -c "$OUT/common.sha256" > /dev/null || fail "common artifact mutation before $case O$opt"
    if [[ "$case" == root ]]; then source="$ROOT_TEST"; else source="$SENSOR_TEST"; fi
    # Isolate each test driver's module outputs from the common modules.
    # No root-test .mod may influence sensor-test compilation.
    DRIVER="$OUT/$case-driver"; mkdir -p "$DRIVER"
    cp "$OUT"/*.mod "$DRIVER/" 2>/dev/null || true
    cp "$OUT"/*.smod "$DRIVER/" 2>/dev/null || true
    gfortran "${COMMON[@]}" -O"$opt" -J "$DRIVER" -I "$DRIVER" -c "$source" -o "$DRIVER/test.o" || fail "$case driver O$opt"
    gfortran -fopenmp -O"$opt" "${objects[@]}" "$DRIVER/test.o" -o "$DRIVER/test" || fail "link $case O$opt"
    "$DRIVER/test" > "$OUT/$case.output" 2>&1 || { cat "$OUT/$case.output" >&2; fail "$case runtime O$opt"; }
    grep -Fq 'MC_IRR01_MANAGEMENT_REAL_RICHARDS=PASS' "$OUT/$case.output" || fail "$case Richards"
    grep -Fq 'MC_IRR01_MANAGEMENT_AUTHORITATIVE_MASS=PASS' "$OUT/$case.output" || fail "$case mass"
    sha256sum -c "$OUT/common.sha256" > /dev/null || fail "common artifact mutation after $case O$opt"
  done
done
python3 tools/performance/irrigation_build_identity.py "$BUILD/identity.json" --verify
for case in root sensor; do
  cmp "$BUILD/o0/$case.output" "$BUILD/o2/$case.output" || fail "$case O0/O2 drift"
  cat "$BUILD/o0/$case.output"
  echo "SHARED_IRR_${case^^}_SHA256=$(sha256sum "$BUILD/o0/$case.output" | cut -d ' ' -f 1)"
done
echo "SHARED_IRR_COMPILED_SOURCES_PER_OPT=$(wc -l < "$BUILD/sources")"
echo "SHARED_IRR_WALL_SECONDS=$SECONDS"
if [[ -n "${SWAP5_SHARED_EVIDENCE_DIR:-}" ]]; then
  mkdir "$SWAP5_SHARED_EVIDENCE_DIR"
  cp "$BUILD/identity.json" "$BUILD/sources" "$SWAP5_SHARED_EVIDENCE_DIR/"
  for opt in 0 2; do
    for case in root sensor; do
      cp "$BUILD/o$opt/$case.output" "$SWAP5_SHARED_EVIDENCE_DIR/$case-o$opt.output"
      cp "$BUILD/o$opt/$case-driver/test" "$SWAP5_SHARED_EVIDENCE_DIR/$case-o$opt.exe"
    done
  done
fi
echo "SHARED_IRR_SCIENCE=PASS"
