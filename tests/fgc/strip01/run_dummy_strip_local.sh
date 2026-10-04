#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-strip01-c2d"
OUT="${C2D_OUTPUT:-$ROOT/integration/f-gc/strip01/results/c2d-local}"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
rm -rf "$OUT"
mkdir -p "$OUT"

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(Path("$BUILD/modflow-bin"), owner="MODFLOW-ORG", repo="modflow6",
         release_id="6.8.0", subset={"mf6", "libmf6.so"},
         downloads_dir=Path("$BUILD/downloads"), force=False, quiet=False)
PY
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $BUILD/downloads/modflow6-6.8.0-linux.zip" | sha256sum -c -
printf '%s\n' '33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  modflow6-6.8.0-linux.zip' > "$OUT/modflow_asset_sha256.txt"
"$BUILD/modflow-bin/mf6" -v

COMMON=(-std=f2008 -ffree-line-length-none -fPIC -Wall -Wextra -Werror -Wno-error=compare-reals)
SOURCES=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
)
gfortran "${COMMON[@]}" -shared -J "$BUILD/bridge" -I "$BUILD/bridge" \
  "${SOURCES[@]}" -o "$BUILD/bridge/libfgc34_bridge.so"
nm -D "$BUILD/bridge/libfgc34_bridge.so" | grep -q fgc34_publish_c

run_case() {
  local name="$1" mode="$2" conductance="$3" tolerance="${4:-1e-10}"
  python3 tests/fgc/strip01/run_dummy_strip.py --libmf6 "$BUILD/modflow-bin/libmf6.so" \
    --publisher "$BUILD/bridge/libfgc34_bridge.so" --output "$OUT/$name" \
    --mode "$mode" --conductance "$conductance" --flux-tolerance "$tolerance"
}
run_case zero_first zero 1000000
run_case zero_replay zero 1000000
cmp "$OUT/zero_first/result.json" "$OUT/zero_replay/result.json"
run_case transparent_first pulse 1000000
run_case transparent_replay pulse 1000000
cmp "$OUT/transparent_first/result.json" "$OUT/transparent_replay/result.json"
run_case finite_resistance_first pulse 0.125
run_case finite_resistance_replay pulse 0.125
cmp "$OUT/finite_resistance_first/result.json" "$OUT/finite_resistance_replay/result.json"
run_case strict_transparent_first pulse 1000000 2e-15
run_case strict_transparent_replay pulse 1000000 2e-15
cmp "$OUT/strict_transparent_first/result.json" "$OUT/strict_transparent_replay/result.json"
run_case strict_finite_resistance_first pulse 0.125 2e-15
run_case strict_finite_resistance_replay pulse 0.125 2e-15
cmp "$OUT/strict_finite_resistance_first/result.json" "$OUT/strict_finite_resistance_replay/result.json"
python3 tests/fgc/strip01/plot_dummy_strip.py

python3 - <<PY
import gzip, hashlib, json
from pathlib import Path
out=Path("$OUT")
cases={}
for name in ("zero_first", "transparent_first", "finite_resistance_first", "strict_transparent_first", "strict_finite_resistance_first"):
    p=out/name/"result.json"; d=json.loads(p.read_text())
    cases[name]={"state":d["conclusion"],"windows":len(d["rows"]),
      "published_windows":sum(r["published"] for r in d["rows"]),
      "max_abs_window_mass_residual_m3":max(abs(r["mass_residual_m3"]) for r in d["rows"]),
      "max_dummy_component_residual_m3":max(abs(r["dummy_component_residual_m3"]) for r in d["rows"]),
      "max_modflow_component_residual_m3":max(abs(r["modflow_component_residual_m3"]) for r in d["rows"]),
      "cumulative_mass_residual_m3":d["rows"][-1]["cumulative"]["mass_residual_m3"],
      "cumulative_relative_mass_residual":d["rows"][-1]["cumulative"]["relative_residual"],
      "max_drain_package_vs_analytic_m3_per_day":max(r["drain_formula_abs_error_m3_per_day"] for r in d["rows"]),
      "coupling_flux_tolerance_m_per_s":d["parameters"]["coupling_flux_tolerance_m_per_s"],
      "max_coupling_residual_m_per_s":max(r["max_abs_coupling_residual_m_per_s"] for r in d["rows"]),
      "max_action_reaction_residual_m3":max(abs(r["action_reaction_residual_m3"]) for r in d["rows"]),
      "fresh_process_byte_identical":p.read_bytes()==(out/name.replace("first","replay")/"result.json").read_bytes(),
      "final_column_revision_min":d["rows"][-1]["revisions_min"],
      "final_column_revision_max":d["rows"][-1]["revisions_max"],
      "final_column_ledger_min":d["rows"][-1]["ledger_min"],
      "final_column_ledger_max":d["rows"][-1]["ledger_max"],
      "final_head_m":d["rows"][-1]["head_m"],
      "total_drain_m3":sum(r["drain_outflow_m3"] for r in d["rows"]),
      "total_interface_transfer_m3":sum(r["interface_transfer_m3"] for r in d["rows"]),
      "right_boundary_final_head_rise_m":d["rows"][-1]["head_m"][-1]-d["initial_head_m"],
      "max_lateral_face_flow_m3_per_day":max(max(map(abs,r["lateral_face_flow_m3_per_day"])) for r in d["rows"]),
      "max_resistance_law_error_m3_per_day":max(r["resistance_law_max_abs_error_m3_per_day"] for r in d["rows"]),
      "final_internal_minus_interface_head_m":max(abs(a-b) for a,b in zip(d["rows"][-1]["dummy_internal_head_m"],d["rows"][-1]["head_m"])),
      "modflow_binary_sha256":d["modflow_binary_sha256"]}
summary={"schema":"swap5.fgc.strip01.c2d.summary.v1","state":"RUNS_COMPLETED",
 "source_commit":json.loads((out/"transparent_first/result.json").read_text())["source_commit"],
 "dummy_bank_commit":"4fd8861bf6300d8074051d3bd24ef993cb60dbda",
 "c2b_comparator_commit":"ac87e2484b1ecc54c8eac9072cd6f9248fbeb5e9",
 "figure":"integration/f-gc/strip01/results/c2d-local/profiles.svg",
 "figure_sha256":hashlib.sha256((out/"profiles.svg").read_bytes()).hexdigest(),
 "modflow_asset_archive_sha256":"33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e",
 "preregistration":"integration/f-gc/strip01/F-GC-STRIP01_C2D_PREREGISTRATION.json","cases":cases}
assert all(v["state"]=="RUN_COMPLETED" and v["fresh_process_byte_identical"] for v in cases.values())
assert cases["zero_first"]["windows"]==4 and cases["zero_first"]["total_drain_m3"]==0.0
assert cases["zero_first"]["cumulative_mass_residual_m3"]==0.0
assert cases["zero_first"]["total_interface_transfer_m3"]==0.0
assert cases["zero_first"]["final_column_revision_min"]==4 and cases["zero_first"]["final_column_revision_max"]==4
assert cases["transparent_first"]["windows"]==120 and cases["finite_resistance_first"]["windows"]==120
assert cases["strict_transparent_first"]["windows"]==120 and cases["strict_finite_resistance_first"]["windows"]==120
for name in ("strict_transparent_first","strict_finite_resistance_first"):
    assert cases[name]["fresh_process_byte_identical"]
    assert cases[name]["max_abs_window_mass_residual_m3"]<=1e-10
    assert cases[name]["total_interface_transfer_m3"]>0.0
    assert cases[name]["coupling_flux_tolerance_m_per_s"]==2e-15
    assert cases[name]["max_coupling_residual_m_per_s"]<=2e-15
for name in ("transparent_first","finite_resistance_first"):
    assert cases[name]["max_abs_window_mass_residual_m3"]<=1e-10
    assert cases[name]["max_dummy_component_residual_m3"]<=1e-10
    assert cases[name]["max_modflow_component_residual_m3"]<=1e-10
    assert abs(cases[name]["cumulative_mass_residual_m3"])<=1e-10
    assert cases[name]["cumulative_relative_mass_residual"]<=1e-8
    assert cases[name]["max_action_reaction_residual_m3"]==0.0
    assert cases[name]["max_drain_package_vs_analytic_m3_per_day"]<=1e-8
    assert cases[name]["total_drain_m3"]>0.0
    assert cases[name]["total_interface_transfer_m3"]>0.0
    assert cases[name]["right_boundary_final_head_rise_m"]>0.01
    assert cases[name]["max_lateral_face_flow_m3_per_day"]>0.0
    assert cases[name]["final_column_revision_min"]==120 and cases[name]["final_column_revision_max"]==120
    assert cases[name]["final_column_ledger_min"]==120 and cases[name]["final_column_ledger_max"]==120
assert cases["finite_resistance_first"]["max_resistance_law_error_m3_per_day"]<1e-8
artifacts={}
for name in ("zero_first","transparent_first","finite_resistance_first"):
    src=out/name/"result.json"; raw=src.read_bytes()
    target=out/f"{name}.result.json.gz"
    target.write_bytes(gzip.compress(raw,compresslevel=9,mtime=0)); src.unlink()
    artifacts[name]={"path":str(target.relative_to(out)),"sha256":hashlib.sha256(target.read_bytes()).hexdigest(),"encoding":"gzip JSON"}
for name in ("zero_replay","transparent_replay","finite_resistance_replay","strict_transparent_replay","strict_finite_resistance_replay"):
    src=out/name/"result.json"; digest=hashlib.sha256(src.read_bytes()).hexdigest(); src.unlink()
    record={"schema":"swap5.fgc.strip01.c2d.replay-identity.v1","byte_identical_to":name.replace("replay","first"),
      "json_sha256":digest,"byte_identical":True}
    target=out/f"{name}.replay_identity.json"
    target.write_text(json.dumps(record,indent=2,sort_keys=True)+"\n")
    artifacts[name]={"path":target.name,"json_sha256":digest}
for name in ("strict_transparent_first","strict_finite_resistance_first"):
    src=out/name/"result.json"; run_sha=hashlib.sha256(src.read_bytes()).hexdigest(); d=json.loads(src.read_text()); src.unlink()
    small={"schema":"swap5.fgc.strip01.c2d.strict-result.v1","source_commit":d["source_commit"],
      "full_run_json_sha256":run_sha,
      "conductance_m2_per_day":d["parameters"]["vertical_conductance_m2_per_day"],
      "coupling_flux_tolerance_m_per_s":d["parameters"]["coupling_flux_tolerance_m_per_s"],
      "state":d["conclusion"],"windows":len(d["rows"]),"published_windows":sum(r["published"] for r in d["rows"]),
      "initial_head_m":d["initial_head_m"],
      "max_coupling_residual_m_per_s":max(r["max_abs_coupling_residual_m_per_s"] for r in d["rows"]),
      "max_window_mass_residual_m3":max(abs(r["mass_residual_m3"]) for r in d["rows"]),
      "cumulative_mass_residual_m3":d["rows"][-1]["cumulative"]["mass_residual_m3"],
      "cumulative_relative_mass_residual":d["rows"][-1]["cumulative"]["relative_residual"],
      "total_interface_transfer_m3":sum(r["interface_transfer_m3"] for r in d["rows"]),
      "total_drain_m3":sum(r["drain_outflow_m3"] for r in d["rows"]),
      "final_head_m":d["rows"][-1]["head_m"],
      "final_dummy_internal_head_m":d["rows"][-1]["dummy_internal_head_m"],
      "resistance_law_max_abs_error_m3_per_day":max(r["resistance_law_max_abs_error_m3_per_day"] for r in d["rows"]),
      "native_cbc_validated":d["native_modflow_cbc_validated"]}
    target=out/f"{name}.result.json"; target.write_text(json.dumps(small,indent=2,sort_keys=True)+"\n")
    artifacts[name]={"path":str(target.relative_to(out)),"encoding":"compact JSON"}
import shutil
for name in ("zero_first","zero_replay","transparent_first","transparent_replay","finite_resistance_first","finite_resistance_replay",
             "strict_transparent_first","strict_transparent_replay","strict_finite_resistance_first","strict_finite_resistance_replay"):
    shutil.rmtree(out/name)
summary["result_artifacts"]=artifacts
(out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
print(json.dumps(summary,indent=2))
PY
for name in zero_first zero_replay transparent_first transparent_replay finite_resistance_first finite_resistance_replay \
            strict_transparent_first strict_transparent_replay strict_finite_resistance_first strict_finite_resistance_replay; do
  rm -rf "$OUT/$name"
done
