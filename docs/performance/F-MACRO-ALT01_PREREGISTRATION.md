# F-MACRO-ALT01 — reduced macropore memory falsification preregistration

Date: 2026-09-30

Status: `PREREGISTERED_RESEARCH_ONLY`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Test whether a reduced functional macropore model for SWAP5 can eliminate explicit macropore-history state, or whether at least one compact history variable is required to preserve event-scale preferential-flow behaviour.

This workunit is research-only. It changes no admitted production physics, no canonical interfaces and no reference source.

## Repository authority

Current macropore review authority:

- `docs/audits/PPA_WU05A_MACROPORE_AUTHORITY.md`
- `integration/audits/PPA_WU05A_MACROPORE_AUTHORITY_CONTRACT.json`

That authority establishes:

- current typed production still has no admitted active-macropore route;
- exact B1.11 source materialization remains mandatory before source-level migration;
- seven historical fields are corroborated committed/history candidates, not yet a definitive B1.11 field census:
  - `ICpBtDm`
  - `SorpDmCp`
  - `ThtSrpRefDmCp`
  - `TimAbsCumDmCp`
  - `VlMpDmCp`
  - `WaUnMpDmCp`
  - `VlMpDyCp`
- worker/rate scratch is not physical continuation state;
- partial rollback is forbidden;
- macropore storage must participate in hard accepted-state mass conservation.

Historical supporting evidence:

- F-PE16 active-sized committed macropore-state recovery;
- F-PE15 active-sized worker/rate-scratch recovery.

## Research question

Can the macropore continuation state relevant to event dynamics be reduced to:

### R1b — memoryless reduced state

```text
S_p(z)
```

with algebraic matrix exchange

```text
E = f(S_p, theta_m)
```

or is at least one explicit compact history state required?

### R1a — one-history-state reduced model

```text
S_p(z), tau_c(z)
```

where `tau_c` represents effective fast-domain/matrix contact history and exchange may depend on

```text
E = f(S_p, theta_m, tau_c)
```

The exact production meaning of `tau_c` is not preregistered; only its information role is.

## Hypotheses

### H1 — memoryless sufficiency

At equal:

- current matrix state;
- current fast-domain storage `S_p`;
- immutable configuration;
- future forcing;

the relevant future macropore response is invariant to prior macropore contact history.

If true, R1b remains viable.

### H2 — irreducible history

At equal current matrix state, equal `S_p`, equal configuration and equal future forcing, the reference macropore response can still differ because prior fast-domain/matrix contact history carries independent information.

If true, R1b is falsified and at least one compact history state is required.

## Clean falsification design

The test must isolate history from residual storage and matrix moisture.

Two candidate initial states for the second event shall therefore be constructed with identical:

```text
theta_m(z)
S_p(z)
forcing(t)
configuration
```

while differing only in a history descriptor.

A comparison based merely on short versus long inter-event gaps is insufficient because that also changes residual fast-domain storage and potentially matrix moisture.

## Standalone toy-harness sanity check

A local standalone toy model was used only to verify that the falsification design itself is discriminating.

The clean test fixed identical:

- matrix moisture profile;
- fast-domain storage profile;
- second-event rainfall;
- connectivity and transfer parameters.

R1b, which has no history state, produced identical response for different nominal prior contact ages by construction.

R1a, with one contact-age state, produced different matrix exchange, deposition and retained fast-domain storage under the same current physical state and same forcing.

This is not evidence that SWAP requires a history state. It only establishes that the proposed falsification test can distinguish a memoryless from a history-carrying model without confounding residual storage.

## Reference falsification target

The decisive test is the exact macropore reference, not the toy harness.

Required next authority step:

1. materialize byte-exact B0 `SWAP/macropore.f90` and `SWAP/macrorate.f90`;
2. verify pinned B0 member hashes;
3. apply and verify SWAP-001;
4. obtain exact B1.11 postimages;
5. complete source-bound state and exchange census;
6. identify whether a controlled second-event experiment can hold current matrix/macropore storage fixed while varying source-proven history state;
7. compare subsequent:
   - matrix exchange;
   - fast-domain storage;
   - drainage;
   - bottom flux;
   - wetting arrival signatures;
   - accepted whole-column mass balance.

## Decision rule

### R1b survives

Only if no source-proven history degree of freedom produces a materially different future response after current matrix state and fast-domain storage have been equalized.

### R1b falsified

If the exact reference produces a reproducible response difference under equal current matrix state, equal current fast-domain storage and equal future forcing, attributable solely to prior macropore history.

Then R1a or another minimal-history formulation becomes the reduced-state lower bound.

## Architecture constraints

Affected SWAP5 invariants:

- 3 explicit data separation;
- 4 compact persistent state;
- 5 scratch per worker;
- 7 transactional time steps;
- 13 hard mass conservation;
- 16 MultiSWAP as primary use case;
- 23 physical options separate from numerical policy;
- 25 reference mode remains available;
- 27 optional functionality scales with use.

No production mutation is authorized by this preregistration.

## Current conclusion

The most defensible current reduced-model hypothesis is not a state-free fast-flow route. It is:

```text
matrix state
+ optional fast-domain storage S_p(z)
+ zero or one compact exchange-history state to be falsified
+ immutable activation/connectivity/transfer parameters
+ worker-local disposable scratch
```

The purpose of F-MACRO-ALT01 is to determine whether the history term can be removed.
