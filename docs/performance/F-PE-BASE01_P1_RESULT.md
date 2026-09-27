# F-PE-BASE01 P1 result — q/state backend internal decomposition

Date: 2026-09-27

Status: `PASS_NO_SINGLE_INNER_HEADCALC_TARGET`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Authority:
- branch head exercised: `0672462b4d6858bab7d1a62097ee08d7412cf2a6`;
- workflow run: `36305570617`;
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

- serialized backend: `461628 ns`;
- HeadCalc: `202372 ns`;
- HeadCalc / backend share: `43.8388%`.

Within HeadCalc, nested timing families are:

- constitutive evaluation: `82818 ns`, `40.9236%` of HeadCalc;
- residual/vector work: `14813 ns`, `7.3197%`;
- Jacobian assembly: `6992 ns`, `3.4550%`;
- tridiagonal linear solve: `12379 ns`, `6.1170%`;
- complete backtracking candidate loop: `61677 ns`, `30.4770%`.

These families are nested. In particular, backtracking contains constitutive and vector work. Their percentages must not be summed as disjoint costs.

Call counts across the frozen population:

- HeadCalc calls: 72;
- constitutive calls: 472;
- vector/residual calls: 308;
- Jacobian builds: 236;
- linear solves: 236;
- backtracking attempts: 236.

## Target-gate interpretation

The preregistered target gate is based on the full q/state backend, not on HeadCalc alone.

Approximate aggregate backend shares are therefore:

- HeadCalc total: `43.84%`;
- constitutive nested work: `17.94%`;
- residual/vector nested work: `3.21%`;
- Jacobian nested work: `1.51%`;
- linear solve nested work: `2.68%`;
- backtracking loop nested work: `13.36%`.

No isolated inner-HeadCalc family reaches the `20%` aggregate-backend gate.

The constitutive family is material but remains below that gate. HYDTABLE01 independently showed that accelerating an isolated conductivity microkernel does not survive to solver wall-clock benefit, which reinforces the decision not to select constitutive arithmetic by microbenchmark alone.

## Main finding

The largest unresolved block is outside HeadCalc:

`backend - HeadCalc ~= 56.16%`.

That residual includes transaction/substep orchestration, temporal-indicator/certificate work, accepted candidate/state materialization and other backend control work that P1 has not yet separated.

Selecting an inner HeadCalc optimization now would therefore be premature.

## Decision

Do not advance constitutive, Jacobian, linear-solve or generic backtracking work directly to P2.

Advance one narrower attribution phase:

`F-PE-BASE01 P1B — non-HeadCalc backend decomposition`.

P1B must split the approximately 56% residual backend block before BASE01 selects its one exact-preserving successor target.
