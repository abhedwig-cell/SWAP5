# TOP03 explicit-layer prerequisite decision

Date: 2026-10-02
Status: SATURATED_LIMIT_VERIFIED__CONSTANT_RESISTANCE_FALSIFIED_IN_READY_DRY_CASES__NO_PRODUCTION_ADMISSION

## Outcome

A constant saturated contact resistance is a correct saturated-layer reduction, but it fails the preregistered physical error budgets in 24 event/origin comparisons with ready space-and-time references. None of the 72 event/origin comparisons establishes physical equivalence: 24 are bounded falsifications and 48 remain unavailable because their refinement prerequisites fail. This does not falsify every surface-resistance model, nor does it validate the synthetic layer against field measurements.

The result supersedes the optimistic implication that the previous stability sweep alone established missing physical surface resistance. Stable integration and closed mass are insufficient evidence of the correct transfer response.

## Executed and persisted scope

- Preregistration: `21f5d4e60116b5e25e0ee90b7c891a1a6838b131`.
- Primary test postimage: `657f3db099dfb999d1174f7a800ff7918ee767d1`, 400 cases per O0/O2 build.
- Preregistered resolution extension and test postimage: `6099e059d8fb2dfda53b9bb925b4b072a6a54345`, 192 additional cases per O0/O2 build, including 24 repeated configurations.
- O0/O2 raw numerical output agrees exactly in both phases. The primary plus extension contain 1184 executed case trajectories across builds, including separately labeled analytical controls; 568 unique configurations.
- All 192 extended trajectories per build complete. All 48 harmonic saturated Darcy controls pass, also in a replay of the final diagnostic source. Maximum analytical head error: 1.777e-15 cm; flux error: 4.601e-13 cm/day.
- Maximum independently reconstructed accepted whole-soil mass error across both phases: 5.558e-14 cm. Request origins remain exactly unchanged after every solve, including failed solves. This is solver-request immutability, not TOP03 participant restart/rollback admission.
- Unchanged previous contact-resistance probe passes its R=0 prior-stage controls and O0/O2 identity. No production file is edited, no Actions run is requested.
- Documentation source checks and local MkDocs strict build pass.

The dry main experiment retains the original 3 cm underlying soil, initial pressure -123 cm, free-drainage bottom mode7, six stage events and their durations. The explicit layer occupies [0,L] above the fixed underlying profile. The reduced comparator retains the same external water elevation H+L, without inventing L of pond storage. The separately labeled prewetted-layer origin changes only initial layer water, never the underlying soil or lower boundary.

Arithmetic-interface analytical controls show up to 0.2523 cm/day flux error at finite resolution. They are diagnostics, not a physical oracle. All equivalence claims use the existing FVQ89 distance-weighted harmonic series-resistance algebra, with geometrically consistent face distances.

## Ready full-horizon counterexamples

At L=0.20 cm (2 mm), m=32 and 512 substeps per event, both spatial and temporal reference prerequisites pass at event6:

| Saturated R, day | Initial layer | Reduced excess top input, cm | Reduced excess bottom output, cm | Bottom relative excess | Parent head error, cm |
| --- | --- | --- | --- | --- | --- |
| 0.50 | dry | 0.02465315 | 0.04753972 | 8.97% | 0.2963 |
| 1.00 | dry | 0.05838779 | 0.08022986 | 19.54% | 0.8210 |
| 0.50 | prewetted | 0.04560380 | 0.04523507 | 8.49% | 0.2963 |
| 1.00 | prewetted | 0.07845094 | 0.07703771 | 18.62% | 0.8210 |

For dry R=0.50, the last temporal bottom differences are 0.00099010 cm (explicit) and 0.00071041 cm (reduced); the last spatial differences are 0.00002652 and 0.00017337 cm. These are much smaller than the 0.04754 cm model discrepancy. For dry R=1.00, corresponding temporal differences are 0.00082457 and 0.00049103 cm, and spatial differences 0.00001969 and 0.00017704 cm, against a 0.08023 cm discrepancy. Model mismatch therefore survives independent resolution and exceeds the original physical budget.

The thin L=0.02 cm comparisons have similar discrepancies, but their required joint contraction chains remain unready. Do not promote those observations into a separately qualified thin-layer falsification. R=0.05 and no-layer controls fail numerically in the primary dry factorial; they establish numerical blockers, not physical nonequivalence.

## Storage and unsaturated contact

The dry 2 mm layer gains approximately 0.0232 cm water. That is material and must remain owned by the layer; it cannot be deleted from external receipts. Yet the prewetted-layer runs also fail the physical transfer budgets. Initial filling alone is insufficient to explain the discrepancy.

At the final event, the explicit 2 mm layer spans pressure approximately -1.481 to +0.289 cm for R=0.50 and -3.234 to +0.280 cm for R=1.00. Its minimum local K(h)/Ksat is respectively 0.6913 and 0.5772. The initially prewetted layer reaches the same final layer pressure/conductivity range. Water above the surface thus does not make the entire transition layer saturated in this test.

This supports investigating an unsaturated layer/contact closure, rather than only adding storage to the constant saturated resistance. It does not yet uniquely attribute the mismatch: both the nonlinear layer conductivity and the reduced matrix face law need a matched interface-head reconstruction. The previous reduced law uses saturated-face arithmetic for the matrix contact; it is not a general nonlinear layer elimination.

## Next bounded research and TOP03 consequence

Keep the explicit layer as the independent bounded numerical comparator for the ready R>=0.50 cases. Before implementing another reduced model, preregister a nonlinear thin-layer elimination with the same constitutive law, correct total-head datum, matched matrix-face conductance and explicit layer-storage treatment. Separate a stationary unsaturated layer closure from a stateful resistance-plus-storage closure. Neither can be selected only because it removes solver failures.

Retain R=0/R=0.05 numerical failures as a separate unresolved envelope. Keep synthetic model-form verification distinct from measurement-backed parameter qualification. A physical reduction that passes this test still needs an applicable field/profile envelope and the separate Ribasim/local-pond storage ownership contract.

TOP03 remains draft and production qualification/admission false. BASE exact-state acceptance, real top-active candidate availability, receipt rejection/replay/exactly-once commit and current-canonical qualification are not supplied by this study. No production tolerance or default resistance is selected.

## Evidence and reconstruction

`TOP03_EXPLICIT_LAYER_RESULT.json` contains all fixed-budget eventwise tests, ready/unready decisions, failures, errors and phase/source identities. `evidence/explicit_layer/raw_records.tar.gz` retains O0/O2 records, exact compiler closure manifests, cases, logs, final analytical replay, unchanged contact-law replay, documentation checks and the dependency reconciliation record. Its manifest records SHA-256 values.

Reconstruct the primary at its exact test postimage with `tests/fapp/run_sw_rib_top03_explicit_layer.py`; reconstruct the extension with its pinned postimage and `--extended`. The final analyzer accepts `--extension`, `--primary-source`, `--source` and `--canonical`. Run it after extracting the archive, using the archived primary/extension directories. Neither a finest grid nor a green control is called ground truth outside its recorded scope.
