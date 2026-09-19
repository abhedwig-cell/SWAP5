# F-ROMV2 D21 rainfall–ponding–runoff adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D21  
**Decision:** **D21_MATCHED_RAIN_PONDING_RUNOFF_BOUNDARY_NO_GO_BEFORE_TRAJECTORY_EXPOSURE**

## Question

D20 retained FMC research candidacy over a one-hour fixed-water-table persistence envelope, but explicitly left fast rainfall-supply, ponding and runoff thresholds unqualified.

D21 therefore asked a narrower question before any matched R16/R2 rainfall trajectory was allowed:

> Can SWAP Reference dynamic-top and the literature-bound FMC surface-accounting route be put on the same three-regime rainfall workload without choosing rainfall factors after seeing both model responses?

The three intended regimes were:

1. supply-limited flux without ponding;
2. ponding without runoff;
3. active runoff.

D21 used a staged design so a mismatch in boundary semantics could stop the work before it was confounded with Richards trajectory response.

## Frozen surface context

The initial subsurface state is the D16 `D14_I_DEEP` B01 surface profile.

The common external scale was frozen before trajectory evidence:

- process step: **10 s**;
- rainfall ladder: **0.25, 0.5, 1, 2, 4, 8, 16 × Ksat**;
- ponding maximum:
  **Ksat × 10 s = 0.0036140064814814818 cm**;
- runoff resistance: **0.001 day**;
- runoff exponent: **1**;
- ET, root uptake, drainage, irrigation, snowmelt and runon: zero;
- no groundwater-front composition.

No later result changes those values.

## Stage 1: independent boundary authority

Stage 1 used the **current-canonical Fortran B1.10 dynamic-top provider itself** as the SWAP regime oracle. No R16/R2 Richards trajectory was run.

Primary execution:

- PR #464, closed unmerged;
- workflow run **35462604315**;
- job **105949034359**;
- head `2ed98f1d9969a3a7ae7c31fd5a8c7fd8574b37ef`;
- artifact **10590430843**;
- digest `sha256:cfb0f9672b461ee94777de924a99fc49b679636f99f2ebedceb68d2dc8d1d805`.

The O0/O2 provider output is bitwise identical.

The frozen ladder gives:

| rainfall | SWAP dynamic-top route | ponding | runoff |
|---:|---|---:|---:|
| 0.25 Ksat | surface-flux | 0 | 0 |
| 0.5 Ksat | surface-flux | 0 | 0 |
| 1 Ksat | surface-flux | 0 | 0 |
| 2 Ksat | ponded-head | 0.0030155 cm | 0 |
| 4 Ksat | ponded-head-linear-runoff | 0.0095540 cm | 0.0006875 cm |
| 8 Ksat | ponded-head-linear-runoff | 0.0225068 cm | 0.0021867 cm |
| 16 Ksat | ponded-head-linear-runoff | 0.0484125 cm | 0.0051850 cm |

The preregistered lowest representatives are therefore:

- **0.25 Ksat** — flux/no ponding;
- **2 Ksat** — ponded/no runoff;
- **4 Ksat** — active runoff.

Independently, the FMC nonzero-(h_p) Eq.18 primitive remains finite and conservative, and the frozen linear surface-reservoir primitive closes exactly at reported precision.

Stage-1 decision:

`D21_RAIN_PONDING_RUNOFF_BOUNDARY_PREFLIGHT_PASS`.

## Stage 2: full FMC surface-accounting micro-preflight

Stage 2 then used exactly those three selected factors in the full D16/D15 FMC connected-front and surface-reservoir path.

Still no R16/R2 rainfall trajectory was generated.

Execution:

- PR #465, closed unmerged;
- workflow run **35462751043**;
- job **105949431873**;
- head `9b83253b3dc5f328e5808b63c59cfa455c60d0fb`;
- artifact **10590176859**;
- digest `sha256:2660f42dc1f63f8a23c58a3241c2bca69d5cf00462a40db294866b5803ccc656`.

### 0.25 Ksat

FMC infiltrates the full **0.00090350 cm** supply.

- final surface store: 0;
- runoff: 0;
- ledger residual: about **7.1e-15 cm**.

The selected no-ponding/no-runoff label matches.

### 2 Ksat

FMC infiltrates about **0.00339959 cm**, leaving **0.00382842 cm** above the column.

The frozen surface-reservoir law produces:

- final surface store: **0.00380618 cm**;
- runoff: **2.22421e-05 cm**;
- ledger residual: about **7.1e-15 cm**.

This is already an **active-runoff** state.

It does not match the SWAP Stage-1 label, which is ponded with zero runoff.

### 4 Ksat

FMC again infiltrates about **0.00339959 cm** and produces:

- surface store: **0.0102844 cm**;
- runoff: **0.000772036 cm**;
- ledger residual: 0 at reported precision.

The selected active-runoff label matches.

## Scientific result

D21 therefore fails at the intermediate threshold:

> under the frozen B01 initial state and common external ponding/runoff scale, SWAP Reference and the FMC surface formulation do not place the ponding-to-runoff transition at the same rainfall supply.

The important point is that this is **not** a mass-conservation failure.

FMC's one-step ledgers close to approximately (10^{-14}) cm or better.

It is a structural threshold difference between the two surface formulations.

The frozen Stage-2 decision is:

`D21_FMC_COUPLED_BOUNDARY_MICRO_PREFLIGHT_NO_GO`.

Therefore Stage-3 R16/R2 rainfall trajectories are **not authorized** under D21.

## What D21 does not mean

D21 does not overturn the positive FMC evidence from D13, D16, D17, D19 or D20.

In particular it does not reclassify:

- the bounded groundwater-front result;
- surface redistribution under prescribed infiltration;
- separated or contact surface-groundwater composition;
- one-hour fixed-water-table persistence.

It does establish that FMC cannot currently be treated as threshold-equivalent to SWAP's dynamic-top formulation for fast rainfall/ponding/runoff applications.

### Purpose-dependent interpretation

**Fast event / threshold applications:** not qualified.

**Long-term regional water balance:** D20 authority remains unchanged; D21 does not test long-term cumulative balance.

**Groundwater-coupled many-column use:** unchanged from D20; D21 contains no groundwater branch or live coupling.

**Operational drought / ET:** not tested.

## Why the rainfall factor is not retuned

After Stage 2, one could trivially search the frozen ladder or interpolate to find a rainfall level at which both routes happen to report ponding without runoff.

Doing that would erase the scientific result.

The mismatch itself is the evidence.

No factor, ponding maximum, runoff resistance, moisture-bin count, 10-s process step, Eq.18 term or surface-reservoir law is changed after exposure.

## Next research step

A useful successor is **not** another matched-label search.

If fast surface thresholds remain scientifically important, the next distinct workunit should preregister a native threshold-response sweep on the already frozen rainfall ladder.

Such a sweep may compare:

- ponding onset;
- runoff onset;
- ponding depth;
- runoff amount;
- infiltration amount;

without requiring the two formulations to share a regime label at a selected rainfall factor.

That would quantify the threshold displacement rather than tune it away.

Production ROM remains unauthorized.
