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


## Recovered G1/G2 evidence — 2026-10-01

The exact user-supplied distribution was materialized and inspected locally.

### Package contents

The official distribution contains:

- `cases/3.macroporeflow/swap.swp`;
- Andelst meteorology and detailed rainfall inputs;
- `swap.bbc` and `swap.dra`;
- crop files;
- packaged Linux and Windows executables;
- exact `SWAP.ZIP`;
- exact `TTUTIL.ZIP`;
- the supplied Linux compiler script.

The case identifies itself as:

`Case: Macropore flow (Andelst)`

and runs from 1998-01-01 to 1999-04-26 with `SWMACRO=1` and
`CRITUNDSATVOL=0.1 cm`.

### Portable local rebuild

The packaged Linux executable is not runnable in the current container because
`libimf.so` is unavailable.

TTUTIL was rebuilt from the packaged source with gfortran.

SWAP 4.3.1 was then rebuilt from the packaged source in the exact source order listed by
`compile_link_431_linux.sh`.

Portability-only changes:

- Intel `!DEC$` conditional compilation was resolved to the ordinary Linux,
  non-MultiSWAP, non-ANIMO, non-SSS branches;
- gfortran legacy argument compatibility was enabled;
- Intel `-save` was not emulated globally because it conflicts with PURE procedures in
  gfortran.

No physical equation or case input was changed for the authority run.

### False-positive guard

A first diagnostic trigger on `NPeGwl>0` stopped at
`t1900=35795.0`, but the apparent perched node coincided with the ordinary saturated
zone. That event is rejected as perched authority.

A stricter diagnostic then required:

`BPeGwl < NodGwl - 1`.

### First distinct perched body

The unmodified official Andelst case then produced:

- `t1900 = 35797.50454372`;
- `Gwl = -59.98714 cm`;
- `NodGwl = 47`;
- `PeGwl = -18.07459 cm`;
- `NPeGwl = 19`;
- `PeGwl_bot = -28.09488 cm`;
- `BPeGwl = 29`;
- `NumNod = 112`.

The pressure-head vector shows a distinct positive-head lens at nodes 19..28, followed by
negative heads through the separator, before positive heads reappear in the ordinary
groundwater zone near node 48.

This passes G2: the shipped official SWAP 4.3.1 macropore case itself contains a genuine
source-defined perched groundwater body.

The next A18 action is therefore exact snapshot/forcing extraction around this event,
not construction of a synthetic replacement profile.
