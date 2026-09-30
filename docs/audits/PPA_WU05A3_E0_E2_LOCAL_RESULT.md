# PPA-WU05-A3 E0-E2 local research result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / NOT_QUALIFIED / SYNTHETIC_PRESCRIBED_MATRIX`

## Scope

This result is the first executable A3 research slice.

It deliberately excludes:

- active Richards coupling;
- rapid drainage physics;
- the `icgwl` defect path;
- production admission;
- parameter calibration.

The local harness isolates source-bound B1.11 process fragments for:

1. macropore disabled control;
2. top inflow into macropore storage;
3. SWABS=1 sorptivity absorption into prescribed matrix state;
4. accepted sorptivity-history update;
5. one-compartment/domain storage balance.

## Source anchors

Exact B1.11 authority:

- `macrorate.f90:1717-1747` — saturation deficit, new/continuing sorptivity event and absorption amount;
- `macropore.f90:1423-1451` — accepted update/reset of `TimAbsCumDmCp`, `SorpDmCp`, and `ThtSrpRefDmCp`;
- A1 mass ownership — absorption is internal matrix/macropore exchange, not an external whole-column sink.

## Local setup

Synthetic prescribed matrix state:

- `theta = 0.16`;
- `theta_s = 0.45`;
- `theta_r = 0.05`;
- `dt = 0.1 d`.

Representative research geometry:

- domain fraction `pp = 0.08`;
- compartment thickness `dz = 10 cm`;
- characteristic pore/aggregate diameter `dipo = 4 cm`;
- wall correction `awl = 0.95`;
- represented macropore storage capacity `1.2 cm`.

These values are research controls, not calibration or recommended parameters.

## E0 — macropores disabled

Result:

- top macropore flux = 0;
- absorption = 0;
- state/history unchanged;
- storage unchanged;
- mass residual = 0.

Verdict: `PASS_NEGATIVE_CONTROL`.

## E1 — direct-bypass dominated

Top input: `5 cm d-1`.

Weak sorptivity: `SorpMax = 0.005`.

Observed:

- `q_top = 5.0`;
- `q_absorb ~= 0.01023`;
- storage increases from 0 to `~0.49898 cm` over 0.1 d;
- mass residual = 0 to floating-point precision.

Interpretation: under deliberately weak matrix absorption, nearly all applied top macropore input remains in macropore storage over this short step.

Verdict: `PASS_BYPASS_STORAGE_DOMINATED`.

## E2 — absorption dominated

Top input: `0.5 cm d-1`.

Initial macropore storage: `0.7 cm`.

Strong sorptivity: `SorpMax = 0.50`.

Observed:

- `q_absorb ~= 1.02318 cm d-1`;
- absorption exceeds contemporaneous top input;
- storage decreases from `0.7` to `~0.64768 cm`;
- the extra absorbed water therefore comes from existing macropore storage;
- mass residual is `~4e-17 cm`.

This behaviour is physically and bookkeeping-wise important: matrix absorption is not constrained to the instantaneous top macropore inflow. Stored macropore water is available to the internal exchange process.

Verdict: `PASS_ABSORPTION_FROM_STORED_WATER`.

## Sorptivity event-memory screen

A six-step continuation using identical prescribed matrix state and forcing produced decreasing absorption rates:

- step 1: `~1.0232 cm d-1`;
- step 2: `~0.4312`;
- step 3: `~0.3332`;
- step 4: `~0.2824`;
- step 5: `~0.2499`;
- step 6: `~0.2268`.

`TimAbsCumDmCp` increased from 0.1 to 0.6 d while `SorpDmCp` retained the event value and `ThtSrpRefDmCp` evolved.

This is a first executable confirmation of H6 directionality: the source formulation contains real wetting-event memory, not merely output bookkeeping.

It is not yet a full H6 qualification because the matrix state was held prescribed rather than coupled back to absorbed water.

## Mass result

All E0-E2 local cases close to machine precision under the reduced balance:

`Delta storage = top input - internal absorption - rapid drainage`.

Rapid drainage is zero by construction in this slice.

## Research conclusions

1. E0-E2 can be studied without the full legacy call graph.
2. The sorptivity-history triplet is demonstrably process-active.
3. Existing macropore storage participates in later matrix absorption.
4. This supports A1/A2 classification of sorptivity history as physical continuation state.
5. The next local slice should add a two-reservoir matrix/macropore balance so absorbed water updates matrix water content rather than using a prescribed matrix indefinitely.
6. Rapid drainage remains held for E5.
7. The `icgwl` correction remains held for E6/E7.

## Next local experiment

Implement E2b/E3 with conservative two-reservoir coupling:

- macropore storage loses absorption;
- matrix storage gains exactly the same amount;
- matrix `theta` responds to that gain;
- compare event-memory trajectories for distinct admissible history states that begin from the same current matrix/macropore storage.

This is the first direct falsification attempt for H6 and a stronger mass-conservation check.
