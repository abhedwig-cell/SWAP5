# F-VZAA02 - VZAA Donor Separability, Trajectory Capture & Diagnostic Flux Falsification

## Workunit identity

- Workunit: `F-VZAA02`
- Type: cross-track experimental evidence / falsification
- Branch: `work/f-vzaa02-donor-separability`
- Exact executable base: F-LMFP08 qualified closeout `7ce558267a7fd36ae508a5c2229f996c916ff61a`
- F-LMFP08 decisive candidate evidence head: `4ecc84210f6af4cbc4528b8b4a23b8c63093fbd8`
- F-VZAA01 source/audit lineage checkpoint: `2ce4ab5cb7f89210d04f809d7f020e1bdc5c8a76`
- Started: 2026-09-09
- Production implementation: **forbidden**
- New soil-water solver family: **forbidden in this workunit**

## Why this workunit exists

F-VZAA01 established that the published VZAA formulation is not directly admissible for SWAP5 because the complete published method does not satisfy the required exact accepted-step mass ledger, does not provide a general prescribed bottom head/flux contract, and literal evaluation of the full fractional moisture history has non-compact state and non-bounded run-length-dependent cost.

F-VZAA01 also established a narrower research question: the published VZAA analytical flux relation contains a history-aware transient diffusive contribution that might contain useful predictive information even if the VZAA state-update algorithm itself is rejected.

This workunit tests only that narrow donor hypothesis.

## Stable base selection

F-VZAA02 deliberately does **not** start from the live F-LMFP09 branch tip.

At reservation time, `work/f-lmfp09-hydraulic-envelope-geometry` had advanced to `f2841b3be3e7553eabb39d86c17d571e23228b5c`, a precommit for new C3b off-grid holdout work. That live tip contains active qualification work outside the needs of this experiment.

F-VZAA02 therefore starts from the qualified F-LMFP08 closeout `7ce558267a7fd36ae508a5c2229f996c916ff61a`, which explicitly records the successful constrained continuous MFP log-Darcian-ratio evidence from head `4ecc84210f6af4cbc4528b8b4a23b8c63093fbd8`.

This isolates the donor test from concurrent F-LMFP09 changes and avoids creating hidden dependency on unqualified work.

## Scientific hypothesis

Primary falsifiable hypothesis:

> Using only the candidate solver's own committed moisture history, the source-bound VZAA layer-centred analytical flux estimate contains a stable diagnostic signal that is closer to FullRichards accepted transfer, or predicts the direction of the LayeredMFP flux error, in at least one physically identifiable regime where current LayeredMFP error is material.

Failure of this hypothesis ends the donor path for the tested regime.

Passing this hypothesis does **not** admit a VZAA-derived solver. It only allows a later bounded-representation experiment.

## Source boundary

Primary VZAA publication:

Sadeghi et al. (2026), "Vadose zone analytical algorithm (VZAA): a non-iterative algorithm for vadose zone soil moisture and groundwater recharge", Journal of Hydrology 673, 135467. DOI `10.1016/j.jhydrol.2026.135467`.

Methodological precursor:

Sadeghi et al. (2022), "Estimating soil water flux from single-depth soil moisture data", Journal of Hydrology 610, 127999. DOI `10.1016/j.jhydrol.2022.127999`.

The DOI-linked official MATLAB supplement has not yet been directly captured. Consequently, any Eq. (3)/(5)/(6)/(7) implementation in F-VZAA02 is labelled **independent reconstruction**, not official VZAA reproduction.

Gate B from F-VZAA01 therefore remains open.

## Non-negotiable architecture rules

F-VZAA02 must preserve all SWAP5 architecture invariants. In particular:

- accepted LayeredMFP and FullRichards physics are unchanged;
- exact mass conservation remains a hard gate;
- no raw VZAA diagnostic flux is booked as an accepted transfer;
- no production `soil_water_solve_result_t` field is added solely for this experiment;
- no HeadCalc internal array becomes a generic dependency;
- experiment-only raw trajectories are evidence artifacts, not persistent production column state;
- candidate history uses only committed candidate states, never FullRichards states;
- rejected trials do not enter history;
- no calendar-day assumption is introduced;
- no MODFLOW-specific logic is introduced;
- reference mode remains unchanged;
- numerical tolerances are not invented to manufacture a pass.

## Existing reference seam

F-VZAA01 source-bound the existing F-LMFP04 FullRichards A/B driver and found that it already runs one explicit solver call per time step:

`solver%solve(request, ws, result)`

The driver receives:

- candidate pressure head;
- candidate water content;
- realized top flux;
- realized bottom flux;
- diagnostics;

before manually committing the candidate to `request%base_state`.

Therefore D0-A requires only an experiment-level trajectory recorder.

The public soil-water result does not expose internal face fluxes, and F-VZAA02 will not widen that production contract for this experiment.

## Ledger-consistent reference face reconstruction

For the current D0-A cases, distributed source and sink providers are zero.

Use downward-positive evidence notation.

For layer `i` over accepted step `n`:

`Delta S_i = dz_i * (theta_i^{n+1} - theta_i^n)`.

Convert the realized FullRichards top flux from its upward-positive convention:

`Q_0 = -result%top_flux`.

Then reconstruct internal ledger faces recursively:

`Q_i = Q_{i-1} - Delta S_i / dt`.

The layer-midpoint reference flux is:

`Q_ref_mid,i = 0.5 * (Q_{i-1} + Q_i)`.

The reconstructed final face is independently checked against `-result%bottom_flux`. The mismatch is retained as evidence and must be consistent with the accepted FullRichards mass residual.

This ledger face is the primary D0 reference. A final Darcy-face cross-check may be added later only if needed, and must remain diagnostic.

## Candidate trajectory capture

The existing LayeredMFP Python transient harness already advances candidate state one accepted trial at a time. F-VZAA02 may extend the experimental harness to record, per accepted step:

- old and new storage/water content;
- pressure head reconstructed from accepted storage where already available;
- accepted face-flux vector;
- midpoint flux vector;
- mass residual;
- face-iteration count;
- retry/rejection diagnostics;
- elapsed generic time.

No rejected trial is appended to VZAA history.

## D0 source-bound diagnostic

For each layer/time, independently reconstruct the published VZAA history signal from the candidate's own committed moisture history.

Required terms:

`q_hist,i = -sqrt(c_i * D_i(theta_i)) * H_i`

`q_steady,i = K_si * (K_i(theta_i) - K_d,i) / (K_si - K_d,i)`

`q_vzaa_mid,i = q_hist,i + q_steady,i`.

For the first D0-A deep-groundwater/free-drainage cases, any simplification of `K_d` must be explicitly documented and source-bound. Do not silently substitute a new groundwater model.

The published empirical direction factor is reconstructed as stated by the paper, including the `H`-dependent switch, but is not treated as a qualified SWAP physical law.

## Comparison quantities

For each layer and accepted step:

`e_vzaa = q_vzaa_mid - q_ref_mid`

`e_lmfp = q_lmfp_mid - q_ref_mid`

`delta_q = q_vzaa_mid - q_lmfp_mid`

`e_needed = q_ref_mid - q_lmfp_mid`.

Required characterization includes:

- absolute and relative flux error where meaningful;
- sign agreement between `delta_q` and `e_needed`;
- cases/times/layers where VZAA is closer than LayeredMFP;
- refinement stability;
- start-up behaviour;
- behaviour near the empirical `H=0` switch;
- dry and near-saturated tails;
- diagnostic history length and arithmetic work;
- all NaN/domain/reconstruction failures.

No physical-admission tolerance is declared before seeing characterization evidence.

## Initial case scope

D0-A begins with the existing F-LMFP04/F-LMFP07 hydraulic-only family that can be reproduced from the qualified base.

Priority is the already characterized ordinary and strong-gradient cases.

No new crop, root uptake, drainage, ponding, groundwater-coupling or heterogeneous VZAA interface physics is added merely to enlarge the matrix.

Heterogeneous LayeredMFP cases may be retained as falsification evidence, but no VZAA analytical interface claim is made across a material discontinuity because the published VZAA relation was derived for uniform soil and the paper reports degraded layered-soil performance.

## Fail-closed D0 decision logic

Reject the donor for a regime if, under refinement, any of the following is robust:

- the VZAA diagnostic is consistently less accurate than current LayeredMFP;
- `delta_q` usually points opposite to `e_needed`;
- signal direction changes materially under time refinement;
- the `H=0` switch produces a material unstable/discontinuous diagnostic;
- useful behaviour requires FullRichards/reference history;
- the signal is too small or redundant to justify additional history state and work;
- diagnostic evaluation fails in ordinary hydraulic states inside the candidate's intended envelope.

A mixed result is `NOT_QUALIFIED`, not a pass.

## Explicit non-goals

F-VZAA02 will not:

- implement the conservative forward/backward VZAA-derived solver hypothesis;
- modify accepted LayeredMFP fluxes;
- add compressed fractional history to production;
- change FullRichards equations;
- implement prescribed groundwater head or MODFLOW coupling;
- derive response tangents;
- merge into the active F-LMFP09 owner branch;
- claim official VZAA reproduction without the official supplement.

## Persist-early sequence

1. Persist this contract.
2. Add the smallest time-resolved FullRichards reference recorder and tests.
3. Add candidate trajectory recording without changing accepted trial physics.
4. Persist raw reference/candidate evidence format before long runs.
5. Add the independent VZAA history diagnostic.
6. Run the smallest ordinary case first.
7. Expand only if the signal is not immediately falsified.
8. Persist characterization before any broader interpretation.

## Initial status

- investigated: F-VZAA01 theory/conservation/runtime audit; F-LMFP08 stable base; FullRichards step-level capture seam
- implemented: contract only
- persisted: contract
- tested: not yet on F-VZAA02
- reproduced: no official VZAA supplementary run
- qualified: nothing in F-VZAA02 yet
- open: reference recorder, candidate recorder, independent Eq. (3)/(5)/(6)/(7) reconstruction, D0-A execution and falsification decision

Current status:

`D0_DONOR_SEPARABILITY_RESERVED_ON_QUALIFIED_LMFP08_BASE__NO_PRODUCTION_CHANGE`
