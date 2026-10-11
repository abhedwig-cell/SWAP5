# F-ROMV2 D25 compiled computational-value screen adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D25  
**Decision:** **FMC_SHARED_HOST_COST_ADVANTAGE_RESOLVED_RELATIVE_TO_R16**

## 1. Why D25 exists

D24 established a bounded hydrological result that changed the ROM research question.

For the frozen B01 native-rainfall + fixed-water-table workload, FMC was closer to R16 than R2 on all eight preregistered decision views:

- infiltration;
- surface storage;
- runoff;
- total storage;
- bottom exchange;
- mapped profile water content;
- terminal bottom-flux magnitude;
- bottom-flux sign.

The remaining computational-value question was no longer whether FMC could be made cheaper by changing its science.

It was:

> If the already frozen D24 FMC equations are implemented in compiled code, do they plausibly occupy a useful cost-fidelity frontier relative to R2 and R16?

D25 answers that question only as a **shared-host screening experiment**.

It does not establish a portable SWAP5 performance baseline.

## 2. Performance-governance boundary

The repository's formal performance authority is unchanged.

MP-7 did not admit its host for a 1% CPU baseline.

The current MP-8 readiness record remains:

`INFRASTRUCTURE_PENDING`.

Therefore:

- D25 may report measured CPU ratios from its own frozen run;
- D25 may classify whether the cost signal is resolved inside that run;
- D25 may not call those ratios a qualified production speedup;
- D25 may not generalize them to other hosts, workloads, compilers or MultiSWAP scaling.

This boundary is independent of how large the observed ratios are.

## 3. Pre-execution reconciliation

The D25 proposition was first written on canonical
`5bb400c222aeade663facfef1e7d0c97df971104`.

Before execution, canonical advanced to
`e6c28770786a4cc7cb2ab6cf4b8e3f936c44b3f1`.

The complete intervening delta was PUB-GC-GMD governance/publication material.

No ROM, performance, runtime, production physics or Reference source changed.

D25 was therefore rebased before execution.

The reconciliation changed only provenance:

- scientific fields changed: false;
- timing protocol changed: false;
- execution had started before reconciliation: false.

## 4. Immutable primary execution

Primary run:

- workflow **35472426493**;
- job **105975698305**;
- executed head `ac5adb9b7946ace395fc04acbdc691ba394f56a6`;
- artifact **10593580295**;
- artifact digest
  `sha256:66d49bfc57b2b2b97288ed30eb48f149116fadb5f4df59db7a821ba6c27fdb7f`;
- workflow conclusion: **success**.

The cost-screen payload SHA-256 is

`1bcad51c6ddc24d2cf6177979e902391501d02a07b0739fab4119a629a78286f`.

Later commits on the execution branch are not part of this primary execution authority.

## 5. Compiled FMC implementation equivalence

Timing was not allowed until compiled FMC reproduced the frozen D24 equations.

The D25 compiled Fortran route was compared against the source-bound D24 Python oracle at both O0 and O2.

Result:

`D25_COMPILED_FMC_IMPLEMENTATION_EQUIVALENCE_PASS`.

Observed maximum differences:

- water-depth / storage quantity: about **7.11e-15 cm**;
- terminal bottom flux: about **5.33e-15 cm d-1**;
- mapped theta: **0**;
- runoff-presence mismatches: **0**.

Compiled FMC O0 and O2 validation outputs are themselves identical.

Their common SHA-256 is:

`3842e16a148138162caf81d743282dab8ac3be67584700d8ef0ef5a1fd97fff9`.

The benchmark-capable Richards harness was also required to reproduce the immutable D24 validation outputs exactly:

- R16:
  `c0571d38427e4122a6376afb9f24aa6a1c625b2ba2524f81542c5dca3bb0c826`;
- R2:
  `a1fec425c91e5131bccb53874ed4f8d82c65a62d8e8e3a6b901806b710e20748`.

Both O0/O2 pairs are byte-identical to their D24 evidence.

Thus D25 does not obtain computational value by changing the D24 science.

## 6. Timing calibration without effect information

Internal batch length was selected using R16 only.

No FMC or R2 timing effect was exposed during calibration.

The frozen sequence was 1, 2, 4, 8, 16, 32, ... complete D24 workloads.

R16 CPU observations were approximately:

| repetitions | R16 CPU |
|---:|---:|
| 1 | 0.0255 s |
| 2 | 0.0508 s |
| 4 | 0.0976 s |
| 8 | 0.2033 s |
| 16 | 0.3973 s |
| 32 | 0.7985 s |

The first preregistered qualifying value is therefore **32 repetitions**.

That value was frozen before the FMC/R2 timing screen.

## 7. Frozen shared-host screen

The measured screen used:

- 3 discarded warmups per route;
- 30 measured samples per route;
- six FMC/R2/R16 execution permutations repeated five times;
- 32 complete D24 workloads per measured process;
- no post-hoc timing outlier deletion;
- deterministic scientific checksums for every measured sample.

Primary CPU time is in-process Fortran `CPU_TIME`, excluding compilation and detailed validation-output serialization.

### Mean CPU per complete D24 workload

| route | mean CPU | median CPU |
|---|---:|---:|
| FMC | **0.0019505 s** | 0.0019519 s |
| R2 | 0.0050101 s | 0.0049767 s |
| R16 | 0.0249471 s | 0.0249018 s |

### Screening CPU ratios

Mean ratios:

- FMC / R16: **0.07819**;
- R2 / R16: **0.20084**;
- FMC / R2: **0.38944**.

The reciprocals are descriptively about:

- R16 / FMC: **12.79**;
- R2 / FMC: **2.57**;
- R16 / R2: **4.98**.

These reciprocals are **not formal speedup claims**.

They are only another way to read the frozen screening ratios from this one shared-host run.

## 8. Was the FMC-vs-R16 cost signal resolved inside this run?

Yes, under the preregistered screening rule.

Paired FMC-minus-R16 CPU per workload:

- mean: about **-0.0229966 s**;
- paired SD: about **0.00020084 s**;
- SE: about **3.67e-5 s**;
- mean + 2 SE: about **-0.0229232 s**.

The upper two-SE screening bound remains below zero.

The frozen classification is therefore:

`FMC_SHARED_HOST_COST_ADVANTAGE_RESOLVED_RELATIVE_TO_R16`.

This means the sign of the cost difference is not ambiguous in this run.

It does **not** mean that the host has become formally admitted.

## 9. Cost-fidelity frontier

D25 should be read together with D24.

D24 showed that, in the bounded hydraulic envelope, FMC is hydrologically closer to R16 than R2 on all eight frozen decision views.

D25 now shows that, in a compiled same-language implementation of exactly that workload, FMC also has a substantially lower measured CPU cost than both R16 and R2 on the shared host.

So within this bounded experiment:

- R16 remains the fuller hydrological reference;
- R2 is cheaper but less faithful on every D24 decision view;
- FMC is both more faithful than R2 on those views and cheaper in the D25 screen.

That is a meaningful computational-value signal.

It is not yet a general application result.

## 10. What D25 does not answer

The D24/D25 envelope still omits major application physics and horizons:

- root water uptake;
- actual/potential evapotranspiration partitioning;
- transpiration stress;
- seasonal dry-down and recovery;
- multi-day to multi-year accumulation;
- arbitrary groundwater depths;
- dynamic/live groundwater feedback;
- heterogeneous soils/material transfer;
- operational or policy decision thresholds.

FMC therefore has not yet earned application acceptance merely because its bounded hydraulic cost-fidelity point is attractive.

## 11. Next scientific boundary

The main blocker is no longer basic computational plausibility.

The next high-value research question is purpose-specific hydrological fidelity.

A successor should add, under a new preregistered authority:

1. root uptake / ET forcing and its water-ledger semantics;
2. longer dry-down / recharge / recovery horizons;
3. balance, soil-moisture and groundwater-response metrics chosen for the intended application before validation.

The frozen D24 FMC equations, 200-bin representation and 10-second process step must not be changed merely to improve D25 performance.

Formal performance qualification remains deferred until an admitted isolated runner exists.

Production ROM remains unauthorized.
