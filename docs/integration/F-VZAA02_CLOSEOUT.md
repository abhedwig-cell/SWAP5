# F-VZAA02 Closeout — D0 donor separability falsified

## Decision

F-VZAA02 is closed as:

`NOT_QUALIFIED_VZAA_D0_DONOR_SIGNAL_FALSIFIED_ON_ORDINARY_HOMOGENEOUS_MATRIX`

D1 bounded-history work is **not authorized** from this workunit.

This is a negative scientific qualification result, not a failed implementation. The executable D0 harness, trajectory capture, mass-ledger reconstruction and source-bound VZAA diagnostic all completed successfully on the tested head.

## Tested evidence

Tested head:

`8c394d3e282ec427ece8c10b2ff57b0ce4a2f900`

GitHub Actions:

- workflow: `F-VZAA02 Donor Separability D0`
- run: `34323697236`
- job: `102375966636`
- conclusion: `success`
- artifact: `10092928409`
- artifact digest: `sha256:dc8c03add2e373b6e2b08f4893a85324450bab10d620338a67eb0f19919f3f40`

The run contains 660 aligned accepted steps and 2640 layer-step diagnostic points. Candidate history is built only from committed LayeredMFP states. FullRichards states are not used in the VZAA history term.

The reconstructed FullRichards bottom-ledger identity mismatch is at most `5.551115123125783e-17` in absolute value.

## D0 result

The precommitted hypothesis required the raw source-bound VZAA layer-centred flux signal to provide a stable and materially distinct diagnostic benefit over the existing LayeredMFP candidate before any compressed-history or trial-influence experiment would be justified.

That condition is not met.

For every non-trivial homogeneous case at both tested time refinements, VZAA has a larger mean absolute midpoint-flux error than LayeredMFP.

### Redistribution sand

This is the decisive ordinary homogeneous counterexample.

Refinement 1:

- points: 160
- LayeredMFP mean absolute error: `0.0389758740777444`
- VZAA mean absolute error: `0.13693217839885255`
- VZAA closer to FullRichards: `0 / 160`
- VZAA correction direction agrees with the required LayeredMFP correction: `0 / 160`

Refinement 2:

- points: 320
- LayeredMFP mean absolute error: `0.03887476713734107`
- VZAA mean absolute error: `0.13636940594942074`
- VZAA closer to FullRichards: `0 / 320`
- VZAA correction direction agrees with the required LayeredMFP correction: `0 / 320`

The negative result is therefore stable under the tested refinement and does not depend on a scientific admission tolerance.

### Infiltration sand

VZAA occasionally points in the required correction direction, especially at refinement 2, but it remains much less accurate on average than the existing LayeredMFP candidate.

Refinement 1:

- LayeredMFP mean absolute error: `2.7876198408168085e-06`
- VZAA mean absolute error: `0.011425869889813187`
- VZAA closer fraction: `0.09375`
- direction-agreement fraction: `0.33125`

Refinement 2:

- LayeredMFP mean absolute error: `1.2798035303315654e-06`
- VZAA mean absolute error: `0.011411990015642522`
- VZAA closer fraction: `0.084375`
- direction-agreement fraction: `0.64375`

This is not sufficient donor value under the fail-closed contract because a mixed result cannot qualify.

### Infiltration clay

The same pattern occurs for clay.

Refinement 1:

- LayeredMFP mean absolute error: `3.028803591248778e-07`
- VZAA mean absolute error: `0.0010033765183355926`
- VZAA closer fraction: `0.105`
- direction-agreement fraction: `0.44`

Refinement 2:

- LayeredMFP mean absolute error: `4.0128610242984567e-07`
- VZAA mean absolute error: `0.0010015275914303692`
- VZAA closer fraction: `0.0925`
- direction-agreement fraction: `0.7775`

Again, directional information exists at some points, but it is not accompanied by competitive flux accuracy and therefore does not justify a separate history-bearing donor mechanism.

## Source boundary

The diagnostic is an independent source-bound reconstruction using:

- Sadeghi et al. (2026), Journal of Hydrology 673, 135467, DOI `10.1016/j.jhydrol.2026.135467`, Eqs. 3, 5, 6 and 7;
- Sadeghi et al. (2022), Journal of Hydrology 610, 127999, DOI `10.1016/j.jhydrol.2022.127999`, van Genuchten Eqs. 28 and 30;
- the F-VZAA01 qualified literal Eq. 5 reference lineage.

For D0-A deep-groundwater/free-drainage conditions, `K_d` is treated as negligible, so the Eq. 3 steady term reduces to `K(theta)`.

The DOI-linked official MATLAB supplement remains uncaptured. This workunit therefore does not claim official-code reproduction and does not universally falsify the published VZAA method.

## Runtime and state implication

Literal Eq. 5 history evaluation required 91,320 direct history-term evaluations for this small matrix. Direct evaluation has total trajectory work of order:

`O(N_layers * N_steps^2)`.

A bounded-memory representation could in principle change that cost structure, but D1 was explicitly conditional on the uncompressed raw signal first demonstrating material donor value. Because D0 fails that gate, implementing compressed fractional history would add state, rollback/restart semantics and runtime complexity without an established accuracy or applicability benefit.

## Architecture assessment

No production-kernel change was made.

The workunit preserves the SWAP5 invariants relevant here:

- no new solver family;
- no new production persistent history state;
- no change to FullRichards or LayeredMFP accepted transfers;
- no mass-conservation concession;
- no MODFLOW-specific assumption;
- no day-bound time semantics;
- no reference-state leakage into the candidate history;
- no new dependency on HeadCalc internals outside the experiment seam.

The FullRichards ledger remains evidence only. The raw VZAA signal is never booked as an accepted transfer.

## Consequence for the broader VZAA track

F-VZAA01's D0 donor-separability question is resolved negatively for the tested ordinary homogeneous matrix.

The compressed fractional-history path should remain deferred. F-VZAA02 provides no basis for promoting it to D1.

The conservative VZAA-derived solver hypothesis is not evaluated by this workunit and remains a separate, already-deprioritized research hypothesis. Nothing here justifies opening a new production solver family around it.

For reduced-order soil-water work, effort should return to the already stronger LayeredMFP line and other independently qualified alternatives unless new primary-source or official-code evidence changes the VZAA assessment materially.

## Final status

`CLOSED_NOT_QUALIFIED_D0_DONOR_SIGNAL_FALSIFIED_D1_NOT_AUTHORIZED`
