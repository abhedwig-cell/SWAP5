# F-VZAA01 Final Qualification Reconciliation

## Decision

F-VZAA01 is closed as:

`NOT_QUALIFIED_FOR_CURRENT_SWAP5_SOLVER_OR_DONOR_ADMISSION`

This is a fail-closed SWAP5 suitability decision under the current source and evidence set. It is not a universal scientific falsification of VZAA.

No D1 bounded-history work and no production VZAA solver family are authorized from this evidence.

## Authoritative evidence reconciled

This reconciliation starts from F-VZAA01 head:

`cffeed211b4bc6f3389ed12ba555253d905f993e`

and consumes the independent F-VZAA02 closeout:

`80157dc2beb9bb2ceb0cbcf00c984eb2662317d9`

whose tested executable head is:

`8c394d3e282ec427ece8c10b2ff57b0ce4a2f900`

with successful GitHub Actions run `34323697236` and artifact `10092928409`.

The older branch `work/f-vzaa01-d0-donor-separability-evidence` is not used as an authoritative base because it is strongly diverged from the current F-VZAA01 lineage.

## Resolution of the three original qualification questions

### 1. Is the published VZAA formulation itself suitable for SWAP5?

No, not under the current SWAP5 hard gates.

The fixed-layer Eq. 8 core can be written as an algebraically exact balance identity, but the complete published formulation is not qualified for the SWAP5 accepted-step ledger, general prescribed bottom head/flux semantics, heterogeneous interfaces, response tangents or bounded runtime.

Literal Eq. 5 history requires run-length-dependent history state. Direct evaluation has total trajectory work of order:

`O(N_layers * N_steps^2)`

before local solve/substep multipliers.

The official DOI-linked MATLAB supplement remains uncaptured, so this is not an official-code reproduction.

### 2. Can VZAA be made suitable by a bounded, explicit, mass-conserving modification?

A narrow algebraic part is feasible, but the complete derived route is not qualified.

The conservative derivative shell gate showed that exact external-flux bookkeeping, pairwise internal debit-credit transfer, explicit head residuals and transaction-safe rejection can be enforced to roundoff in isolation. The successful algebra gate had maximum accepted mass residual about `8.05e-16`.

That does not qualify:

- VZAA hydraulic predictor fidelity;
- bounded half-order history;
- prescribed-head corrector convergence;
- bidirectional groundwater coupling;
- response tangents;
- production solver admission.

The algebraic shell is therefore retained as research evidence, not promoted to a separate solver family.

### 3. Does VZAA provide a useful algorithmic donor for the current reduced-order route?

No for the tested D0 ordinary homogeneous matrix.

F-VZAA02 used only candidate committed moisture history and kept FullRichards strictly as reference evidence. The D0 diagnostic was never booked into the accepted water ledger.

The decisive counterexample is `redistribution_sand`:

- refinement 1: `0/160` VZAA points closer to FullRichards and `0/160` correction directions agree;
- refinement 2: `0/320` VZAA points closer to FullRichards and `0/320` correction directions agree.

All non-trivial homogeneous case/refinement combinations in the executed ordinary matrix had larger VZAA mean absolute midpoint-flux error than the current LayeredMFP candidate.

The F-VZAA02 contract explicitly says to run the smallest ordinary case first and expand only if the signal is not immediately falsified. Therefore no strong-gradient, reversal, shallow-groundwater or bounded-history expansion is required after this robust negative first-stage result.

## Gate reconciliation

Current gate position:

- scientific reconstruction: sufficient for this feasibility decision, with source limits;
- official-code reproduction: open because the MATLAB supplement is not captured;
- exact conservation of the complete published formulation: not qualified;
- general bottom head/flux contract: not qualified;
- heterogeneous interfaces: not qualified;
- bidirectional groundwater interface: not qualified;
- literal Eq. 5 reference: qualified as reference only;
- bounded runtime: failed for literal full history;
- conservative derivative shell: algebraically qualified, research only;
- D0 donor separability: failed scientific qualification;
- D1 bounded-history candidate: not authorized;
- production solver admission: not authorized.

## SWAP5 architecture consequences

The negative qualification avoids adding complexity without demonstrated value:

- no new production soil-water solver family;
- no per-column unbounded fractional history;
- no new rollback/restart burden for history state;
- no accepted VZAA transfer;
- no mass-conservation concession;
- no MODFLOW-specific assumption;
- no calendar-day dependency;
- no new dependency on HeadCalc internals;
- no erosion of MultiSWAP bounded-cost goals.

This is consistent with the core invariants on compact persistent state, transactionality, generic time, predictable runtime, exact mass conservation and scalable MultiSWAP execution.

## Reopen policy

F-VZAA01 may be reopened only on material new evidence, for example:

1. authoritative DOI-linked or author-provided MATLAB code becomes available and materially changes the reconstructed algorithm;
2. new primary-source evidence resolves the complete discrete-ledger or lower-boundary limitations;
3. a genuinely different SWAP5 use case establishes a new donor hypothesis not already covered by the current D0 falsification.

Any reopening begins with source/evidence reconciliation. It does not silently resume D1 or production implementation.

## Final routing

Do not open D1 from the present VZAA line.

Do not create a production VZAA solver family.

Retain F-VZAA01 and F-VZAA02 as negative qualification evidence and direct reduced-order soil-water effort toward LayeredMFP and other independently qualified candidates unless new evidence materially changes this assessment.

Final status:

`CLOSED_NOT_QUALIFIED_CURRENT_VZAA_TRACK_NO_D1_NO_PRODUCTION_ADMISSION`
