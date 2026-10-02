# A27 bounded nonlinear lateral moisture frontier

Date:2026-10-02. Status: LOCAL_RESEARCH_EVIDENCE. Production A/B/C OPEN, no canonical admission.
Canonical checked:0d44f0195c94a9732c67b5e77f2148912df9bbc8. Branch baseline:b729aef1af3ec9ceca4f679ab32fcc126afa974d. Executed code:a1abfe0e058fe9baf12f48ca14a8ee0b006cde86. [Preregistered contract](PPA_WU05A27_LATERAL_PROFILE_CONTRACT.md). Production sources, A26 first-order split, persistence and shared ownership are unchanged.

## Conclusion and limits

A fixed128-cell lateral moisture profile passes the declared storage/receipt and four band-moisture screens in all24 nonlinear diffusion/contact-interruption cases. Smaller tested states fail some or all cases. This supports a bounded research representation that retains moisture feedback and spatial relaxation during interruption. It does not prove original RFM theory, a production state layout, moving-contact closure, physical field validity or speedup.128 is the smallest passing **tested** resolution, not a proven mathematical minimum.

The experiment replaces scalar wall age with an explicit spatial moisture profile in a fixed full-wall horizontal slab. Positive synthetic D(theta) laws are prescribed with beta=-2,0,2; their retention/conductivity correspondence has not been established. During absent contact, matrix water either remains conserved or leaves through an explicitly prescribed0.1cm/day evaporation boundary. A source pulse supplies exactly0.25 of each cell's saturation deficit. All geometry, laws and screens are identical across numerical resolutions; no case-specific fitting was used.

## State versus response frontier

There are24 cases per mesh and six saved phase/time endpoints per case. Eight nominal meshes give192 case trajectories and1152 sampled records. The tight1024 rerun adds24 case trajectories and144 records. Analyses compare candidate meshes against1024 at matching case/stage, using cell-overlap averages in fixed lateral bands. Raw trajectories retain all receipts, dry losses, ledgers and band responses.

| Lateral cells | Passing cases | Maximum storage/receipt error cm | Maximum band-theta error | Packed moisture bytes per wall patch |
| --- | --- | --- | --- | --- |
|8|0/24|0.01575308|0.06349275|64|
|16|0/24|0.00408505|0.02087243|128|
|32|6/24|0.00103530|0.00502317|256|
|64|16/24|0.00026140|0.00165844|512|
|128|24/24|0.000064803|0.00036144|1024|

The preregistered limits are0.01cm storage/receipt and0.001 band theta.16,32 and64 pass the mass screen in every case but fail moisture response in some or all cases. Thus even a small storage/exchange difference does not establish sufficiently similar near-wall behavior. All eight64-cell failures have a0.5day interruption and beta=-2 or0, for both pulse choices and both drying boundaries. A long interruption can require more spatial state even when evaporation is absent. Failures are numerical representation errors against this model's refined reference; they do not establish that the model itself is physically correct.

Packed memory counts only N real64 moisture values. It excludes precomputed mesh/constitutive data, solver workspace, Jacobian/factorization storage, descriptors, temporary copies, accumulated-flux diagnostics and any vertical patch state. It is not RSS or a complete MultiSWAP footprint. Counts are constant with timestep/event count for a fixed wall patch. A bound on the number and geometry of patches is still necessary for moving contact. Solver counters are raw diagnostics; cached initial-wetting counts are repeated for case context and must not be summed as executed aggregate cost.

## Reference verification

| Reference comparison | Maximum storage/receipt difference cm | Maximum band-theta difference |
| --- | --- | --- |
|256/512|0.0000123533|0.0000850723|
|512/1024|0.00000308915|0.0000165970|
|1024 nominal/tight BDF tolerances|8.91975e-10|1.40905e-9|

All required reference limits0.0001cm/0.0001theta pass. Constant-D initial wetting uptake differs from the continuous finite-slab eigenseries by5.96704e-7cm. Maximum sampled ledger residual is3.55271e-15cm. Every stored moisture state stays within the declared0.05 to0.45 envelope without clipping. Analytic sparse Jacobian versus finite differences, instantaneous flux conservation, immutable trial arrays and discard/replay checks pass. These are research checks, not production reject/restart qualification.

The nonlinear reference shares the finite-volume equation/discretization family with candidates; refinement plus a constant-D independent analytic check is not an independent nonlinear physical validation. Tight temporal reruns show that reported spatial errors are not dominated by nominal BDF tolerances within this experiment.

The first implementation ataa31ae45f2fffabaee5f2d869f4eb7b71557de8f completed the numerical CSVs but failed JSON serialization of a NumPy boolean, exit1. This was a reporting defect. The persisted repair converts the scalar to a native JSON type and reruns all cases, exit0. The failure log is retained; manifests record exact dependency SHA256 at each original code SHA and the numerical CSV identity check. Do not relabel the failed full run as successful.

## Next physical and production gate

This resolves bounded state for the declared fixed-wall research model only. Before using it as an RFM replacement, test moving wetted contact with a **bounded vertical patch representation**, retention/conductivity-derived diffusivity, external matrix redistribution/root uptake, signed pressure-driven exchange and receiver feedback. Keep numerical integration policy separate from physical state/closure. A moisture-profile equation is a different proposed closure from frozen Philip cohorts; its relation to source theory must be derived rather than assumed.

The full paired production benchmark remains unrun. Matrix-only Reference, full standard macropore and admitted RFM must still be compared over the eight forcing regimes, multiple geometries and explicit parameter mapping. No E1 production envelope, stability superiority, ensemble scaling, useful speedup or admission follows here. A26's accepted-state-frozen split and existing ownership remain unchanged; central regie owns canonical admission.

## Reproduction

At the executed code SHA:

```bash
python3 research/rfm/a27/probe_lateral_profile.py /tmp/a27-lateral-profile
```

The script regenerates trajectories, profiles, reference refinement, candidate comparisons, solver counters and summary. Numerical/package versions and raw output hashes are in docs/audits/evidence/PPA_WU05A27_LATERAL_MANIFEST.json. Concatenate PPA_WU05A27_LATERAL.tar.gz.part-* in lexical order and extract the gzip tar. It contains all raw outputs and both success/failure logs. Documentation/source checks and strict MkDocs verification are recorded separately. Source code and evidence are durable on the A27 branch; production qualification and canonical admission remain false.
