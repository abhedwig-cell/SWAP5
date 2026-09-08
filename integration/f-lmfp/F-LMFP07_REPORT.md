# F-LMFP07 — Transient Darcian-Lookup Candidate A/B/C

**Workunit:** F-LMFP07  
**Branch:** `work/f-lmfp07-transient-darcian-candidate-ab`  
**Base:** F-LMFP06 `f53ac0cc6291bf006fd490155bd857f1a38d72f5`  
**Decision:** `QUALIFIED_TRANSIENT_DARCIAN_SIGNAL_READY_FOR_PHYSICS_INFORMED_LOOKUP_REFINEMENT`  
**Production admission:** none

## 0. Executive finding

F-LMFP07 tests whether the steady-Darcian face physics qualified in F-LMFP06 remains useful when embedded in the generic-time, explicitly mass-conservative LayeredMFP column update.

The result is deliberately mixed.

The Darcian idea survives transient testing and is especially useful in the regime that motivated F-LMFP06: strong vertical hydraulic gradients in homogeneous coarse blocks. In all five strong-gradient transient controls, the 16 x 16 oracle-derived Darcian lookup follows a direct per-step steady-Darcy face closure more closely than the current MFP closure. The improvement in maximum theta error ranges from about 1.6x to 22.7x.

However, the same 16 x 16 absolute-K_DAR lookup is not a suitable final representation. In the ordinary F-LMFP04 cases it is less accurate than the current MFP closure against a direct Darcian face control in five of six cases. It also loses the exact homogeneous equal-head identity and therefore perturbs the otherwise exact steady-sand control.

A separate density experiment confirms that this weakness is substantially interpolation-driven. Increasing the head grid from 16 to 32 points reduces p90 face-flux error against the independent steady-Darcy oracle by about 3.8x for sand-sand and 4.7x for sand-clay, while the storage cost remains only 8192 bytes of double values per face class before metadata. Even at 32 points, though, raw absolute-K interpolation does not preserve the known equal-head identity exactly.

The correct conclusion is therefore not to replace the MFP closure by the current lookup. The Darcian signal is strong enough to continue, but F-LMFP08 should design a physics-informed representation that preserves exact limiting identities and represents only the additional gravity/capillarity correction that MFP does not already capture well.

No production source is changed in F-LMFP07.

## 1. Scope and reference hierarchy

The workunit keeps four distinct objects separate:

1. **FullRichards reference**: the admitted SWAP5 `reference_richards_legacy_solver_t` path used in F-LMFP04, with B1.10 hydraulics, real Thomas tridiagonal solve, `SWKMEAN=1`, explicit top flux and free-drainage bottom boundary.
2. **Current LayeredMFP closure**: MFP-secant flow in homogeneous material and the equal-full-flux interface-head solve at material changes.
3. **Darcian lookup candidate**: an immutable table of `K_DAR(h_upper,h_lower)` generated outside the transient solve from the independent F-LMFP06 steady-Darcy oracle and evaluated by O(1) bilinear interpolation.
4. **Direct Darcian face control**: the same transient explicit storage update as LayeredMFP, but with each internal face flux solved directly from the independent steady one-dimensional Darcy BVP at every step. This is intentionally expensive and is used only to isolate lookup and face-closure error.

The fourth path is **not** a replacement scientific reference for transient Richards physics. It isolates the quasi-steady face closure. FullRichards remains the reference for complete transient soil-water physics.

## 2. Transactional and mass-conservative transient harness

Both reduced-order candidates use the same conservative update:

`W_i(n+1) = W_i(n) + dt * [q_(i-1/2) - q_(i+1/2)]`

for the hydraulic-only cases in this workunit.

The top flux is explicit and the bottom boundary is unit-gradient free drainage. There are no crop, root uptake, drainage-process, ponding, groundwater or MODFLOW terms in this gate.

A candidate trial never clips water content after the update. If storage bounds would be exceeded, it returns the unchanged base state and an explicit failure/advised-step result. The F-LMFP07 tested trajectories required no such candidate rejection.

The largest mass residual over the principal MFP/lookup matrix was:

`4.62e-15 cm`

and the direct-Darcian transient control closed to:

`4.76e-15 cm`.

This is numerical roundoff scale for the tested balances and remains far below the structural `2e-10 cm` gate.

## 3. Lookup coverage is fail-closed

The experimental lookup envelope is `-500 <= h <= -1 cm`.

F-LMFP07 does not inherit the extrapolating behavior of the F-LMFP06 feasibility class. The transient wrapper checks the envelope explicitly. A head outside the table range causes a visible candidate failure.

There is no silent:

- extrapolation;
- switch back to MFP;
- switch to FullRichards;
- numerical-policy fallback.

The principal six-case matrix used 1980 transient face lookups with zero envelope misses. The strong-gradient matrix used 150 lookups with zero misses.

This is important for invariant 23: a LayeredMFP face representation is part of the selected soil-water model, not an execution-policy substitution.

## 4. A/B/C against FullRichards on the F-LMFP04 cases

The six original hydraulic fixtures were rerun at the two F-LMFP04 temporal resolutions.

At the fine resolution, theta RMSE against the same-grid FullRichards path was:

| case | current MFP | 16 x 16 Darcian lookup | interpretation |
| --- | ---: | ---: | --- |
| steady sand | `4.44e-16` | `1.53e-5` | raw lookup destroys an exact identity |
| infiltration sand | `2.59e-7` | `3.09e-6` | MFP clearly closer to same-grid FullRichards |
| infiltration clay | `1.29e-7` | `1.70e-6` | MFP clearly closer |
| redistribution sand | `5.06e-4` | `5.72e-4` | both differ; MFP slightly closer to SWKMEAN=1 |
| sand over clay | `7.01e-5` | `5.34e-5` | lookup closer to same-grid FullRichards |
| clay over sand | `1.61e-4` | `1.58e-4` | lookup marginally closer |

Across both temporal resolutions, the lookup has lower theta RMSE than current MFP in 4 of 12 comparisons. Those four are the two heterogeneous cases at both resolutions.

This table must not be overinterpreted. F-LMFP05 already established that `SWKMEAN=1` and equal-flux/Darcian interface physics have different discontinuity limits. Same-grid FullRichards proximity is therefore a diagnostic, not the sole physical admission criterion for the material interface.

## 5. Direct Darcian transient closure control

To separate lookup interpolation from Darcian face physics, the fine-resolution six-case matrix was repeated with the independent steady-Darcy BVP solved directly at every internal face and every transient step.

Maximum theta difference relative to that direct-Darcian transient control was:

| case | current MFP | 16 x 16 lookup | same-grid FullRichards |
| --- | ---: | ---: | ---: |
| steady sand | `4.92e-13` | `2.73e-5` | `4.91e-13` |
| infiltration sand | `3.16e-7` | `5.75e-6` | `1.48e-7` |
| infiltration clay | `2.13e-7` | `3.14e-6` | `6.13e-8` |
| redistribution sand | `2.35e-4` | `1.33e-4` | `1.09e-3` |
| sand over clay | `1.99e-5` | `4.70e-5` | `1.42e-4` |
| clay over sand | `2.22e-6` | `7.07e-6` | `2.85e-4` |

Thus the current MFP closure is closer to the exact face-Darcian control in five of six ordinary cases. The coarse lookup wins only for homogeneous sand redistribution.

This has two consequences.

First, F-LMFP06 did **not** demonstrate that MFP should be discarded. In several ordinary and heterogeneous regimes it is already a very good inexpensive approximation to the local steady-Darcy solution.

Second, the weak ordinary performance of the 16 x 16 table cannot be used to reject Darcian face physics, because the direct-Darcian control itself does not show the same defect.

## 6. Strong-gradient transient controls

The strongest F-LMFP06 discrepancy was homogeneous material under large vertical pressure-head gradients, where gravity and nonlinear capillary conductivity variation interact over a coarse block.

Five short generic-time transient controls were therefore evaluated with:

- direct Darcian face solve;
- current MFP closure;
- 16 x 16 Darcian lookup.

At the finer temporal resolution, maximum theta error against the direct-Darcian trajectory was:

| case | MFP error | lookup error | MFP / lookup |
| --- | ---: | ---: | ---: |
| clay, strong downward gradient | `6.55e-8` | `2.82e-8` | `2.32` |
| clay, strong upward gradient | `6.09e-8` | `3.76e-8` | `1.62` |
| sand strong gradient 1 | `3.70e-5` | `2.56e-6` | `14.43` |
| sand strong gradient 2 | `2.91e-5` | `1.28e-6` | `22.69` |
| sand strong gradient 3 | `6.21e-6` | `1.22e-6` | `5.10` |

The lookup is closer in all five cases.

For the three sand cases, its coarse-to-fine temporal change also closely tracks the direct-Darcian control. This supports the F-LMFP06 diagnosis that MFP's main remaining face error is not the material interface itself but strong homogeneous vertical-gradient physics.

This is the decisive positive result of F-LMFP07.

## 7. Lookup density attribution

The 16-point head grid from F-LMFP06 was intentionally only a feasibility surrogate. The historical SWAP 4.3.1 `MOD_Kavg_Szym` source contains a special `iLogh81` lookup-index path, consistent with a much denser pressure-head table. The actual legacy table values and table-generation program are absent from the supplied archive, so no historical table is claimed to have been reconstructed.

F-LMFP07 independently tests three oracle-generated absolute-K_DAR grids over `-500 .. -1 cm`:

- existing 16-point grid;
- 24-point geometric grid;
- 32-point geometric grid.

The same deterministic validation heads were used for each density.

### sand-sand, 5 cm + 5 cm

| head points | values | bytes before metadata | median rel. error | p90 | maximum |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 16 | 256 | 2048 | 3.36% | 15.13% | 30.82% |
| 24 | 576 | 4608 | 1.60% | 7.93% | 11.70% |
| 32 | 1024 | 8192 | 0.92% | 3.94% | 5.88% |

### sand-clay, 5 cm + 5 cm

| head points | values | bytes before metadata | median rel. error | p90 | maximum |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 16 | 256 | 2048 | 2.05% | 5.99% | 20.19% |
| 24 | 576 | 4608 | 0.86% | 2.62% | 5.86% |
| 32 | 1024 | 8192 | 0.54% | 1.28% | 3.52% |

Going from 16 to 32 points improves p90 error by factors of approximately:

- `3.84` for sand-sand;
- `4.67` for sand-clay.

No direction mismatch occurred in these density validations.

The memory result remains compatible with the intended architecture. A 32 x 32 table is only 8 KiB of double values per face class before metadata and must be shared by compatible columns/templates, never duplicated in each logical column state.

## 8. Exact limiting identities expose a representation defect

A Darcian closure has known identities that should not be sacrificed to interpolation.

For homogeneous material with equal pressure heads:

`h_upper = h_lower = h`

and downward-positive z, the steady solution is unit-gradient gravity flow:

`q = K(h)`.

The MFP closure satisfies this exactly.

The raw absolute-K_DAR bilinear lookup does not. On the sand-sand diagonal validation, maximum relative error in the inferred equal-head flux was approximately:

- 28.8% for 16 points;
- 7.68% for 24 points;
- 6.77% for 32 points.

This is why the F-LMFP07 lookup perturbs the steady-sand trajectory.

Merely making the table denser is therefore not a complete design. F-LMFP08 must preserve the analytic identities by construction rather than hope that interpolation approximates them closely enough.

The same caution applies to the hydrostatic zero-flux line and to response derivatives near regime boundaries.

## 9. Performance and memory interpretation

The principal A/B/C matrix recorded:

- 1968 FullRichards nonlinear iterations over the twelve reference trajectories;
- maximum current-MFP heterogeneous local interface solve cost of 31 scalar bisection iterations;
- 1980 transient Darcian lookup calls;
- 8 lookup face classes built for the principal matrix;
- 2048 total table values for the 16 x 16 principal lookup set, or 16 KiB before metadata;
- zero transient lookup BVP solves once tables were built.

For the strong-gradient matrix:

- 4 lookup face classes;
- 1024 total 16 x 16 values, or 8 KiB before metadata;
- 150 transient lookup calls;
- zero coverage misses.

The expensive steady-Darcy BVP solves used to generate tables are qualification/preparation cost and are not counted as transient production work.

No wall-clock production speedup is claimed. What is established is the desired cost shape: after immutable preprocessing, a Darcian lookup is bounded O(1) scalar work per face with no column-global Newton solve and no branch-dependent local root solve.

The number of unique material-pair/geometry classes at realistic MultiSWAP scale remains an open memory/preprocessing question.

## 10. Consequence for the LayeredMFP face design

F-LMFP07 rejects two simplistic conclusions.

### Do not replace MFP everywhere by the current absolute-K lookup

The 16 x 16 representation loses exact identities and is less faithful to direct Darcian face physics in five of six ordinary trajectories.

### Do not reject the Darcian concept because the coarse lookup is imperfect

The exact face control and the strong-gradient transients show a real physical/numerical signal that MFP misses in the target regime. Lookup density improves oracle agreement rapidly without changing runtime complexity.

The next candidate should therefore start from the strengths of MFP and encode only the missing Darcian correction in a representation that preserves known constraints.

A promising hypothesis for F-LMFP08 is a physics-informed correction representation, for example a normalized correction or residual around the MFP flux rather than an unconstrained absolute `K_DAR` surface. The exact representation is intentionally not fixed by F-LMFP07.

Any such representation must preserve at least:

- homogeneous `h_upper = h_lower` gravity-flow identity;
- hydrostatic zero flux;
- conservative common face flux;
- continuity or explicitly diagnosed non-smoothness needed for response tangents;
- fail-closed table coverage;
- generic geometry and material-pair ownership;
- immutable shared parameter storage.

## 11. Architecture invariant check

F-LMFP07 does not change production architecture, but the candidate direction is checked explicitly.

- **1, one kernel:** no separate application kernel is introduced.
- **2, kernel separate from I/O:** the candidate does not read `.unf` or any file. Lookup construction/loading remains outside the solver kernel.
- **3, explicit data separation:** hydraulic lookup data are immutable parameters, not forcing or dynamic state.
- **4, compact persistent state:** no new committed per-column state is required.
- **5, scratch per worker:** transient face temporaries remain trial-local. Direct-oracle scratch exists only in the experimental reference path.
- **6, scalable memory layout:** tables are shared by compatible face/material/geometry classes and can be packed independently of logical object API.
- **7, transactional timesteps:** rejected trials do not mutate the base state; no clipping is used.
- **8, cheap recomputation:** the same state can be reevaluated with changed forcing without rebuilding immutable tables unless model geometry/material class changes.
- **9, generic time:** all transient reduced-order gates use explicit arbitrary `dt`; no day boundary appears in the solver.
- **11, coupling is core functionality:** no coupling path is implemented here; the face design does not preclude bottom-head or response-tangent work.
- **12, groundwater interface contract:** not yet qualified. Prescribed bottom head is outside this workunit.
- **13, mass conservation absolute:** satisfied to roundoff in all admitted experimental trials.
- **14, interface sensitivities:** not yet implemented; a smooth/table-based closure is attractive because local derivatives can in principle be obtained cheaply. Exact behavior across interpolation cells remains to be qualified.
- **15, coupling cost:** no production coupling loop is added.
- **16, MultiSWAP primary:** O(1) lookup and shared immutable tables are compatible with homogeneous batched execution; unique-class cardinality still needs measurement.
- **18, deep vadose:** unchanged and remains outside SWAP.
- **20, alternative soil-water solvers:** LayeredMFP remains an explicit alternative behind the common solver concept, not a modified FullRichards execution policy.
- **21, SWAP physics reuse:** the same B1.10-compatible constitutive K(h), theta(h) and inverse relations are used.
- **22, no HeadCalc internals downstream:** no new process depends on HeadCalc arrays.
- **23, physics versus solver policy:** no performance policy is allowed to switch to LayeredMFP or between physical solver families silently.
- **24, predictable cost:** lookup transient work is bounded; offline generation cost and class count remain to be qualified.
- **25, Reference mode:** FullRichards is retained and rerun in the gate.
- **26, diagnostics:** lookup coverage, table builds, memory values, face calls, local MFP iterations and FullRichards nonlinear iterations are reported.
- **27, optional cost scales with use:** Darcian lookup data are needed only for LayeredMFP configurations that select the eventual representation.
- **28, runtime/coupler composition:** no MODFLOW/tile/deep-vadose ownership enters the soil solver.
- **29, no silent dependencies:** no file, calendar, daily-step or MODFLOW assumption is introduced.
- **30, explicit architecture check:** this section records the workunit assessment.

## 12. What is not qualified

F-LMFP07 does not qualify:

- the 16 x 16 absolute-K_DAR table as a production representation;
- 24 x 24 or 32 x 32 as sufficient production density;
- the historical SWKMEAN=7 tables or table generator;
- an automatic MFP-versus-Darcian regime switch;
- a final interpolation coordinate or interpolation order;
- lookup behavior above `h=-1 cm`, at saturation, or below `h=-500 cm`;
- ponding or rapid infiltration fronts;
- root uptake;
- drainage;
- groundwater or prescribed bottom head;
- MODFLOW response tangents;
- macropores, swelling/shrinkage, or preferential flow;
- production wall-clock speedup;
- final MultiSWAP table-class cardinality and preprocessing cost.

## 13. Decision and next workunit

Decision:

`QUALIFIED_TRANSIENT_DARCIAN_SIGNAL_READY_FOR_PHYSICS_INFORMED_LOOKUP_REFINEMENT`

The feasibility signal is strong enough to continue, but the current absolute-K lookup is not admitted as the LayeredMFP face implementation.

The next smallest workunit should be:

**F-LMFP08 — Physics-Informed Darcian Correction Representation**

It should remain outside production code and should:

1. preserve exact equal-head gravity and hydrostatic zero-flux identities by construction;
2. test correction/residual representations around the current MFP closure instead of only absolute K_DAR interpolation;
3. compare table coordinates and densities with identical oracle validation sets;
4. quantify continuity and derivative behavior relevant to future response tangents;
5. rerun the six F-LMFP04 trajectories and five strong-gradient transient controls;
6. retain fail-closed coverage and exact mass conservation;
7. measure table memory and preprocessing class count separately from transient runtime work;
8. only after that decide whether broader hydraulic physics such as ponding and groundwater should enter the LayeredMFP qualification matrix.
