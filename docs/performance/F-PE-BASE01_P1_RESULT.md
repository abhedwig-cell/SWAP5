# F-PE-BASE01 P1 result — q/state backend internal decomposition

Date: 2026-09-27

Status: `PASS_NO_SINGLE_INNER_HEADCALC_TARGET`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Current-head authority:
- branch head exercised: `c5f1881d3d95695993ab6420e232adb32c9df60b`;
- workflow run: `36306634228`;
- job: `p1-backend-internal`;
- frozen q-only live-head population from LIVE01 authority run `36303861366`.

## Scope

P1 replays the exact q-only SWAP trial head sequences from the frozen 12-group LIVE01 population.

Accepted-direction work is disabled identically for this base-q/state decomposition.

No production source is modified. Instrumentation is applied only to generated research copies.

## Preservation

The instrumented replay preserves the frozen discrete trajectory:

- transaction calls: 52;
- accepted substeps: 52;
- attempts: 72;
- retries: 20;
- temporal rejections: 20;
- solver rejections: 0;
- nonlinear iterations: 236;
- backtracking attempts: 236.

The preservation gate passes.

## Aggregate timing

Across the 12 group medians:

- serialized backend: `814,706 ns`;
- HeadCalc: `333,956 ns`;
- HeadCalc / backend share: `40.9910%`.

Within HeadCalc, nested timing families are:

- constitutive evaluation: `134,701 ns`, `40.3350%` of HeadCalc;
- residual/vector work: `24,764 ns`, `7.4153%`;
- Jacobian assembly: `12,903 ns`, `3.8637%`;
- tridiagonal linear solve: `18,855 ns`, `5.6460%`;
- complete backtracking candidate loop: `96,912 ns`, `29.0194%`.

These families are nested. In particular, backtracking contains constitutive and vector work. Their percentages must not be summed as disjoint costs.

Call counts remain:

- HeadCalc calls: 72;
- constitutive calls: 472;
- vector/residual calls: 308;
- Jacobian builds: 236;
- linear solves: 236;
- backtracking attempts: 236.

## Target-gate interpretation

The preregistered target gate is based on the full q/state backend, not on HeadCalc alone.

Approximate aggregate backend shares are:

- HeadCalc total: `40.99%`;
- constitutive nested work: `16.53%`;
- residual/vector nested work: `3.04%`;
- Jacobian nested work: `1.58%`;
- linear solve nested work: `2.31%`;
- backtracking loop nested work: `11.90%`.

No isolated inner-HeadCalc family reaches the `20%` aggregate-backend gate.

The constitutive family is material but remains below that gate.

## Main finding

The largest unresolved block is outside HeadCalc:

`backend - HeadCalc ~= 59.01%`.

That residual includes transaction/substep orchestration, temporal-indicator/certificate work, accepted candidate/state materialization and other backend control work that P1 does not yet separate.

## Decision

Do not advance constitutive, Jacobian, linear-solve or generic backtracking work directly to P2.

Advance the narrower attribution phase:

`F-PE-BASE01 P1B — non-HeadCalc backend decomposition`.

P1B splits the outer backend block before BASE01 selects its one exact-preserving successor target.
