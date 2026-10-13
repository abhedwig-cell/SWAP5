# F-CI duplicate call-site forensic inventory (2026-10-13)

Status: static evidence only, NOT an executed runtime trace.

Pinned inspected file: `tests/fci/run_fci_canonical_p2e05_moving_preservation.sh` on `integration/f-ci-canonical`, 1554 lines. Regex count of direct `bash tests/...` and `python tests/...` tokens yields 87 call-sites and 67 distinct script paths; these are syntactic counts, NOT executed job counts.

Repeated paths:
- `tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh`: 11
- `tests/mc-met01/verify_daily_demand_successor.py`: 3
- `tests/fci/run_crop_file_weather_production_successor.sh`: 2
- `tests/fapp/run_ppa_wu03_common_forcing_adapter.sh`: 2
- `tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh`: 2
- `tests/fmig431/run_crop_weather_preflight_read_boundary.sh`: 2
- `tests/fmig431/run_crop_weather_day_owner.sh`: 2
- `tests/fmig431/run_crop_germination_preflight.sh`: 2
- `tests/fmig431/run_crop_fkt_b110_scientific_successor.sh`: 2
- `tests/fmig431/run_crop_accepted_hydraulic_provenance.sh`: 2

None of this proves that any calls run repeatedly on the same candidate, that their relevant dependency closures are identical, or that safe skipping is possible. Conditional branches, generated data and output dependencies may differ. Existing Full Richards / mass / retry / restart evidence stays authoritative.

Next decisive experiment: instrument command boundaries in original runner on a fixed HEAD and record, for each invoked group, conditional context, full command, UTC/monotonic elapsed, input manifest fingerprint, compiler count, executable wall/CPU time where isolated, output hashes, and terminal result. Compare the 11 cross-preservation call sites; only identical fully auditable closures could be candidates for one-run inheritance. Do not edit scientific gates before tracing.

Separately benchmark already-built **actual** Full Richards executables with fixed fixture and physical output checks across current and previous SWAP5; historical SWAP431 source authority is already present in repository. The source archive's presence does not equal a benchmark execution.

Current evidence: model-specific solver CPU and performance regression are UNKNOWN. No speedup claim or gate removal authorized.

## Confirmed duplicate conditional branch in original script

The current original runner's region around lines 872-900 contains **two separate** `if (( crop_hydraulic_provenance_changed )); then` blocks, both executing the same pair:

- `bash tests/fmig431/run_crop_accepted_hydraulic_provenance.sh`
- `bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh`

If the Boolean is true and the first pair passes, the second pair is reached under the same Boolean, absent side effects modifying it. This is a stronger static redundancy finding than merely seeing the same path repeated in independent guards. Scientific equivalence is still **not** demonstrated: tests may read or mutate shared state, and an unexamined external action may change it. Confirm exact invocations and input/output closure and measure both calls on one clean running candidate BEFORE refactoring.

A fail-closed future consolidation could run the pair once, then require the same exact source/fixture/runtime/toolchain assertion at the second gate and record both logical claims. But no gate was removed or skipped in this PR.

## Candidate simplification on audit PR (2026-10-13)

The audit branch now contains a **proposed** direct consolidation of the duplicate same-condition hydraulic-provenance branch. It retains the original first occurrence of both `run_crop_accepted_hydraulic_provenance.sh` and `run_crop_lifecycle_b19_micro_cross_preservation.sh`, while removing their second occurrence and duplicated flag declaration/case selector. Exact branch source re-read confirms one occurrence of declaration, selector, and conditional guard. A static unit test in `tests/performance/test_hydraulic_provenance_route.py` guards this structure. This is NOT evidence of full-preservation equivalence, execution-cost savings, or admission.

The preservation script rebuilds O0/O2 transitive production Fortran sources into a fresh temporary directory, while B19/MICRO runner invokes child gates and temporary builds. These outputs are not intentionally used as persistent downstream artifacts, but external dependencies and effects have not yet been fully audited. Restore the original runner or re-run both groups if any hidden state difference or validation failure is found. Before any canonical merge: exact-HEAD `bash -n`, static tests, both original owner gates, conditional-route positive/negative selection tests, requisite full moving F-CI and F-CI/VQ preservation approval. Quantify savings against an unmodified same-source baseline. No other gate or tolerance is authorized to change.
