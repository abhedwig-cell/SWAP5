# PPA-WU05-A18 preregistration — solver-stable perched Reference-Richards authority fixture

Date: 2026-10-01

Status: `PREREGISTERED / AUTHORITY_FIXTURE_RECOVERY`

Baseline:
`work/ppa-wu05-a17-serialized-inner-callback@1a03558664c73efe62cf024cf47ee3cc9ebf6a7f`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

## Purpose

Recover or construct a source-backed perched-groundwater hydraulic case that is
independently stable in Reference Richards before the A17 inner macropore callback is
enabled.

The A17 inner transaction infrastructure is already qualified. A18 owns only the missing
hydraulic authority for active perched end-to-end qualification.

## Primary authority

Use the user-supplied exact SWAP 4.3.1 distribution.

Pinned identities:

- outer uploaded package: `SWAP_4.3.1.zip`;
- nested source archive SHA-256:
  `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`;
- exact `macrorate.f90` SHA-256:
  `537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`.

The distribution contains the official case:

`cases/3.macroporeflow` — Andelst.

A18 may instrument exact source for read-only diagnostics, but may not change physical
equations when establishing source authority.

## Required sequence

### G1 — exact 4.3.1 runtime recovery

Build/run the exact source locally, using only compiler portability preprocessing needed
to reproduce the standalone non-MultiSWAP Linux route.

Record all local source preprocessing and distinguish it from physical source changes.

### G2 — shipped-case census

Run the unmodified official Andelst macropore case and determine whether it contains a
**distinct** perched groundwater body.

A distinct perched body requires source-state evidence separating it from the ordinary
groundwater table, not merely `NPeGwl > 0`.

At minimum compare:

- `NodGwl`;
- `NPeGwl`;
- `BPeGwl`;
- `PeGwl`;
- ordinary `Gwl`.

### G3 — source-backed perched variant if shipped case is negative

If the shipped case does not contain a distinct perched body, construct a minimal variant
that changes only the initial pressure-head profile and, only if required for solver
stability, the shortest explicitly documented set of initial/boundary inputs.

All soil discretization, hydraulic functions, macropore parameters and source code remain
the official case authority unless a deviation is explicitly preregistered and justified.

The exact 4.3.1 runtime itself must:

- identify a distinct perched body;
- complete normally;
- preserve the perched body for at least one accepted interval.

### G4 — independent SWAP5 Reference-Richards baseline

Translate one exact-source perched snapshot into a bounded SWAP5 Reference-Richards
fixture with macropore callback disabled.

Require:

- clean nonlinear convergence;
- hard mass gate;
- source-consistent perched topology at accepted endpoint.

### G5 — replay A17 inner callback

Only after G4 passes, enable the already qualified A17 inner callback on the same fixture.

Require:

- nonzero source-faithful perched `QInIntSat`;
- matching macropore storage transfer;
- internal mass cancellation;
- reject/replay and restart.

## Explicit negative rules

Do not qualify a case by repeatedly tuning arbitrary synthetic heads, conductivities,
forcing or tolerances until it passes.

Do not weaken mass or nonlinear convergence criteria.

Do not use a perched fixture that fails Reference Richards with macropore callback disabled.

Do not classify `NPeGwl > 0` as perched authority when it merely duplicates the ordinary
groundwater level.

## Decision states

- `QUALIFIED_SOLVER_STABLE_PERCHED_AUTHORITY_FIXTURE`;
- `QUALIFIED_A17_ACTIVE_PERCHED_E2E`;
- `SHIPPED_CASE_HAS_NO_DISTINCT_PERCHED_BODY`;
- `BLOCKED_NO_SOURCE_STABLE_PERCHED_FIXTURE`.
