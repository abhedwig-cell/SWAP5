# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `PREREGISTERED / PERCHED_PRODUCTION_DEPENDENCY`

Research baseline:
`research/ppa-wu05-a18-perched-authority-fixture@5434665c34cff570066ccd2d76e10a092f7979d7`.

Current canonical reconciliation:
`integration/f-ci-canonical@641a8ba7fad5b67f0ebff7c78dd065270ed46329`.

Namespace rule:

This workunit uses the dedicated `PPA-WU05-PERCH` namespace. Generic A11-A18 research
documents are not candidates for wholesale canonical merge because canonical now owns
overlapping generic PPA identifiers for RFM work.

## Purpose

Represent the exact B1.11 macropore exchange-reduction ladder required by the qualified
A18 source-backed perched case without hardcoding `FrReduQ=0.1`.

## Exact source semantics

B1.11 `MACRORATE` computes:

`FrReduQ = 0.1 ** IDecMpRat`.

`IDecMpRat` is bounded to 0..3, yielding:

`[1.0, 0.1, 0.01, 0.001]`.

On nonlinear failure, exact HeadCalc first requests a smaller timestep while the timestep
can still be reduced.

Only when the minimum timestep is active and `IDecMpRat<3` does it increment
`IDecMpRat` and retry the same timestep with reduced macropore exchange.

On later successful execution, legacy can relax the reduction level after accepted-step
history. That recovery memory is numerical continuation, not physical macropore state.

## PERCH19 bounded target

### G1 — dtmin-gated retry ladder

For the explicit inner-Richards route:

- factor 1.0 is always attempted first unless a future admitted numerical continuation
  contract explicitly supplies another start level;
- if the solve requests retry and `dt > min_step_duration`, return retry to the temporal
  owner without changing FrReduQ;
- if the solve requests retry at numerical dtmin, retry the same accepted-state trial with
  factors 0.1, 0.01 and 0.001 in order;
- stop at the first converged solve;
- after factor 0.001 fails, return the normal retry/failure status.

### G2 — trial isolation

Every ladder attempt starts from the same accepted matrix and seven-field macropore state.

Failed factors may mutate only solver/provider scratch.

No failed factor may publish:

- matrix candidate;
- macropore candidate;
- sorptivity history;
- geometry continuation;
- restart state.

### G3 — exact rate scaling

The selected factor must be applied consistently to all exact A6 surfaces controlled by
legacy `FrReduQ`:

- unsaturated absorption;
- perched saturated exchange;
- ordinary saturated exchange;
- rapid drainage.

No top-input ownership is scaled unless exact source authority says so.

### G4 — A18 source-backed perched qualification

On the qualified 112-node A18 fixture, with the request explicitly at numerical dtmin:

- factor 1.0 must be attempted and rejected/retried;
- factor 0.1 must be the first accepted level, matching A18 evidence;
- active perched inner exchange must remain nonzero;
- matrix/macropore internal mass residual must pass;
- macropore balance must pass;
- accepted external macropore state must remain unchanged until publication.

### G5 — preservation

With the ladder policy disabled, A16/A17 behavior remains unchanged.

The A8-A10 canonical/default outer route remains unchanged.

## Recovery semantics boundary

PERCH19 qualifies the **within-trial reduction ladder** and its dtmin gate.

The legacy cross-accepted-step recovery memory (`NStep`, `dtold`, decrement of
`IDecMpRat`) is not silently added to physical continuation state.

PERCH19 must record whether production requires that numerical continuation memory for
efficiency/source-equivalence. If required, it becomes an explicit numerical-state
follow-up with restart semantics rather than being hidden in HeadCalc.

## Decision states

- `QUALIFIED_SOURCE_FAITHFUL_DTMIN_FREDUQ_LADDER`;
- `REQUIRES_NUMERICAL_CONTINUATION_STATE`;
- or `FALSIFIED_FREDUQ_LADDER_ROUTE`.

No canonical admission is performed from this research branch.
