# F-AHL47 — direct-retention provider screen closeout

Date: 2026-09-25

Status: `CLOSED_PASS_READY_FOR_PRODUCTION_SHAPED_QUALIFICATION`

Production parent: admitted F-PE-PLANVALID01 postimage `df664f56cf09ee8479701f15fe10ee02d31a9536`.

PR: #617.

## Architecture tested

F-AHL47 does not approximate the full hydraulic tuple.

It keeps authoritative analytical evaluation for:

- full theta/C/K evaluation;
- conductivity demand;
- point conductivity;
- all unqualified demand masks.

Only the hot demand-specific retention path is replaced:

- WATER_CONTENT demand;
- CAPACITY demand.

The representation is:

- 256 intervals per decade;
- six physical |h| decades from 1 to 1e6 cm;
- direct decade branch;
- direct index arithmetic;
- cubic Hermite theta interpolation;
- C = dtheta/dh from the exact derivative of the same interpolant;
- analytical fallback outside the represented domain.

No log10, binary search, logistic reconstruction or K interpolation is used.

## Microarchitecture authority

F-AHL46 established at N=60 that direct Hermite theta+C costs about 0.82 us/call versus about 2.22 us for analytical theta-only and 4.44 us for analytical theta+C on the measured runner.

At 256 intervals/decade:

- B01 max theta error ~1.97e-9;
- B01 max relative C error above C=1e-13 ~5.94e-6;
- O05 max theta error ~1.04e-8;
- O05 max relative C error above C=1e-13 ~1.86e-5.

This is derivative-consistent by construction.

## Current-postimage solver screen

Single B01-mid current Reference Richards screen:

- prescribed-head mode 5;
- same status;
- 4 versus 4 nonlinear iterations;
- 4 versus 4 backtracking attempts;
- max head difference ~2.27e-11 cm;
- max theta difference ~4.26e-13.

Seven paired timings gave median fast/reference ratio ~0.689, approximately 31% lower solver runtime.

## 12-case fidelity matrix

Workflow run `36152598034`: PASS.

Materials:

- B01;
- B12;
- O05;
- O14.

Regimes:

- wet: h0=-10 cm, hbot=-7.5 cm;
- mid: h0=-75 cm, hbot=-50 cm;
- dry: h0=-500 cm, hbot=-400 cm.

Result: `12/12 PASS`.

Every case retained:

- identical nonlinear iteration count;
- identical backtracking count;
- mass residual <= 1e-12.

Largest observed head difference was O05-dry at approximately 1.53e-7 cm.

Theta differences remained of order 1e-12 or smaller.

## 12-case paired timing

Workflow run `36152945895`: PASS.

Each case used five alternating paired timing observations.

All 12 cases were speed-positive.

Median candidate/reference ratios:

- B01 wet ~0.738
- B01 mid ~0.740
- B01 dry ~0.702
- B12 wet ~0.738
- B12 mid ~0.705
- B12 dry ~0.745
- O05 wet ~0.737
- O05 mid ~0.699
- O05 dry ~0.740
- O14 wet ~0.782
- O14 mid ~0.734
- O14 dry ~0.735

Across the 12 case medians:

- median ratio: `0.737385`;
- minimum ratio: `0.698715`;
- maximum ratio: `0.782335`;
- speed-positive: 12/12;
- speed-negative: 0/12.

Thus the bounded current-postimage screen shows approximately 22–30% solver reduction, with a median around 26%.

No portable absolute speed claim is made.

## Why this differs from policy-4 F-AHL

F-AHL44 showed the historical policy-4 architecture is speed-negative on the current demand-aware solver because it performs expensive log/search/Hermite/logistic work and also approximates pieces that current HeadCalc no longer requests on every candidate.

F-AHL47 instead matches the solver demand structure:

- analytical full tuple remains exact;
- candidate theta demand is accelerated directly;
- accepted capacity demand uses the same derivative-consistent interpolation;
- K is not looked up.

The performance result therefore comes from architecture alignment rather than looser tolerances.

## Scientific status

The candidate is derivative-consistent for retention:

`C(h) = d theta(h) / dh`

from the same cubic interpolant.

The current bounded evidence shows very small endpoint differences and exact nonlinear-path preservation.

This does not yet qualify:

- all 36 default-MvG materials;
- layered/multi-authority profiles;
- qbot execution;
- accepted-trajectory directional execution;
- SWKIMPL=1 / dKdh;
- KSATEXM combinations;
- production cache/ownership;
- parallel/thread-safe sharing.

## Production blocker before admission

The research provider owns two tables of size:

`2 * 6 * 257 * 8 bytes ~= 24.7 kB`

per provider, excluding object overhead.

That is trivial for a single provider but cannot be blindly multiplied by large MultiSWAP column counts.

Before production admission, qualification must decide between:

1. reducing resolution if 64 or 128 intervals/decade retain solver-path/fidelity gates;
2. shared immutable exact-key tables with solve-local direct access;
3. another ownership model that avoids both per-candidate registry lookup and per-column table duplication.

The old policy-4 shared-registry sample path must not be reintroduced without measurement because F-AHL44 showed that registry-based solve-loop lookup is performance-negative.

## Decision

`F-AHL47 = CLOSED_PASS_READY_FOR_PRODUCTION_SHAPED_QUALIFICATION`

The next workunit is not further interpolation tuning. It is ownership/resolution qualification for the direct-retention architecture.

Recommended next unit:

`F-AHL48 — direct-retention resolution and immutable ownership qualification`
