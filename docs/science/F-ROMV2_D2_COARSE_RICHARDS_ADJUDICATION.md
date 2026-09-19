# F-ROMV2 D2 coarse-Richards adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D2  
**Decision:** **COARSE_RICHARDS_REMAINS_SERIOUS_PHYSICAL_REDUCTION_CANDIDATE**

## Purpose

D2 asks whether a simple physical reduction, obtained by solving the same B01 Richards physics on fewer vertical cells, deserves to remain on the cost-fidelity frontier before a more elaborate quasi-steady or learned reduction is designed.

D2 is development evidence on already exposed forcing histories. It is not blind application validation.

## Immutable execution

Complete workflow run **35441802458**, job **105893780103**, executed head
`329ffa7582f592529984b172f5c4fc01240dc363`.

Artifact:

- ID: **10583802946**
- digest: `sha256:95cd25551da619091f8e3b2d14c494cf55ddb39bf650ac41d806b049e22e252b`

Frozen result payload SHA-256:

`abfa8e6adc208971d7dcbec08bb155b717a40ba566c1dee00e77f8c4dd7397c9`.

The earlier run 35441681811 terminated the census after the first R4 scientific failure. The repair changed orchestration only, so that every preregistered geometry was attempted independently. No scientific policy was changed.

## R8 result

R8 is the only coarse geometry that completes all 768 development endpoints under the frozen research Reference policy and hard transaction mass gate.

Relative to R16:

- total-storage RMSE: **0.017992 cm**;
- cumulative bottom-exchange RMSE: **0.017992 cm**;
- terminal bottom-flux RMSE: **1.640922 cm d-1**;
- mapped water-content RMSE: **0.0003199**;
- mapped pressure-head RMSE: **0.1177 cm**;
- bottom-flux sign errors: **136/768 = 17.7%**;
- reversal-sequence mismatch: **8/12 histories**.

Computational proxies:

- nodes: 8 versus 16;
- nonlinear iterations: 2654 versus 3188, ratio 0.8325;
- backtracking attempts: 3290 versus 4135, ratio 0.7956;
- research Reference fallbacks: 484 versus 65, ratio 7.45.

There is therefore no general “half the nodes means twice as fast” result. The coarser grid performs less raw nonlinear work but enters the strict research fallback route far more often.

## Purpose-dependent meaning of R8

R8 separates cumulative and event fidelity strongly.

On V01-V04, final cumulative-bottom-exchange error relative to R16 ranges from about -1.97% to +14.74% in the exposed histories. Yet R8 reproduces none of the R16 reversal sequences in those histories and accumulates 16-20 bottom-flux sign errors per history.

That makes R8 scientifically plausible as a **balance-focused physical reduction candidate**, but not as a fast-event or lower-boundary-flux-dynamics model on current evidence.

No percentage above is an acceptance criterion. These are observed development discrepancies only.

## R4 and R2 are not hydrological no-go results

R4 and R2 both stop at the first post-seed interval under the frozen research Reference numerical authority.

R4:

- class: `RETRY_LOCAL_BALANCE`;
- local integrated residual: about **1.94e-15 cm**;
- frozen allowed local integrated residual: **1.60e-15 cm**;
- absolute total residual: about **1.61e-15 cm**.

R2:

- class: `RETRY_LOCAL_BALANCE`;
- local integrated residual: about **2.37e-15 cm**;
- frozen allowed local integrated residual: **1.60e-15 cm**;
- absolute total residual: about **2.84e-15 cm**.

Both total residual scales are far below the separate hard accepted-transaction mass gate of **1e-12 cm**.

The violated criterion is inherited from a strict Reference-sample policy created to measure a numerical Reference floor. It is not an independently justified hydrological-fidelity requirement for a deliberately reduced model.

Therefore D2 supports only:

- `R4_FROZEN_REFERENCE_POLICY_NO_GO`;
- `R2_FROZEN_REFERENCE_POLICY_NO_GO`.

It does **not** support:

- `R4_HYDROLOGICALLY_INVALID`;
- `R2_HYDROLOGICALLY_INVALID`.

Retuning the D2 threshold after seeing these failures is prohibited. A successor must define a reduced-model numerical/accepted-state authority independently before execution.

## Relation to F-ROMV2

This distinction is the central F-ROMV2 rule.

An alternative numerical solver for the same Richards solution can be held to a tight Reference-equivalence envelope.

A deliberately reduced hydrological model must instead satisfy:

1. application-independent integrity;
2. purpose-dependent hydrological fidelity;
3. explicit validity-domain behavior;
4. useful computational value.

A local solver residual threshold inherited from full-order numerical-equivalence research cannot automatically become an application-independent ROM criterion.

## Decision

D2 retains **R8** as a serious physical-reduction comparator.

It also leaves open, but does not positively qualify, the scientific possibility that R4/R2 could become legitimate balance-oriented reductions under a separately preregistered accepted-state policy.

The next workunit must therefore avoid two errors:

- do not loosen D2 after the result;
- do not discard R4/R2 merely because the strict Reference-floor route rejected them.

A successor should use an independently justified reduced-model accepted-state authority, preserve the hard water ledger and physical bounds, and then compare:

- R16;
- R8;
- any safely executable R4/R2 route;
- a low-dimensional layered-bucket or quasi-steady/integrated-manifold reduction.

Production ROM remains unauthorized.
