# PUB-GC / COUPLE — fixed-interface theory handoff

Date: 2026-09-23  
Status: **EDITORIAL_HANDOFF_TO_COUPLE_MANUSCRIPT**  
Target manuscript: `docs/publication/PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md`

## Purpose

This note preserves the theoretical interpretation reached after closure of the bounded
SWAP5–MODFLOW6 fixed-interface coupling line and transfers it explicitly into the
publication workstream.

The earlier SWAP4–MODFLOW6 project/process report is development documentation, not the
prior scientific publication against which the COUPLE paper must be framed as an
incremental extension. The paper should therefore present the present SWAP5–MODFLOW6
method as one coherent primary scientific formulation. The process report may be used
for development history where useful, but it should not constrain the scientific
structure or novelty narrative of the manuscript.

## Core mathematical continuity

The present method preserves the central predictor–corrector coupling idea:

1. start from one committed SWAP state at the beginning of the coupling window;
2. run a SWAP predictor over the new window under the new stresses and a provisional
   lower-boundary condition;
3. condense the SWAP lower-boundary response into a local affine response for MODFLOW6;
4. solve MODFLOW6 for an updated fixed-interface head;
5. replay the same SWAP window from the same committed origin at that head;
6. accept only when the physical SWAP and MODFLOW6 interface exchange is consistent.

The historical coefficient
```
u = Δt / (∂H_end/∂q_bot)
```
has the local differential counterpart
```
u/Δt = ∂q/∂H
```
when the local response is invertible. Thus the old `u, q_u` affine formulation and
the current `q, dq/dH` formulation are locally the same mathematical response form.
The plus/minus bottom-flux perturbations were one numerical way to estimate the local
response; they are not fundamental to the coupling mathematics.

## What is materially sharpened in SWAP5

The current formulation should be presented explicitly, not as an implementation footnote:

- **Fixed interface state.** The exchanged state is hydraulic head at a fixed lower SWAP
  coupling plane; it is not automatically the phreatic groundwater-table elevation.
- **Physical exchange.** The accepted coupling closes on the physical fixed-interface
  exchange, with one explicit sign convention and action/reaction mapping.
- **Finite-window response.** The response coefficient is a condensed local SWAP
  response/Jacobian over the coupling window. It must not be interpreted automatically
  as an independent physical MODFLOW storage coefficient.
- **Direct trajectory tangent.** The accepted SWAP trajectory can provide the local
  physical derivative without separate `+Δq/-Δq` full nonlinear runs.
- **Relinearization.** A non-converged corrector yields both a new physical flux and a
  new physical tangent. The MODFLOW term is rebuilt around the current point rather
  than keeping the predictor coefficient frozen throughout the outer iteration.
- **Immutable origin.** Predictor and every corrector replay the same physical window
  from the same committed SWAP origin. Trial states do not advance physical time.
- **Transactional authority.** Rejected predictor/corrector candidates have no committed
  state or mass authority; only the final accepted trajectory is published.
- **Fail-closed bounded profile.** Storage role, drainage ownership, response provenance,
  restart state and publication order are explicit parts of the admitted contract.

## Numerical interpretation

The difference between the earlier frozen-response iteration and the current method is
best described as a numerical strengthening of the same coupled problem.

Earlier conceptual form:
```
q(H) ≈ q* + k_predictor (H-H*)
```
with a response slope effectively held fixed during the outer coupling iteration.

Current form after corrector `i`:
```
q(H) ≈ q_i + k_i (H-H_i)
k_i = (dq_SWAP/dH)|_i
```
followed by MODFLOW6 relinearization.

This changes the nonlinear iteration from a frozen-Jacobian/modified-Newton-like scheme
toward a locally relinearized Newton-like partitioned coupling. It does **not** define a
different physical endpoint: both formulations seek the same fixed-interface
state/flux consistency.

## Publication positioning

The COUPLE manuscript should not be organized as “an improvement to the process-report
method.” It should derive the final method cleanly from the coupled physics:

```
fixed interface
→ finite-window SWAP response q_SWAP(H)
→ local tangent dq/dH
→ MODFLOW6 affine boundary term
→ predictor / physical corrector
→ relinearization when needed
→ transaction-safe acceptance and publication
```

The scientific novelty discussion must still be based on an external literature review.
Individual ingredients such as partitioned iteration, Newton linearization, Schur-like
response condensation or Dirichlet–Neumann concepts should not be claimed as new merely
because they were not formally published in the project report.

The candidate contribution to establish against the literature is the **hydrologically
accountable combination** for a stateful, independently time-integrating Richards-column
model coupled to MODFLOW6, including:

- finite-window state and flux semantics;
- physically derived accepted-trajectory sensitivity;
- repeated correctors from an immutable state origin;
- explicit storage/process ownership;
- provenance-bound response reuse;
- fail-closed transaction and restart semantics;
- independent endpoint and mass-conservation evidence.

## Required manuscript integration

For the next substantive COUPLE manuscript revision:

1. revise the Methods section so the complete current fixed-interface formulation is
   the primary derivation;
2. connect `u/Δt` explicitly to the local response derivative while avoiding an
   independent-storage interpretation;
3. describe one predictor plus one-or-more physical correctors, including tangent
   refresh and relinearization;
4. state clearly that two full SWAP trajectories per coupling window is the minimum,
   not a guaranteed fixed count;
5. separate generic numerical ingredients from the paper's hydrological/accountability
   contribution in the Discussion;
6. use the closed fixed-interface canonical evidence as the implementation and
   qualification authority.

## Authority anchor

The bounded fixed-interface implementation was closed on canonical with verdict
`CANONICAL_ADMITTED_CLOSED`. The terminal closeout witness is commit
`a2d99ddd149ffaa422d9c422f96bd66e92c8555d`; the authority artifacts include:

- `integration/f-gc/F-GC_FIXED_INTERFACE_CANONICAL_ADMISSION.json`
- `integration/f-gc/F-GC_FIXED_INTERFACE_COUPLING_CONTRACT.json`
- `integration/f-gc/F-GC_FIXED_INTERFACE_CLOSEOUT_STATUS.json`
- `docs/integration/SWAP5_MODFLOW6_FIXED_INTERFACE_CLOSEOUT.md`

This note is an editorial handoff. It does not widen the bounded production admission
and does not create new physical or numerical evidence.
