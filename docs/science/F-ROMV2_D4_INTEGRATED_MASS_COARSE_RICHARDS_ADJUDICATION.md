# F-ROMV2 D4 integrated-mass coarse-Richards adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D4  
**Decision:** **STRONGLY_COARSE_RICHARDS_HYDROLOGICALLY_MEASURABLE_UNDER_INTEGRATED_MASS_POLICY**

## Question

D4 is the terminal numerical-authority experiment for the coarse-Richards family.

It asks whether R16, R8, R4 and R2 can be evaluated on the same exposed B01
development workload when numerical integrity is expressed in integrated water
depth rather than by a fixed residual rate.

The policy was preregistered independently of D2/D3 residual magnitudes.

## Numerical authority

The hard accepted transaction mass scale remains

[
arepsilon_{depth}=10^{-12} {m cm}.
]

For (N) active compartments D4 assigns

[
arepsilon_{local,depth}=arepsilon_{depth}/N
]

and converts only for the solver interface:

[
arepsilon_{local,rate}=
rac{arepsilon_{depth}}{NDelta t},qquad
arepsilon_{total,rate}=
rac{arepsilon_{depth}}{Delta t}.
]

Thus even the worst-case sum of compartment integrated residual magnitudes is
bounded by the same water-depth scale as the pre-existing hard mass gate.

Head convergence, finite/physical state and the final accepted transaction
water ledger remain hard.

This is research-only reduced-model numerical integrity, not a production
Reference tolerance.

## Immutable execution

Workflow run **35445149845**, job **105902697853**, executed head
`7ceb67d35712cd042f9eb7f88b41584a7220fac1`.

Artifact:

- ID: **10585137684**
- digest: `sha256:812fb3f66ec0c959d0eba82d1fff567a01667a6a84e87b911ef0b3df2cd1636e`
- result SHA-256:
  `58cc68b0a25df2d12899600b046875b25010b510973c3339957664e64ee926e8`.

R16, R8, R4 and R2 all complete at O0 and O2 with bitwise-identical output per
geometry.

No geometry violates the hard accepted transaction mass gate or the frozen B01
water-content bounds.

## Hydrological fidelity

Pooled errors relative to R16 are:

| candidate | nodes | storage RMSE | cumulative bottom-exchange RMSE | terminal bottom-flux RMSE |
|---|---:|---:|---:|---:|
| R8 | 8 | 0.01799 cm | 0.01799 cm | 1.641 cm d-1 |
| R4 | 4 | 0.03215 cm | 0.03215 cm | 2.537 cm d-1 |
| R2 | 2 | 0.04071 cm | 0.04071 cm | 3.002 cm d-1 |

Balance error increases smoothly with coarsening.

Transient lower-boundary fidelity is qualitatively weaker. Every coarse
candidate has:

- 136 bottom-flux sign errors over 768 development intervals;
- reversal-sequence mismatch in 8 of 12 histories.

The V01-V04 histories are particularly clear: R16 contains multiple reversals,
whereas the coarse trajectories publish no corresponding reversal sequence.

Therefore a geometry may remain interesting for cumulative regional balance
while being unsuitable for fast-event or coupling uses that depend on
instantaneous lower-boundary flux direction.

## Development-history scale

Final cumulative bottom-exchange errors relative to the R16 cumulative exchange
include:

| candidate | V01 | V02 | V03 | V04 |
|---|---:|---:|---:|---:|
| R8 | -3.5% | +14.7% | -2.0% | -6.4% |
| R4 | -4.4% | +21.7% | -2.5% | -8.1% |
| R2 | -4.6% | +24.9% | -2.6% | -8.5% |

These percentages are **observations**, not acceptance criteria. V01-V04 are
already exposed development evidence and cannot be used to select a convenient
future tolerance.

## Computational proxies

Raw structural complexity decreases as expected:

- R16: 16 nodes;
- R8: 8;
- R4: 4;
- R2: 2.

Accepted-attempt nonlinear iterations also decrease:

- R16: 3180;
- R8: 2554;
- R4: 2317;
- R2: 1913.

That is not yet a speedup result.

The strict-first policy requires a second numerical attempt on:

- R16: 60/768 = 7.81%;
- R8: 499/768 = 64.97%;
- R4: 684/768 = 89.06%;
- R2: 731/768 = 95.18%.

The failed strict attempt is real work but is not represented by the accepted
nonlinear-iteration count. A strongly coarse Richards model could therefore
have fewer unknowns yet still lose much of its theoretical speed advantage to
retry/reattempt cost.

Formal performance claims require end-to-end timing against the current direct
routes.

## Purpose-dependent adjudication

### Long-term regional water balance

**Candidate family retained, not qualified.**

R8, R4 and R2 now form a genuine development cost-fidelity sequence. Which, if
any, is acceptable depends on application-specific cumulative ET/recharge,
seasonal storage and systematic-bias requirements that have not yet been
frozen.

### Groundwater-coupled many-column simulation

**Not qualified.**

The lower-boundary sign/reversal evidence is currently too weak. A groundwater
coupler can be sensitive to the direction and timing of capillary
rise/recharge, not only their long-term integral.

### Fast events and threshold-sensitive simulation

**Not qualified.**

The development reversal evidence is directly adverse.

### Operational soil moisture / drought

**Not tested.**

The current hydraulic workload has no root uptake, ET stress, drought
persistence or recovery.

### Scientific process/extreme inference

**Not qualified.**

Strongly coarse profiles deliberately discard vertical state structure.

## Architecture implication

D4 closes numerical-policy escalation for coarse Richards. No additional
tolerance workunit is justified merely to make R2/R4 cheaper or more accurate.

The next serious candidate should remove the source of the repeated nonlinear
reattempt itself.

That points to a clean-sheet mass-conservative layered or quasi-steady physical
reduction, not to another looser Richards solve.

Relevant precedent includes:

- MetaSWAP-style storage/flux manifolds based on detailed unsaturated-zone
  physics;
- two-layer thickness-averaged Richards reductions;
- recent layered mass-conservative groundwater/UZ models that retain moving
  groundwater head and capillary exchange while using a cheaper storage/flux
  update.

Those are precedents for the scientific architecture question, not code donors.

## Current conclusion

The useful frontier is no longer simply

> full Richards versus learned ROM.

It now contains at least:

1. R16 full development reference;
2. R8 moderate vertical coarsening;
3. R4 strong vertical coarsening;
4. R2 two-layer Richards coarsening;
5. a still-to-be-tested non-Richards layered/quasi-steady physical reduction;
6. C2 local data-driven reduction for comparison where its domain is covered.

The next study must compare **actual computational cost versus
purpose-dependent hydrological fidelity**, with retry cost included.

Production ROM remains unauthorized.
