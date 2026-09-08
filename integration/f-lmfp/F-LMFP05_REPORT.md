# F-LMFP05 — Flux Closure Attribution & Refined Richards Reference

**Workunit:** F-LMFP05  
**Branch:** `work/f-lmfp05-flux-closure-attribution`  
**Base:** F-LMFP04 `7fd36497ba071ddb7d6fe59677f5f2aa8fdda557`  
**Decision:** `QUALIFIED_FACE_CLOSURE_ATTRIBUTION_READY_FOR_INTERFACE_PHYSICS_QUALIFICATION`  
**Production admission:** none

## 0. Executive finding

F-LMFP05 localises the persistent F-LMFP04 redistribution and layer-interface differences to the spatial face-flux closure, not primarily to LayeredMFP time integration.

On the identical four-layer grid and identical initial state, a diagnostic reduced-order control using the same arithmetic endpoint-conductivity face law as FullRichards `SWKMEAN=1` reproduces the one-step FullRichards storage tendency roughly three to four orders of magnitude more closely than the MFP-secant closure. This is direct attribution evidence. It is not a recommendation to replace the LayeredMFP closure with arithmetic conductivity.

A separate frozen-state spatial-refinement experiment then removes time integration entirely. For a smooth homogeneous sand profile, arithmetic-`K` and MFP-secant face fluxes converge toward one another as the grid is refined. The maximum internal-face difference falls from `7.258e-2 cm/d` at `dx=10 cm` to `9.878e-5 cm/d` at `dx=0.15625 cm`. The fine-grid reduction approaches second order.

At a true material discontinuity the result is qualitatively different. The MFP equal-flux interface construction converges to the local series-resistance, harmonic-conductivity limit. `SWKMEAN=1` converges to the arithmetic endpoint-conductivity limit. The difference therefore remains finite as `dx -> 0`. For the synthetic sand/clay interface used here, the limiting flux magnitudes are approximately `0.007825 cm/d` for the equal-flux/harmonic construction and `0.012462 cm/d` for the arithmetic construction under the selected local hydraulic gradient.

This is not evidence that LayeredMFP is wrong at heterogeneous interfaces. It shows that the coarse and refined FullRichards route with `SWKMEAN=1` embodies a different interface discretisation. A physically qualified interface reference is therefore required before changing LayeredMFP to match FullRichards there.

F-LMFP05 also found that forcing the current Reference HeadCalc toward extremely small `dt` is not a clean way to construct that spatial reference. With a real Thomas tridiagonal solve, the diagnostic route shows non-monotone retry behaviour across grid sizes and cases at very small steps. Those failed probes are retained as evidence and are not treated as a production HeadCalc defect.

## 1. Why F-LMFP05 was needed

F-LMFP04 showed three distinct regimes:

1. steady homogeneous free drainage was effectively identical;
2. moderate homogeneous infiltration was extremely close;
3. redistribution and heterogeneous profiles retained small but reproducible differences when `dt` was halved.

For redistribution and the two material-contrast profiles, the cross-model difference was much larger than either solver's own coarse-to-fine temporal change. The leading hypothesis was the face conductivity closure:

- FullRichards with `SWKMEAN=1`: arithmetic endpoint conductivity;
- LayeredMFP: conductivity implied by the matric-flux-potential secant, with an equal-flux interface solve when materials differ.

F-LMFP05 tests that hypothesis directly.

## 2. Source-bound FullRichards face law

For the admitted F-LMFP04/F-LMFP05 reference configuration, HeadCalc forms the internal hydraulic gradient as

`gradient = (h_upper - h_lower)/distance + 1`

and uses `Kmean` as the face conductivity.

With `SWKMEAN=1`, the supplied SWAP 4.3.1 `hcomean` implementation and the F-LMFP04 source-bound fixture use

`K_arith = 0.5 * (K_upper + K_lower)`.

The corresponding downward-positive diagnostic flux used in F-LMFP05 is therefore

`q_arith = K_arith * [1 + (h_upper-h_lower)/L]`.

This is a semi-discrete spatial law. No `dt` is needed to evaluate it on a frozen state.

## 3. LayeredMFP face law

For a homogeneous material, the current candidate uses

`K_sec = [Phi(h_upper)-Phi(h_lower)] / (h_upper-h_lower)`

with

`Phi(h) = integral K(xi) dxi`,

and

`q_MFP = K_sec * [1 + (h_upper-h_lower)/L]`.

For a material boundary, F-LMFP03 does not average the two endpoint conductivities. It solves one interface pressure head `h_i` such that the full Darcy flux through the upper and lower half segments is equal.

F-LMFP05 uses direct adaptive quadrature of `K(h)` for its spatial-limit probe, not the production-candidate MFP lookup table. This prevents table interpolation resolution from being confused with the face-law question.

## 4. Same-grid attribution against current FullRichards

The first part of the final qualification gate reuses the current SWAP5 reference route:

- `reference_richards_legacy_solver_t`;
- current repository HeadCalc;
- B1.10 constitutive provider;
- real Thomas tridiagonal test fixture;
- `SWKMEAN=1`;
- explicit zero top flux for the attribution profiles;
- free-drainage lower boundary;
- no crop, root sink, drainage process, ponding, macropores or groundwater.

Two reduced-order one-step tendencies are then evaluated from the same base state:

1. the actual MFP-secant candidate closure;
2. an arithmetic-`K` diagnostic control.

The arithmetic control is not a proposed LayeredMFP modification. It exists only to test whether the F-LMFP04 offset follows the known FullRichards face law.

At the fine attribution step on the original four-layer grid:

| Case | MFP vs FullRichards weighted L1 theta-rate error | arithmetic control vs FullRichards | ratio MFP/arithmetic |
|---|---:|---:|---:|
| redistribution_sand | `2.237e-3` | `2.324e-6` | `963` |
| sand_over_clay | `2.194e-4` | `3.033e-8` | `7,233` |
| clay_over_sand | `5.282e-4` | `1.013e-7` | `5,211` |

The direct frozen-face maximum differences on this grid are respectively about:

- `0.0672 cm/d`;
- `0.00658 cm/d`;
- `0.01584 cm/d`.

This establishes the attribution: on the same grid, the FullRichards trajectory follows its arithmetic-`K` closure, while LayeredMFP follows the MFP closure. The persistent F-LMFP04 differences are therefore not unexplained solver noise.

## 5. Homogeneous spatial refinement

A second experiment evaluates the two spatial closures directly, without advancing either model in time.

A continuous piecewise-linear redistribution profile is sampled on uniform grids from 6 through 384 cells over 60 cm. All material is sand-like. Direct MFP quadrature is used.

Maximum absolute internal-face flux difference:

| cells | dx cm | max `|q_MFP-q_arith|` cm/d |
|---:|---:|---:|
| 6 | 10.00000 | `7.2581e-2` |
| 12 | 5.00000 | `4.2258e-2` |
| 24 | 2.50000 | `1.6519e-2` |
| 48 | 1.25000 | `5.1816e-3` |
| 96 | 0.62500 | `1.4513e-3` |
| 192 | 0.31250 | `3.8405e-4` |
| 384 | 0.15625 | `9.8777e-5` |

The last three refinement ratios are approximately `3.57`, `3.78` and `3.89` per factor-two grid refinement, corresponding to observed orders approaching `2`.

This behaviour is consistent with both formulas approximating the same local constitutive flux for a smooth single-material profile. It also explains why a relatively coarse LayeredMFP profile can differ from a coarse Richards grid during redistribution even though the model forms approach one another under spatial refinement.

This is a useful distinction: the reduced-order model can have a legitimate coarse-cell effective flux that is not numerically identical to the endpoint-average flux used by coarse FullRichards.

## 6. Heterogeneous interface limit

The sand-over-clay and clay-over-sand experiments place a material interface exactly at 20 cm and refine the grid while preserving the same continuous pressure-head profile.

Away from the material interface, the same-material face differences again converge rapidly toward zero.

At the material face they do not.

### sand over clay

| cells | q arithmetic cm/d | q MFP cm/d | relative difference |
|---:|---:|---:|---:|
| 6 | `-0.009725` | `-0.007863` | `0.191` |
| 24 | `-0.011608` | `-0.007829` | `0.326` |
| 96 | `-0.012236` | `-0.007826` | `0.360` |
| 384 | `-0.012405` | `-0.007825` | `0.369` |

### clay over sand

| cells | q arithmetic cm/d | q MFP cm/d | relative difference |
|---:|---:|---:|---:|
| 6 | `-0.017524` | `-0.007839` | `0.553` |
| 24 | `-0.013457` | `-0.007825` | `0.419` |
| 96 | `-0.012697` | `-0.007825` | `0.384` |
| 384 | `-0.012520` | `-0.007825` | `0.375` |

Both orientations approach the same limiting values as the two cell centres approach the physical interface.

## 7. Why the heterogeneous limits differ

At the interface the continuous test profile approaches `h = -90 cm`. For the two B1.10-compatible synthetic materials used in this workunit:

- `K_sand(-90 cm) ~= 0.020064 cm/d`;
- `K_clay(-90 cm) ~= 0.004861 cm/d`.

The arithmetic mean is

`K_arith ~= 0.012462 cm/d`.

The harmonic mean is

`K_harm = 2 / (1/K_sand + 1/K_clay) ~= 0.0078253 cm/d`.

The selected local pressure-head slope gives a full Darcy-gradient factor tending to `-1`. Consequently:

- arithmetic endpoint closure tends to `q ~= -0.012462 cm/d`;
- the equal-flux two-half-layer closure tends to `q ~= -0.0078253 cm/d`.

The numerical F-LMFP05 limits match these values.

This result can be derived directly from flux continuity. For two equal half lengths `l`, locally constant `K_u` and `K_l`, and one interface head `h_i`:

`q/K_u = 1 + (h_u-h_i)/l`

`q/K_l = 1 + (h_i-h_l)/l`.

Adding the two equations gives the harmonic series-conductance factor. Thus the LayeredMFP interface construction has a clear local resistance interpretation.

This derivation does **not** by itself prove that the complete LayeredMFP solver is a more accurate Richards discretisation. It establishes only that its material-interface closure enforces the expected equal-flux series structure, whereas `SWKMEAN=1` uses a different conductivity mean.

## 8. Why a tiny-dt FullRichards spatial oracle was rejected

F-LMFP05 initially attempted to estimate the FullRichards semi-discrete rate by repeatedly shrinking the actual Reference step.

That approach was deliberately abandoned rather than tuned until it passed.

### extremely small probe

At diagnostic `dt` values of approximately `2e-7` and `1e-7 d`, all 30 refined-profile attempts returned `legacy-reference-retry` despite use of the real Thomas tridiagonal solver and no intended physics change.

### intermediate small probe

At approximately `2e-5` and `1e-5 d`, convergence became case- and grid-dependent and was not monotone in `dt`. Some `2e-5` runs converged while the corresponding smaller `1e-5` run requested retry; other grids failed at both values.

The relevant HeadCalc path declares retry after the normal nonlinear convergence criteria remain unsatisfied. F-LMFP05 has not established whether cancellation, conditioning, convergence tolerances or another numerical detail dominates this small-step behaviour.

Therefore:

- this is **not** classified as a production Reference defect;
- it is **not** used as LayeredMFP performance evidence;
- it is retained as a failed diagnostic method;
- spatial face-law attribution is instead performed directly from the source-bound semi-discrete formulas.

This is also kept separate from F-SI18. F-SI18 diagnosed a different apparent convergence cliff as a zero-correction-TRIDAG fixture artefact. F-LMFP05 uses a functional Thomas solve, so the two findings must not be conflated.

## 9. Wider frozen face sweep

The final same-grid attribution harness also evaluates 1,296 frozen face combinations spanning:

- both homogeneous materials;
- both material orientations;
- pressure heads from `-1000` to `-1 cm`;
- face distances from `2` to `20 cm`.

Results:

- all 1,296 MFP face evaluations solved;
- maximum local MFP interface bisection count: `47`;
- no flow-direction disagreement was observed between the two closures in this final corrected sweep;
- the magnitude difference can nevertheless become extremely large for deliberately severe cross-material/head combinations.

The worst normalized difference in this sweep was approximately `0.9996`. The corresponding arithmetic flux was about `-417.6 cm/d` while the MFP equal-flux result was about `-0.1593 cm/d` for a very strong clay-to-sand/head contrast. This is not presented as a realistic SWAP application case. It demonstrates that conductivity averaging is a first-order physical/numerical modelling choice under extreme contrasts and must be part of the qualification envelope.

## 10. SWKMEAN=7 provenance finding

The supplied SWAP 4.3.1 source contains a further relevant comparator.

`functions.f90` defines `SWKMEAN=7` as a Darcian mean attributed in the source comments to Szymkiewicz (2009), Szymkiewicz & Helmig (2011), based on a suggestion by Warrick (1991).

The corresponding source module `MOD_Kavg_Szym.f90` is present in the nested source archive. It does not compute the mean from the current two endpoint values alone. It reads a binary table named like

`Kavg_Szymkiewicz_<profile>_<numnod>.unf`

and bilinearly interpolates the stored conductivity mean as a function of top and bottom pressure head for each boundary. The reader verifies the profile identifier, number of compartments, soil-layer assignment and compartment thicknesses.

The required `.unf` tables were not found in the supplied archive. Therefore F-LMFP05 does not claim or reconstruct numerical `SWKMEAN=7` results.

This option is nevertheless scientifically relevant because it confirms that SWAP itself already recognised endpoint conductivity averaging as a material numerical choice and carried a more elaborate Darcian-mean route.

## 11. Consequences for LayeredMFP design

### Do not replace MFP by arithmetic K merely to match FullRichards SWKMEAN=1

That would make the reduced-order model reproduce one particular coarse Richards discretisation rather than establish its own physically qualified closure.

### Keep MFP as the current candidate for homogeneous layers

The smooth-profile refinement evidence shows that its flux approaches the same local continuum flux as arithmetic-`K` when spatial resolution increases. The MFP form has the additional attraction that it integrates the nonlinear conductivity curve over a coarse head interval instead of sampling only the endpoints.

This remains a hypothesis of improved coarse-grid behaviour, not yet a general qualification claim.

### Treat material interfaces separately

The equal-flux MFP interface and arithmetic `SWKMEAN=1` have different limiting laws. A material-boundary qualification must therefore use an independent physical/interface reference rather than require equality to coarse `SWKMEAN=1`.

### Solver selection remains separate from execution policy

Nothing in F-LMFP05 changes invariant 23. LayeredMFP remains an explicitly selected soil-water model. A numerical performance policy may not switch to it silently.

## 12. Performance implications

F-LMFP05 still does not establish a wall-clock speedup.

It does strengthen the bounded-work argument:

- homogeneous MFP faces require no nonlinear interface iteration;
- all 1,296 sweep cases solved;
- heterogeneous interface work stayed at or below 47 scalar bisection iterations in the final sweep;
- no column-global Jacobian or linear system is part of the LayeredMFP face calculation.

Direct adaptive quadrature used in the F-LMFP05 limit probe is an oracle and is intentionally too expensive for production. F-LMFP02 already showed that shared immutable MFP tables can remove runtime quadrature. Table accuracy and resolution remain a separate qualification item.

## 13. Architecture invariant check

F-LMFP05 changes no production source and therefore does not alter the common kernel, I/O boundary or admitted FullRichards route.

Relevant invariants:

- **1, 20:** LayeredMFP remains an alternative solver behind the common soil-water concept, not a separate SWAP product.
- **2, 3:** no file or parsing semantics enter the candidate solver design.
- **4, 5, 6, 16, 27:** the evidence remains compatible with compact per-column state and shared hydraulic/MFP data; runtime quadrature is not proposed.
- **7, 8:** no change to transaction ownership; rejected trials remain non-committing.
- **9:** no daily time assumption is introduced.
- **13:** mass conservation remains a hard gate.
- **21, 22:** common SWAP constitutive hydraulics remain the intended source; no other process should depend on HeadCalc internals.
- **23:** physical solver choice remains separate from execution policy.
- **24:** bounded local face work is supported, but difficult-column/retry qualification remains open.
- **25:** FullRichards remains the reference model, while F-LMFP05 explicitly distinguishes reference physics from a particular coarse face discretisation.
- **26:** retries and failed diagnostic probes are retained rather than hidden.
- **29:** no calendar or file-format assumption is introduced.
- **30:** the material face law is now explicitly identified as an architecture/science decision requiring its own qualification.

Coupling invariants 11, 12, 14, 15, 18 and 28 remain outside this workunit. No MODFLOW or prescribed-bottom-head claim is made.

## 14. Decision

**Decision: `QUALIFIED_FACE_CLOSURE_ATTRIBUTION_READY_FOR_INTERFACE_PHYSICS_QUALIFICATION`.**

F-LMFP05 answers the immediate F-LMFP04 question:

- the same-grid redistribution offset is caused principally by the different face conductivity closure;
- for smooth homogeneous material this difference converges away under spatial refinement;
- for a material discontinuity it does not converge away because the two methods embody different interface transmissibilities;
- the MFP equal-flux limit has a direct harmonic series-resistance interpretation;
- current `SWKMEAN=1` FullRichards therefore cannot by itself serve as the final physical oracle for that material-interface choice.

No production or application-envelope admission follows.

## 15. Recommended next workunit

**F-LMFP06 — Heterogeneous Interface Physics & Darcian-Mean Reference**

Minimum scope:

1. reconstruct the scientific basis of the Szymkiewicz/Warrick Darcian conductivity mean from primary sources and determine how the SWAP `SWKMEAN=7` tables were generated;
2. locate or reconstruct the missing `Kavg_Szymkiewicz_*.unf` generation path if provenance and licensing allow it;
3. build independent two-material interface benchmarks with analytically controlled piecewise-constant conductivity and nonlinear SWAP constitutive functions;
4. compare arithmetic, harmonic/equal-resistance, MFP equal-flux and, if reproducible, Szymkiewicz/Darcian means;
5. establish spatial convergence against an interface-consistent Richards weak-solution benchmark rather than against a single coarse `SWKMEAN=1` grid;
6. determine whether LayeredMFP should retain its current heterogeneous interface solve, modify it, or expose a qualified interface closure choice;
7. preserve exact mass conservation and bounded local cost as hard gates;
8. make no production integration, process coupling or application-envelope claim until this material-interface question is resolved.

Only after F-LMFP06 should the workstream broaden to strong wetting fronts, ponding, evaporation/root uptake, drainage, groundwater, MODFLOW response and production performance qualification.
