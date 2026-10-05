# Guarded B1 frost geometry reference

Status: current / canonically admitted bounded reference component through PR #1042. SWAP5 production sources remain unchanged.

Direct execution of the original B1 FrozenCond reproduces a floating-point division trap for uniform negative temperatures. A temperature candidate selected by the legacy 1e-6C search epsilon without a real end-temperature crossing can produce a frost bottom approximately 4998cm above the surface. Original FrozenBounds also accesses drain index zero when no supplied drain depth is negative. These are demonstrated source failures, not inferred failures of every frost configuration.

FROST-GEOMETRY-01 layers guards over the admitted reporting-only FROST-DRAIN-01 reference. It checks finite inputs, ordered limits and valid node geometry, requires an actual bracket before evaluating each old depth formula, and exposes a disposable geometry validity/status. FrozenBounds rejects unavailable geometry and invalid ordinary drain-depth domains before assigning any boundary or drain physical flux. It supplies no invented front for a uniform cold profile and does not correct the legacy decrement-before-test last-node index policy. Uniform fully frozen depth interpretation remains a separate physical decision.

Valid formulas and physical assignments are retained byte for byte. A 1e-10cm guard allowance accepts floating-point endpoint roundoff while leaving original depth values unchanged; it does not clamp or shift those outputs. Two grids, eight profiles and three surface temperatures produce 48 valid cases. Original and guarded hydraulic factors, top/bottom depths, nodal drainage and bottom fluxes agree bit for bit at O0/O2. The existing ordinary reporting correction remains in force, so derived totals equal final nodal fluxes.

Separate subprocess probes reproduce the original division and bounds failures and extreme above-surface depth, then verify deterministic guarded status or explicit preflux rejection. NaN temperature, invalid limits, coincident nodes, inconsistent distance, stale invalid geometry and invalid drain levels reject. Both optimization levels use bounds checks and invalid/zero/overflow traps. The exact-base applicator verifies base and target hashes, rejects an original or conflicting-output overwrite, and leaves the original B1.11 and reporting overlay immutable. Reference source copies preserve CRLF bytes.

This qualifies the actual FrozenCond/FrozenBounds source component with explicit test globals. It does not establish a full legacy simulation, promote a global B1 snapshot, admit SWDIVD=1/macropore/surface-water drainage, introduce phase-change physics or broaden SWAP5 production. Exact source identities and replay output are in `integration/audits/PPA_WU05B7_REF_STATUS.json` and `integration/audits/PPA_WU05B7_REF_LOCAL_REPLAY.json`. Run `python3 tests/frost/run_ppa_wu05b7_geometry_reference.py`.

The next production scope can migrate bracketed low-air ordinary drainage using explicit physical drain depths and the corrected single nodal flux owner. It must retain separate qualification for uniform/last-node front interpretation and redistribution.

## Canonical reference-component admission

PR #1042 admitted the bounded reference component at `e93e40a9609bb13a1e6786a2dccd08c8ca30856f`. Proposed merge `cc4d7c409df07ac121989dae3b8938daebf10493` matched qualified tree `03c3814113aa927df9fc981d6ea9cbbe5e5459bd` exactly; production source remains `c659cc9d51216437859e6675cce83f1b4b28e1b7`. Admission uses completed local qualification with no queued Actions success claim.
