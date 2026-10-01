# PPA-WU05-A14 preregistration — inner-Richards macropore rate evaluation

Date: 2026-10-01

Status: `PREREGISTERED / ARCHITECTURE_RESEARCH`

Baseline: `research/ppa-wu05-a11-perched-zone-carrier@f0291d8c5c153417465a5bd8f464bd4a2fd88c33`
plus corrected A11 carrier copied into this branch.

Canonical reconciliation point:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

Owning predecessor evidence:

- corrected A11 carrier qualification: run `36838931487`;
- A13 decision: `FALSIFIED_ACCEPTED_STATE_SEED`.

## Purpose

Determine the smallest architecture that can evaluate source-faithful macropore exchange
inside the Reference-Richards nonlinear trial path, as B1.11 does, while preserving SWAP5
transaction ownership and preventing trial-local macropore calculations from mutating
committed continuation state.

This is a design/research workunit first. Production implementation is not preregistered.

## Source-order requirement

Exact B1.11 establishes:

`soilwater(2) -> headcalc -> MACROPORE(2) -> MACRORATE(1)`

during nonlinear evaluation.

The A13 accepted-state seed was falsified because a single outer seed does not retain
transient perched transfer through the completed outer fixed-point transaction.

A14 therefore investigates rate evaluation at the nonlinear iterate, not another
outer-predictor tuning.

## Required architecture properties

Any feasible design must satisfy all of the following.

### G1 — current-iterate hydraulics

The macropore rate service receives the current nonlinear matrix iterate:

- pressure head;
- water content or a deterministic constitutive equivalent;
- ponding/top state required by admitted macropore physics;
- current step duration.

It must not infer current-iterate state from committed/candidate state after the solve.

### G2 — immutable accepted macropore context

The service may read:

- accepted seven-field macropore continuation state;
- immutable geometry/configuration;
- current forcing.

It may return only trial-local rate/diagnostic data during Newton evaluation.

It must not mutate accepted macropore continuation state, sorptivity history, geometry
continuation or restart state from inside HeadCalc.

### G3 — source/sink ownership

The matrix equation receives the macropore exchange exactly once through an explicit
provider/overlay contract.

The same internal transfer must later be integrated into the macropore candidate with
opposite sign. No double counting and no hidden source ownership are allowed.

### G4 — nonlinear derivative policy

A14 must identify whether current Reference-Richards convergence can remain correct with:

- lagged/Picard macropore rate in the Newton residual;
- a supplied derivative/Jacobian contribution;
- or another explicitly qualified linearization.

The design must not silently omit a materially required derivative.

### G5 — transaction/restart boundary

Rejected nonlinear/time-step trials may discard all callback scratch without changing
committed state.

Only the accepted trial result may update macropore continuation/history through the
existing transaction publication path.

Restart payload must remain the seven-field admitted macropore state unless a separate
source requirement proves otherwise.

## Falsification criteria

The inner-rate route is rejected if it requires any of the following merely to function:

- direct mutation of committed macropore state from HeadCalc;
- hidden dependency on legacy module globals;
- duplicate ownership of matrix/macropore exchange;
- weakening mass/restart/reject contracts;
- a solver-specific mutable state that cannot be deterministically reconstructed or
  safely discarded;
- an unaccounted Jacobian term that makes convergence dependent on accidental damping.

## Non-scope

- no production admission in A14;
- no covering-layer extension;
- no arbitrary/multiple rapid drain levels;
- no dynamic crack-volume feedback beyond what is needed to understand the callback
  boundary;
- no RossFast implementation;
- no parallel MultiSWAP changes.

## Planned evidence

1. exact current Reference-Richards call/data-flow map;
2. exact source/sink provider ownership map;
3. candidate callback interface with lifetime/ownership classification;
4. smallest compile-level or isolated numerical proof if needed;
5. explicit decision:
   - `FEASIBLE_INNER_RATE_CALLBACK_DESIGN`;
   - `REQUIRES_SOLVER_INTERFACE_EXTENSION`;
   - or `FALSIFIED_INNER_RATE_ROUTE`.

No canonical merge is permitted from A14.
