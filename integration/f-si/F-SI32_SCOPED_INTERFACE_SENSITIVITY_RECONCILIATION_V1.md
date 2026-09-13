# F-SI32 Scoped Interface Sensitivity / Coupling Preconditioner Reconciliation v1

## Status

Owner/reconciliation candidate. This workunit starts from exact current canonical
`integration/f-ci-canonical@c19a04721a05c6a00ba264e7477969807dcb258f`.

F-SI32 does not admit a new production solver, does not modify frozen F-SI31 v1,
and does not admit response-tangent consumption into the production predictor-corrector.

## Problem being closed

F-SI28 qualified an optional same-factorization bottom-interface sensitivity from
the final accepted Full Richards / HeadCalc linearization. That producer value is
numerically useful, but its raw solver carrier has only availability, value and
method. It does not itself state whether the value is a local terminal response,
a derivative of a composed transaction horizon, or a derivative of a complete
coupling window.

Current canonical already adds the missing semantic boundary outside the solver:

* the transaction contract publishes accepted sensitivities as
  `TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL`;
* `origin_t0` and `origin_t1` identify the accepted solve segment that produced
  the value;
* `covers_requested_interval` reports only whether that origin segment equals
  the requested transaction/canonical interval;
* the canonical runtime publishes only the final accepted transaction's terminal
  sensitivity and forces interval coverage false when more than one accepted
  transaction was needed;
* the kernel copies the structured sensitivity result without relabelling it;
* the F-CI56 predictor-corrector does not consume interface sensitivity and
  explicitly did not admit F-GC23 response-tangent composition.

The closure requirement is therefore semantic qualification and executable
protection of this existing seam, not a second scope field in F-SI28 and not a
new production algorithm.

## Normative v1 semantics

### S1. Local-terminal is the only currently admitted sensitivity semantic

`TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL` means that the value belongs to the
terminal accepted soil-water solve segment represented by its producer
linearization.

It MUST NOT be interpreted as any of the following unless a future, separately
qualified contract explicitly says so:

* derivative of a sequence of accepted transaction substeps;
* derivative of the complete canonical `[t0,t1]` interval;
* derivative of a groundwater coupling window;
* Newton Jacobian of a SWAP-MODFLOW coupled residual.

### S2. Origin coverage and derivative scope are orthogonal

`origin_t0`, `origin_t1` and `covers_requested_interval` are provenance metadata.

`covers_requested_interval = true` means only that the accepted solve segment
that produced the local-terminal value has the same temporal endpoints as the
requested interval, subject to the existing runtime checks. It MUST NOT upgrade
`LOCAL_TERMINAL` to a whole-window derivative.

This distinction remains necessary even when a single transaction call spans the
requested interval because the physical solver may itself use internal nonlinear,
timestep, retry or constitutive operations that are not represented by a composed
whole-window response derivative.

### S3. Transaction publication is fail-closed

A rejected trial never publishes its sensitivity. The transaction layer owns
accepted-route provenance.

For the external full/half route, the accepted two-half solution publishes only
the second half's sensitivity, with the second half as origin and coverage false
for the original requested interval.

For a model-certified accepted solve, the transaction publishes the accepted
solve's local-terminal sensitivity. If retry shortens the accepted interval,
coverage of the original requested interval is false.

### S4. Canonical runtime may transport but not compose a local tangent

If a canonical interval requires multiple accepted transaction substeps, only the
last accepted transaction's local-terminal sensitivity may be transported as the
terminal sensitivity. The runtime MUST NOT algebraically compose or average those
values unless a future separately qualified composition contract is introduced.

`covers_requested_interval` must remain false for such a multi-transaction
canonical interval.

### S5. Kernel transport preserves semantics exactly

Kernel publication may copy the transaction/runtime sensitivity carrier, but may
not change its semantic classification, origin interval or coverage flag.

Sensitivity is result metadata. It is not persistent physical column state and it
is not solver scratch.

### S6. A coupling preconditioner is not a derivative by declaration

A future coupling algorithm may define a separate, explicitly qualified
preconditioner capability that uses a `LOCAL_TERMINAL` response as one input.
Such a preconditioner is an algorithmic numerical hint, not automatically a
physical whole-window derivative.

Correctness and publication MUST remain governed by rerunning the physical window
from the proper committed checkpoint, evaluating the actual interface residual,
finite-state validity and hard mass conservation. Unsupported scope, unavailable
sensitivity or invalid numerical use must fail closed to the qualified fallback
or non-tangent route.

### S7. F-ROSS01 J1E-D1 remains research-only evidence

`work/f-ross01-d1-chat-pilot@9deddef0294ea14ea1ed418ce6688bfc7b136c53`
qualified a restricted research route in which
`B_pre = n_substeps * local_terminal_tangent` behaved well for its constant-qbot,
equal-substep research matrix.

F-SI32 does NOT promote that construction to production. In particular it makes
no claim for adaptive or nonuniform substeps, time-varying qbot, nonsmooth route
changes, MODFLOW end-to-end coupling or a true whole-window derivative.

### S8. Frozen F-SI31 v1 is unchanged

`work/f-si31-research-solver-contract-freeze@4190ede0b17e81abe806430cc9a4c94a21995917`
remains the frozen research-solver compatibility contract. F-SI32 does not add a
sensitivity member to `SoilWaterResponse` and does not change its schema.

Any future research-solver sensitivity extension must be optional/versioned and
must preserve F-SI31 v1 compatibility.

## Current-canonical qualification obligations

The F-SI32 gate must prove on the exact branch head that:

1. two-half acceptance publishes only the terminal half sensitivity as
   `LOCAL_TERMINAL`, with coverage false;
2. a single accepted model-certified interval can have coverage true while the
   semantic remains `LOCAL_TERMINAL`;
3. a retry-shortened accepted interval keeps coverage false;
4. O0 and O2 produce identical test output;
5. canonical runtime only transports the final accepted terminal sensitivity and
   only permits requested-interval coverage for one accepted transaction;
6. kernel transport copies the structured sensitivity without semantic upgrade;
7. current F-CI56 predictor-corrector still has no `interface_sensitivity`
   consumer;
8. current production transaction/runtime/kernel code exposes no whole-window
   sensitivity classification;
9. no production `src/` file is changed by F-SI32.

## Architecture-invariant audit

F-SI32 is consistent with the SWAP core invariants because it:

* keeps solver numerical detail behind the soil-water boundary;
* keeps sensitivity as optional result metadata rather than persistent state;
* leaves transaction ownership of checkpoint/retry/commit/rollback intact;
* preserves generic `[t0,t1]` and coupling-window semantics;
* prevents a local numerical response from being silently promoted to a coupled
  physical derivative;
* keeps hard mass conservation as a publication condition for future consumers;
* separates physical solver meaning from numerical coupling/preconditioner policy;
* imposes no per-column persistent-memory cost when sensitivity is unused;
* leaves MultiSWAP batching, worker scratch and runtime composition unchanged.

## Hard nonclaims

F-SI32 does not claim:

* a true whole-window response tangent;
* F-GC23 production response-tangent composition;
* production RossFast admission;
* modification or requalification of frozen F-SI31 v1;
* change to Full Richards physics or HeadCalc numerics;
* MODFLOW or aquifer-solver end-to-end qualification;
* performance qualification of tangent consumption;
* canonical admission of this workunit.

A future production response-tangent/coupling-preconditioner workunit must start
from then-current canonical, consume this semantic distinction explicitly and be
independently qualified before canonical admission.
