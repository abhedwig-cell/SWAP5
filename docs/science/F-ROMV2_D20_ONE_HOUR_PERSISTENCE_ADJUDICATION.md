# F-ROMV2 D20 one-hour hydraulic persistence adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D20  
**Decision:** **FMC_ONE_HOUR_PERSISTENCE_RETAINS_RESEARCH_CANDIDACY**

## Question

D20 asks whether the relative advantage of the admitted FMC surface-plus-fixed-water-table route persists beyond the short D17 and D19 windows when hydraulic forcing changes repeatedly.

The experiment is deliberately still narrow:

- homogeneous B01;
- fixed zero-head water table at the 160-cm bottom;
- no ET or root uptake;
- no drainage or subsurface irrigation;
- no ponding/runoff;
- no dry-bin activation;
- no falling-slug/contact/merge event in the D20 workload.

The novelty of D20 is duration and repeated forcing-order changes, not a new process law.

## Frozen workload

Each history lasts one hour with a 10-s process/observation step.

Top infiltration uses only the already exposed D17 factors:

- 0.10 Ksat;
- 0.25 Ksat;
- 0.50 Ksat;
- 0.75 Ksat.

Each factor is applied for five minutes. Four blocks form a forcing cycle and the cycle is repeated three times.

Four histories have exactly the same factor multiset and cumulative top input but different ordering:

- P_UP;
- P_DOWN;
- P_ALT_A;
- P_ALT_B.

This makes forcing-order memory visible without introducing new factor values.

## Staged execution

### Stage 1 — FMC-only preflight

Run **35460196880**, job **105942554405**.

Artifact **10589358371**, digest:

`sha256:0149f5fd61d9208c89c45b838662ae31a25d1c66717e3d5ec0ac557526885204`.

Decision:

`D20_FMC_ONE_HOUR_PREFLIGHT_PASS`.

All 4 × 360 FMC steps complete.

Across histories:

- cumulative prescribed top input is about **0.520417 cm** and is equal within the frozen numerical identity criterion;
- cumulative bottom exchange is about **-0.371648 cm**;
- minimum surface-groundwater separation remains about **8.70 cm**;
- maximum absolute FMC step-mass residual is about **1.17e-14 cm**;
- no contact/merge occurs;
- no runoff or ponding occurs;
- no dry-bin activation occurs;
- no falling-slug state occurs.

No R16/R2 trajectory evidence was consumed in Stage 1.

### Stage 2 — matched R16/R2 comparator

A first Stage-2 workflow run, 35460411554, stopped at Fortran compile time before any R16/R2 trajectory was generated. One history-summary output still called a helper with its old argument list.

The repair removed only that non-scientific summary field. It changed no physics, forcing, initial state, numerical authority, metric or decision gate.

Primary scientific run:

- workflow run: **35460468883**;
- job: **105943287019**;
- executed head: `aa565fd60a3db0dd93253559594479e4f4fc7687`;
- artifact: **10589368773**;
- artifact digest:
  `sha256:01ced1ca2bafd794fc966a3a5b8d883bbb48adcb4090b696fd3abad3fe294250`;
- raw result SHA-256:
  `dbbd89fa075504ef7dc8e8b820ef39c8a811225165bfbd6950aa00b4253b289b`.

R16 and R2 are each bitwise identical between O0 and O2.

## Full-hour frontier

| metric | FMC | R2 | FMC/R2 |
|---|---:|---:|---:|
| total-storage RMSE | 0.26194 cm | 0.48432 cm | 0.541 |
| cumulative-bottom-exchange RMSE | 0.26194 cm | 0.48432 cm | 0.541 |
| mapped 10-cm theta RMSE | 0.007020 | 0.048186 | 0.146 |
| terminal bottom-flux RMSE | 10.763 cm d-1 | 19.365 cm d-1 | 0.556 |
| bottom-flux sign errors | 0/1440 | 0/1440 | — |

Every preregistered full-hour frontier gate passes.

## Last-quarter persistence

The last 15 minutes, steps 271-360, were preregistered separately so an early transient advantage could not carry the whole decision.

| metric | FMC | R2 |
|---|---:|---:|
| total-storage RMSE | 0.39715 cm | 0.72027 cm |
| cumulative-bottom-exchange RMSE | 0.39715 cm | 0.72027 cm |
| mapped 10-cm theta RMSE | 0.010216 | 0.049823 |
| terminal bottom-flux RMSE | 9.955 cm d-1 | 16.768 cm d-1 |

Every last-quarter gate also passes.

The FMC advantage therefore persists rather than disappearing after the first forcing cycle.

## Absolute drift remains material

D20 is a relative-frontier success, not an application-accuracy result.

Over the complete hour FMC mean total-storage error is about **-0.226 cm**, with an equal-and-opposite cumulative-bottom-exchange bias of about **+0.226 cm**.

In the last quarter those mean biases increase to approximately **-0.396 cm** and **+0.396 cm**.

R2 is substantially worse, but the growing FMC bias is scientifically important.

This prevents interpreting D20 as evidence for seasonal or long-term application acceptance.

## Vertical-partition trade-off

A particularly important purpose-dependent result is hidden by the total-storage and profile aggregates.

Over the full hour:

- FMC upper 0-80 cm storage RMSE: **0.1411 cm**;
- R2 upper 0-80 cm storage RMSE: **0.04905 cm**.

FMC is therefore almost three times worse than R2 for this integrated upper-zone storage metric.

At the same time:

- FMC lower 80-160 cm storage RMSE: **0.1214 cm**;
- R2 lower 80-160 cm storage RMSE: **0.4353 cm**.

The same pattern strengthens in the last quarter.

FMC's advantage is thus concentrated in lower-zone storage, resolved profile structure, total balance and groundwater exchange. It is **not** a universal state-fidelity improvement.

This is exactly why F-ROMV2 uses a purpose-dependent acceptance envelope.

## Purpose-dependent interpretation

### Regional water balance / recharge

**Promising research direction, not qualified.**

The relative advantage over R2 persists for one hour, including the final quarter. But absolute systematic bias grows and one hour is far from seasonal or multi-year balance.

### Groundwater-coupled many-column use

**Promising fixed-water-table research direction, not qualified.**

Lower-zone storage and bottom-flux magnitude are substantially better than R2. A moving/live groundwater table has not been tested.

### Operational root-zone soil moisture / drought

**Not qualified.**

The upper-80-cm storage result is worse than R2. ET, root uptake, drought persistence and recovery are absent.

### Fast-event threshold use

**Not qualified.**

D20 deliberately excludes rainfall supply limitation, surface ponding and runoff thresholds.

### Scientific process / extreme inference

**Not qualified.**

## Decision

The frozen D20 decision is:

`FMC_ONE_HOUR_PERSISTENCE_RETAINS_RESEARCH_CANDIDACY`.

This extends the positive FMC chain from isolated short hydraulic branches to a one-hour repeated-forcing persistence envelope.

It does **not** authorize production ROM or application acceptance.

The next hydraulic discriminator should address the largest still-unqualified surface process boundary: **rainfall supply, ponding and runoff threshold behavior** against R16 and R2.

A same-runtime FMC performance screen is now scientifically worth doing as a separate screening workunit because FMC has survived a materially longer hydraulic horizon. Such timing still cannot be promoted to a formal production speedup claim without the admitted performance host.

Production ROM remains unauthorized.
