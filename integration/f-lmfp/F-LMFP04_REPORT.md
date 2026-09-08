# F-LMFP04 — FullRichards Hydraulic A/B Qualification I

**Workunit:** F-LMFP04  
**Branch:** `work/f-lmfp04-fullrichards-ab1`  
**Base:** F-LMFP03 `3d703041bac16ac20fb32085f5e4ccb70cee40eb`  
**Decision:** `QUALIFIED_INITIAL_FULLRICHARDS_AB_READY_FOR_FLUX_CLOSURE_ATTRIBUTION`  
**Production admission:** none

## 0. Executive finding

The first direct hydraulic A/B comparison between the standalone LayeredMFP prototype and the SWAP5 FullRichards reference route is encouraging but does not yet define a qualification envelope.

For a steady homogeneous free-drainage state, the two routes are numerically identical to floating-point accuracy. For moderate prescribed-flux infiltration in homogeneous sand-like and clay-like profiles, the differences after the test windows are very small: maximum volumetric water-content differences are below `5e-7`, maximum head differences below `0.002 cm`, and bottom-flux differences below `1e-5` relative.

The more diagnostic redistribution and heterogeneous cases show a different pattern. They remain mass-conservative and qualitatively consistent, but profile differences persist when the time step is halved. In the homogeneous redistribution case the fine-step maximum water-content difference is about `8.94e-4` and the maximum pressure-head difference is about `1.28 cm`. In the heterogeneous cases the fine-step maximum water-content differences are about `1.22e-4` and `2.85e-4`, with maximum head differences about `0.26 cm` and `0.53 cm`.

Those offsets are much larger than either solver's own coarse-to-fine change. They therefore cannot reasonably be attributed primarily to time-integration error. The next workunit must attribute the difference to the spatial/face flux closure before changing LayeredMFP or declaring an application envelope.

The leading hypothesis is concrete: the F-LMFP03 LayeredMFP prototype uses an MFP-secant conductivity over a face, while the admitted FullRichards test route uses `SWKMEAN=1`, the unweighted arithmetic mean of endpoint conductivities. These approximations are not algebraically identical when `K(h)` varies strongly. This hypothesis is not yet treated as proven.

## 1. Reference route and harness fidelity

F-LMFP04 does not use a separately written Richards solver as its primary reference. The reference side is the existing SWAP5 route:

- `reference_richards_legacy_solver_t`;
- common `soil_water_solve_request_t` and candidate result contract;
- explicit state binding;
- worker-owned reference workspace;
- current repository `src/legacy/b1_10_port/headcalc.f90`;
- current `mod_b110_default_mvg_provider`;
- explicit top-flux provider;
- zero source/sink provider;
- free-drainage bottom boundary (`bottom_mode=7`).

The supplied `/mnt/data/SWAP_4.3.1(6).zip` remains supporting provenance, but its `HeadCalc` is not byte-identical to the current SWAP5 pinned source. It is therefore not used as the authoritative A/B oracle.

The existing F-SI04/F-SI09 isolation fixture cannot be used unchanged for dynamic hydraulic tests because its `tridag` stub deliberately returns zero corrections. F-LMFP04 replaces only this fixture routine with a normal Thomas tridiagonal solve. The real current HeadCalc still constructs the nonlinear residual and Jacobian. Use of the separate banded fallback is forbidden by the driver and would fail the gate.

The support fixture also provides `hcomean`. For the numerical configuration used here (`SWKMEAN=1`), its arithmetic mean `0.5*(K_up+K_low)` matches the supplied SWAP 4.3.1 `functions.f90` definition of `hcomean` for mode 1. Other `SWKMEAN` modes are outside F-LMFP04.

This is therefore a high-fidelity hydraulic-core A/B harness, not a complete standalone SWAP application run.

## 2. Test matrix

All tests use four finite-volume layers with thicknesses `[10, 10, 20, 20] cm`, explicit top flux, zero distributed source/sink, no root uptake, no drains, no macropores, no ponding switching and free drainage at the bottom.

Two synthetic B1.10-compatible materials are used only to span contrasting hydraulic behaviour:

- sand-like: `theta_r=0.045`, `theta_s=0.430`, `Ks=20 cm/d`, `alpha=0.040 cm-1`, `n=1.80`, `lambda=0.50`;
- clay-like: `theta_r=0.080`, `theta_s=0.500`, `Ks=0.20 cm/d`, `alpha=0.010 cm-1`, `n=1.30`, `lambda=0.50`.

Cases:

1. `steady_sand`: uniform `h=-100 cm`, top flux equal to free-drainage `K(-100)`;
2. `redistribution_sand`: `h=[-200,-120,-60,-30] cm`, zero top flux;
3. `infiltration_sand`: uniform `h=-200 cm`, downward top flux `0.10 cm/d`;
4. `infiltration_clay`: uniform `h=-200 cm`, downward top flux `0.01 cm/d`;
5. `sand_over_clay`: upper two layers sand-like, lower two clay-like;
6. `clay_over_sand`: upper two layers clay-like, lower two sand-like.

Every case is run at a base step and at half that step.

## 3. CI evidence

GitHub Actions run `34257257191`, job `102166075347`, head `5f6b08af49d32a959066ec035b5b130679a8309a` completed successfully.

The gate reported:

- `F-LMFP04_REAL_TRIDIAG_FIXTURE PASS`;
- `F-LMFP04_FULLRICHARDS_REFERENCE_PASS`;
- `F-LMFP04_AB_STRUCTURAL_GATE PASS`.

Artifact ID: `10068369275`.  
Artifact ZIP SHA-256: `20c2fc09583b2c1d25657a10af5b13246d96eab7a03e66c2c554040da465f4d8`.

The FullRichards source compilation emitted pre-existing compiler warnings concerning possible uninitialised `sum1` and a `dkmean` result path in HeadCalc. They did not trigger in the tested routes and are not interpreted here as LayeredMFP evidence.

## 4. Structural results

All twelve LayeredMFP trajectories were accepted without retry. Both routes closed mass well inside the deliberately conservative A/B structural thresholds.

- FullRichards maximum observed step mass residual was of order `5e-13 cm` or smaller.
- LayeredMFP maximum observed step mass residual was of order `4e-15 cm`.
- No FullRichards banded fallback was used.
- No LayeredMFP storage clipping was used.

The steady homogeneous free-drainage case is essentially an identity test. At the fine step:

- maximum `theta` difference: `8.88e-16`;
- maximum head difference: `1.00e-10 cm`;
- relative bottom-flux difference: `3.77e-12`.

This verifies sign conventions, constitutive alignment, storage bookkeeping and the unit-gradient bottom closure for this equilibrium-like route.

## 5. Dynamic A/B results

The table below reports the finer of the two step sizes.

| Case | max |Δtheta| | max |Δh| cm | |ΔS| cm | relative bottom-flux difference | flow-direction agreement |
|---|---:|---:|---:|---:|---:|
| steady_sand | 8.88e-16 | 1.00e-10 | 7.11e-15 | 3.77e-12 | no changing nodes |
| infiltration_sand | 4.63e-7 | 1.64e-3 | 7.72e-10 | 8.97e-6 | 4/4 |
| infiltration_clay | 1.51e-7 | 4.48e-4 | 1.09e-9 | 4.70e-6 | 4/4 |
| redistribution_sand | 8.94e-4 | 1.282 | 1.07e-3 | 1.204e-2 | 4/4 |
| sand_over_clay | 1.22e-4 | 0.261 | 1.43e-7 | 6.26e-5 | 4/4 |
| clay_over_sand | 2.85e-4 | 0.530 | 1.65e-5 | 5.09e-4 | 4/4 |

The infiltration cases are strikingly close despite LayeredMFP's explicit storage update and FullRichards' implicit nonlinear solve. This is useful positive evidence, but the cases are moderate and far from ponding or sharp wetting fronts.

The redistribution case is the largest discrepancy. The fine-step bottom flux differs by about 1.2%, while all four layer storage changes still have the same direction. That is not a failure of mass conservation or sign convention. It is a difference in how the model distributes flux internally.

## 6. Time-step refinement separates temporal error from model-form error

For each dynamic case, the coarse and fine endpoints of each solver were compared with each other. The fine-step LayeredMFP-versus-FullRichards difference was then compared with that self-refinement signal.

### redistribution_sand

- FullRichards coarse-to-fine max `theta` change: `8.18e-6`;
- LayeredMFP coarse-to-fine max `theta` change: `9.47e-6`;
- fine cross-model max `theta` difference: `8.94e-4`.

The cross-model difference is about 109 times the FullRichards refinement signal and 94 times the LayeredMFP refinement signal.

### sand_over_clay

- FullRichards self-refinement: `1.90e-7`;
- LayeredMFP self-refinement: `1.19e-7`;
- fine cross-model difference: `1.22e-4`.

The cross-model difference is roughly 644 to 1028 times the self-refinement signals.

### clay_over_sand

- FullRichards self-refinement: `5.54e-7`;
- LayeredMFP self-refinement: `5.60e-7`;
- fine cross-model difference: `2.85e-4`.

The cross-model difference is about 509 to 515 times the self-refinement signals.

Even the very small infiltration differences remain several times larger than the self-refinement signal, so they should not be called numerical identity. Their absolute size is nevertheless small in this test matrix.

The evidence therefore supports a material **face-closure/model-discretisation difference**, not a claim that the remaining discrepancy disappears as `dt -> 0`.

## 7. Leading closure hypothesis

For a homogeneous face, F-LMFP03 computes

`K_sec = [Phi(h_u)-Phi(h_l)] / (h_u-h_l)`

and then the downward-positive Darcy flux

`q_LMFP = K_sec * [1 + (h_u-h_l)/L]`.

The F-LMFP04 FullRichards route uses `SWKMEAN=1`. In the supplied SWAP 4.3.1 implementation this is the unweighted arithmetic mean

`K_mean = 0.5*(K_u+K_l)`,

followed by the discrete hydraulic gradient.

For nonlinear `K(h)`, `K_sec` and `0.5*(K_u+K_l)` are generally different. The discrepancy should grow when endpoint heads span a region with strong conductivity curvature, which is consistent with the redistribution result.

This is a hypothesis requiring direct face-level attribution in F-LMFP05. F-LMFP04 does not yet decide that the MFP-secant is better or worse.

For heterogeneous material interfaces an additional caution applies. LayeredMFP imposes a continuous interface pressure head and equal flux through two half-layer material segments. A coarse FullRichards face with endpoint conductivity averaging is a numerical reference implementation, but it is not automatically a grid-converged representation of the material discontinuity. The correct scientific comparison should therefore include FullRichards spatial refinement around the interface before forcing LayeredMFP to reproduce the coarse-grid result.

## 8. Cost observations

No wall-clock performance claim is made yet. The diagnostics do show a useful structural difference.

FullRichards nonlinear work in the base-step runs was:

- steady sand: 1 iteration per step;
- sand infiltration: 3 iterations per step;
- clay infiltration: 2 iterations per step;
- redistribution sand: up to 5 iterations per step, 198 nonlinear iterations over 40 steps;
- sand over clay: 3 iterations per step;
- clay over sand: 4 iterations per step in the coarse run.

LayeredMFP needed no local nonlinear interface solve in homogeneous cases. The heterogeneous cases used at most 31 scalar bisection iterations at the material face, with no column-global Newton/Jacobian/linear solve and no retry in this matrix.

This supports the bounded-local-work performance hypothesis, but operation counts and wall-clock cost are not directly comparable yet. MFP lookup, inverse `h(theta)` and branch behaviour still have to be measured in a production-like implementation.

## 9. What F-LMFP04 does and does not establish

Established within this narrow testbench:

- the FullRichards and LayeredMFP sign and storage conventions are aligned;
- both paths conserve mass in the selected hydraulic-only cases;
- LayeredMFP exactly reproduces the steady uniform free-drainage state;
- moderate homogeneous infiltration is very close to the FullRichards reference;
- redistribution and heterogeneous profiles expose reproducible cross-model offsets;
- those offsets are not primarily removed by halving the time step;
- local LayeredMFP work remains bounded in the tested heterogeneous cases.

Not established:

- a production qualification envelope;
- ponding or infiltration-capacity behaviour;
- strong wetting fronts;
- evaporation or root uptake coupling;
- drainage processes;
- prescribed bottom head;
- shallow groundwater;
- MODFLOW response tangents;
- B12/heavy-clay behaviour;
- other SWAP hydraulic model families;
- production MFP-table accuracy;
- wall-clock speedup;
- grid-converged equivalence to Richards at material discontinuities.

## 10. Architecture invariant check

No production source was modified, so invariants 1, 2, 20, 21, 22 and 23 remain intact by construction. LayeredMFP is still a separately selected soil-water model and not an execution-policy fallback.

The prototype remains compatible with compact storage and worker scratch (4, 5, 6, 16, 27), transaction-owned commit/discard (7, 8), generic step duration (9), hard mass conservation (13), reference-mode qualification (25), explicit diagnostics (26) and no hidden day/file/MODFLOW assumptions (29).

Groundwater/coupling invariants 11, 12, 14, 15, 18 and 28 remain design obligations but are outside this A/B scope and are not claimed as satisfied by F-LMFP04.

Invariant 24 remains open: this matrix did not yet test difficult clay/B12 columns or quantify retry cost cliffs.

## 11. Decision

**Decision: `QUALIFIED_INITIAL_FULLRICHARDS_AB_READY_FOR_FLUX_CLOSURE_ATTRIBUTION`.**

The initial A/B does not show a reason to abandon LayeredMFP. On the contrary, the homogeneous steady and moderate infiltration results show that the reduced-order structure can track FullRichards very closely while preserving mass and bounded local work.

It would nevertheless be premature to widen the test matrix immediately. The persistent redistribution and heterogeneous profile offsets need to be understood first. Otherwise later tests would mix genuine process limitations with a still-unattributed face-discretisation choice.

## 12. Recommended next workunit

**F-LMFP05 — Flux Closure Attribution & Refined Richards Reference**

Minimum scope:

1. compare, on identical frozen states, the FullRichards arithmetic-`K` Darcy face flux and the LayeredMFP MFP-secant flux;
2. separate conductivity averaging error from explicit time-integration error;
3. repeat homogeneous redistribution with multiple spatial resolutions;
4. refine FullRichards around sand/clay and clay/sand interfaces while preserving the physical profile;
5. compare LayeredMFP to the spatially refined Richards limit, not only the four-layer coarse discretisation;
6. determine whether the LayeredMFP face closure should remain MFP-secant, be modified, or become resolution/material-contrast dependent;
7. retain mass conservation and bounded local cost as hard gates;
8. make no production integration or application-envelope claim in F-LMFP05.

Only after this attribution is complete should the workstream proceed to broader infiltration fronts, ponding, drainage, root uptake, groundwater and performance qualification.
