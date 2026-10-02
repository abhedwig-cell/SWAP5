# TOP03 finite surface-contact resistance decision

Date: 2026-10-02  
Status: FINITE_CONTACT_RESISTANCE_ROBUSTLY_SUPPORTED__NO_PRODUCTION_ADMISSION  
Evidence run: GitHub Actions 36980868364  
Preservation run: GitHub Actions 36980868227  
Source postimage: `175770f781636a940ee14c336ff03b22f8d04c24`  
Canonical inspected: `641a8ba7fad5b67f0ebff7c78dd065270ed46329`

## Question

Does a finite hydraulic resistance between open surface water and the soil matrix provide the missing continuous matrix-to-surface-water transition that simple microrelief alone did not?

The tested law adds an explicit resistance `R_s` in series with the existing soil-face resistance:

```
R_total = d/K_face + R_s
K_eff   = d/R_total
K_contact = f_wet K_eff
```

This is a Robin/Cauchy contact law. It changes the physical interface, not the Richards solver, temporal acceptance policy or constitutive soil law.

## Controls

All `R_s=0` cases reproduce the failure locations from the previously persisted microrelief stage-evolution experiment. The new resistance implementation therefore preserves the prior research law when disabled.

The dedicated O0/O2 outputs are exactly identical.

The existing TOP03 transactional-exchange preservation workflow also passes on the research head.

## Result

No tested combination with `R_s <= 0.25 day` completes the full six-stage trajectory at all four temporal refinements.

At `R_s=0.50 day` the result changes qualitatively:

- every tested microrelief amplitude `D = 0, 0.02, 0.05, 0.10, 0.25 cm` completes the full trajectory;
- every amplitude completes at 1, 2, 4 and 8 substeps per stage event;
- for every amplitude, state, cumulative top transfer and cumulative bottom transfer contract over both successive refinement chains `1-2 -> 2-4` and `2-4 -> 4-8`.

`R_s=1.00 day` gives the same structural result.

The largest absolute whole-trajectory ledger residual among complete trajectories is approximately `4.02e-14 cm`; the largest accepted soil-mass residual is approximately `2.62e-14 cm`.

This exceeds the preregistered robustness requirement. The successful behavior is not an isolated single resistance or single microrelief amplitude.

## Mechanism separation

The most important result is the flat-surface control.

At `D=0`, where there is no gradual increase in wetted fraction or microrelief storage at all:

- `R_s=0` through `0.25 day` retain nonlinear failure;
- `R_s=0.50` and `1.00 day` complete all refinement levels and show the same joint state/top/bottom contraction.

Therefore the fixed-stage microrelief benefit was real, but microrelief is **not necessary** for the numerical regularization in this fixture once a sufficiently finite interface resistance is present.

The evidence supports a two-part physical description:

1. surface geometry determines wetted fraction and local surface storage;
2. a separate finite contact law determines hydraulic exchange between wetted surface and matrix.

For TOP03's current failure, the second term is the stronger mechanism.

## What the resistance values mean

The successful values are mechanism probes, not calibrated parameters or production defaults.

For a face distance `d=1 cm`, `R_s` is a true series resistance in days. It limits the effective wet-area conductivity by

```
K_eff = K_face / (1 + R_s K_face/d)
```

so it remains state-dependent through `K_face`; this is not a fixed numerical conductivity cap.

The present sweep only shows that the transition becomes numerically coherent somewhere between the tested `0.25` and `0.50 day` values for this synthetic four-node fixture. It does not establish that this bracket is physically correct for field soils.

## Decision

Retain finite surface-contact resistance as the preferred physical prerequisite for TOP03.

Do not select `R_s=0.50 day` as a production default. Before production admission:

- define the physical meaning and ownership of the contact parameter;
- determine whether an existing SWAP parameter already represents this interface or whether a new explicit parameter is required;
- qualify a defensible parameter envelope on representative soils/stages rather than this single synthetic fixture;
- preserve microrelief as a separate optional geometry/storage model rather than conflating it with contact resistance;
- only after that, derive the dynamic-top temporal state/top/bottom acceptance budget from complete refinement evidence.

The exact-state BASE temporal policy remains unchanged. PR #956 remains draft and unadmitted.

Machine-readable evidence: `integration/sw-rib-top03/TOP03_CONTACT_RESISTANCE_RESULT.json`.
