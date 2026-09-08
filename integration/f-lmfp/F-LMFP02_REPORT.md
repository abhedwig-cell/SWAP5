# F-LMFP02 — Standalone Lineage Reconstruction & Constitutive Testbench

**Workunit:** F-LMFP02  
**Branch:** `work/f-lmfp02-lineage-testbench`  
**Basis:** F-LMFP01 `GO_PROTOTYPE` at `6672f4ac10d7ddd79fbe6b0b1080b45b6467b09f`  
**Scope:** standalone experiment only, no production solver registration, no FullRichards qualification

## 1. Result

The reduced-order MFP primitives are sufficiently reproducible and numerically well behaved to continue to a conservative multi-layer column prototype.

The workunit therefore exits as:

`QUALIFIED_STANDALONE_MFP_PRIMITIVES_READY_FOR_COLUMN_PROTOTYPE`

This qualification applies only to the standalone testbench and the reconstructed primitives. It does **not** mean that LayeredMFP is physically qualified against FullRichards, admitted into the SWAP5 kernel, qualified for groundwater coupling, or assigned a production application envelope.

The strongest new findings are:

1. the homogeneous MFP face law and the heterogeneous equal-head/equal-flux construction can be reconstructed cleanly using SWAP-style constitutive hydraulics;
2. exact face bookkeeping closes mass at floating-point precision in the standalone storage update;
3. the historical `UpwardFlowLimit = 0.50` is demonstrably step-count dependent and therefore cannot be imported unchanged into generic `[t0,t1]` semantics;
4. direct numerical integration of `K(h)` is a useful oracle but much too expensive for the runtime path;
5. a shared immutable MFP table removes runtime quadrature and gives small face-flux error on the initial synthetic test matrix;
6. the current PCSE source contains an unresolved inverse-hydraulics naming/usage inconsistency in the heterogeneous equal-potential loop that must not be copied blindly.

## 2. Source-bound lineage reconstruction

The current PCSE `WaterBalanceLayered` implementation at repository commit `67a28e56b0e34655f8d60b0b4a254a7c81efbb2f` confirms the WATFDGW lineage behavior used in F-LMFP01:

- `delt = 1.0` in the water-balance rate calculation;
- per-layer pF, conductivity and MFP are reconstructed from layer hydraulic functions;
- homogeneous dry flow is
  `2 * (MFP_upper - MFP_lower) / (dz_upper + dz_lower)`;
- wet downward flow is the thickness-weighted harmonic conductivity;
- heterogeneous dry flow searches an interface pF by bisection until upper-half and lower-half flux agree;
- `MaxFlowIter = 50` and `TinyFlow = 0.001` are the historical/local iteration controls;
- upward flow is limited by an equal-potential transfer amount and `UpwardFlowLimit = 0.50`;
- free-drainage flow contains field-capacity gating;
- the current Python implementation still raises `NotImplementedError` for groundwater influence.

Primary lineage reference remains Rappoldt et al. (2012), *Extension of the WOFOST soil water submodel; Comparison with SWAP and technical documentation*, including Appendix C `WATFDGW`.

## 3. New source discrepancy: inverse hydraulic lookup

A material discrepancy was identified in the current PCSE implementation.

`pcse/soil/soil_profile.py` defines:

- `SMfromPF` as soil moisture as a function of pF;
- `PFfromSM` as the explicitly constructed inverse table.

However, in the heterogeneous equal-potential iteration in `multilayer_waterbalance.py`, the code evaluates:

`PF1 = self.soil_profile[il1].SMfromPF(SM1)`

and equivalently for layer 2.

Semantically, the iteration requires pF/head from water content, so the independently named inverse `PFfromSM` appears to be the relevant operation. The historical Fortran text also uses a table named `SMfromPF` in this location, but its table layout/naming lineage is not sufficient evidence that the current Python call is semantically correct.

F-LMFP02 therefore does not reproduce this call literally. The prototype computes equal-potential transfer through an explicit and tested inverse `h(theta)`. This discrepancy remains open for provenance reconciliation and should be reported upstream separately if the PCSE maintainers confirm the interpretation.

## 4. SWAP hydraulic basis

The supplied SWAP 4.3.1 source was re-inspected. Relevant file hashes are:

- `MOD_MvG_functions.f90`: SHA-256 `a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390`;
- `headcalc.f90`: SHA-256 `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`;
- `boundbottom.f90`: SHA-256 `5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`.

`MOD_MvG_functions.f90` exposes the expected constitutive operations:

- `watcon` at source line 244;
- `moiscap` at 371;
- `hconduc` at 500;
- `dhconduc` at 690;
- `prhead` at 771.

The standalone testbench uses an equation-aligned reconstruction of the currently qualified F-SI09 B1.10 default MvG parameter shape and the same synthetic parameter fixture used by the F-SI09 fingerprint harness. This is deliberate reuse of the constitutive model shape, but F-LMFP02 does **not** claim a new bitwise identity test between the Python prototype and the Fortran provider. F-SI09 already owns the qualification of its production constitutive provider against the corrected B1.10 oracle.

## 5. Standalone mathematical primitives

### 5.1 Matric flux potential oracle

The testbench uses

`Phi(h_a) - Phi(h_b) = integral[h_b,h_a] K(h) dh`

with deterministic adaptive Simpson integration. This is intentionally an expensive reference calculation, not the proposed runtime implementation.

A numerical derivative test verifies `dPhi/dh = K(h)`.

### 5.2 Homogeneous face

For equal materials:

`q_dry = 2 * (Phi_u - Phi_l) / (dz_u + dz_l)`.

The testbench also splits the same face into two half-layers, solves for a continuous interface head and verifies that the resulting equal-flux solution reproduces the direct homogeneous expression.

### 5.3 Heterogeneous face

For different hydraulic materials an interface head `h_i` is found such that

`q_u = [Phi_u(h_u) - Phi_u(h_i)] / (dz_u/2)`

and

`q_l = [Phi_l(h_i) - Phi_l(h_l)] / (dz_l/2)`

satisfy `q_u = q_l`.

The solve is bracketed between the two cell-center heads and bounded to at most 50 scalar iterations. Failure to bracket is a hard error in the prototype, not an invitation to silently substitute another flux law.

### 5.4 Equal-potential transfer amount

For a transfer amount `x`, positive downward,

`theta_u(x) = (W_u - x)/dz_u`

`theta_l(x) = (W_l + x)/dz_l`.

The equal-potential amount solves

`h_u(theta_u(x)) = h_l(theta_l(x))`

inside storage bounds defined by residual and saturated water contents.

This makes the inverse hydraulic operation explicit and avoids dependence on the ambiguous `SMfromPF(SM)` call noted above.

### 5.5 Conservative layer update

For downward-positive face fluxes:

`W_i(t1) = W_i(t0) + dt * [q_(i-1/2) - q_(i+1/2) + S_i - U_i]`.

Every internal face is booked once with opposite sign in its two adjacent layers. This is the required basis for invariant 13. Post-update clipping is not part of the prototype.

## 6. Test evidence

The standalone test was executed locally with Python 3 and no external numerical package. Two consecutive runs produced byte-identical JSON output with SHA-256:

`757c9ce179a6057e8b8d06303d8d2808bb91ee160259b6d36e665fe0e7ae5402`

The persisted evidence is `experiments/lmfp/F-LMFP02_TESTBENCH_EVIDENCE.json`.

Key results:

| Check | Result |
|---|---:|
| `theta -> h(theta)` reconstruction | max absolute head error `8.63e-9` |
| `dPhi/dh = K` | max relative error `2.05e-10` |
| homogeneous direct vs split face | flux difference `3.86e-10` |
| heterogeneous equal-flux residual | `7.97e-9` |
| heterogeneous example iterations | `26` |
| 20-case local iteration matrix | max `34`, bound `50` |
| equal-potential final head residual | `5.55e-8` |
| conservative storage mass residual | `1.67e-16` |
| 513-point MFP table, 28 face cases | max relative flux error `1.57e-4` |
| 513-point MFP table | max absolute flux error `8.02e-4` |
| table runtime numerical quadrature | `0` evaluations per lookup |

These are numerical reconstruction tests on synthetic constitutive cases. They are not physical acceptance thresholds for SWAP5.

## 7. Generic-time result: fixed 0.50 upward limiter fails subdivision invariance

This is the strongest qualification finding in F-LMFP02.

For one deliberately upward-flowing two-layer state, the equal-potential transfer is negative. Applying the historical 50% limiter once gives total transfer:

`-0.8452544146789454`

Applying the same 50% rule twice after subdividing the nominal interval gives:

`-1.2678816220184181`.

The difference is:

`-0.4226272073394728`.

Therefore the historical rule is not invariant to the number of solver steps. It is a per-step stabilization/relaxation closure tied to the historical time discretization, not generic physical law.

F-LMFP02 also demonstrates a purely mathematical alternative of the form

`f(dt) = 1 - exp(-dt/tau)`

with `tau = 1/ln(2)` days chosen only so that `f(1 day)=0.5`. One 1-day application and two 0.5-day applications then compose exactly in the test case. This demonstrates how a relaxation factor can be made time-composable. It does **not** qualify that exponential law, nor does it establish that `tau` has a physical interpretation. The preferred SWAP5 closure may instead be a flux/stability limit derived from the governing approximation.

## 8. MFP table result and performance shape

The direct integration oracle required `10562` constitutive evaluations for one tight-tolerance heterogeneous face example. That is unacceptable as a production runtime mechanism.

A candidate shared immutable table was therefore tested. It contains 513 pF locations over prototype range `[-4,6]`, with `Phi` precomputed from the same `K(h)` relation. On the 28-case table test:

- maximum relative face-flux error versus the integration oracle was `1.5717e-4`;
- maximum absolute error was `8.0166e-4` in the test flux units;
- maximum interface solve count was `35`;
- runtime MFP lookup performs no `K(h)` quadrature;
- storing pF and Phi as two double arrays costs about `8208 bytes` per hydraulic material at this provisional resolution.

The table is shared material data, not column state. If the pF grid is common across materials, even the pF coordinate array can be shared globally, reducing material-specific storage further.

The numerical values above only establish feasibility of pretabulation. They do not select 513 points, linear pF interpolation or the prototype pF envelope as production choices. Those must be qualified across all admitted SWAP hydraulic models, especially near air-entry features and other constitutive discontinuities/non-smooth points.

## 9. Cost and batching implications

The reduced-order runtime shape now looks credible:

- homogeneous face: constant-cost MFP lookups and arithmetic;
- heterogeneous face: bounded scalar root solve, each iteration requiring only material-table evaluations;
- wet-flow estimate: constant-cost conductivities and harmonic mean;
- equal-potential limiter when active: bounded scalar solve using `h(theta)`;
- no column-wide Jacobian assembly/factorization in these primitives;
- no permanent Newton vectors or Jacobian storage per column.

The test matrix needed 26 to 35 bisection iterations at the deliberately tight `1e-8` face-flux residual. Historical WATFDGW uses much looser `TinyFlow = 0.001`. Production tolerances are still open. A safeguarded secant/Brent-style local solve may reduce iterations while preserving a hard iteration bound, but this is an optimization hypothesis, not yet qualified.

For MultiSWAP, homogeneous execution classes should preferably group columns by layer topology and material-transition pattern. Material MFP tables can then be shared. Heterogeneous interfaces and active upward-limit branches still introduce branch divergence, but the divergence is local and bounded rather than driven by an unbounded global Newton history.

## 10. State and scratch implications

F-LMFP02 reinforces the F-LMFP01 state model.

Persistent soil-water state should be approximately:

- conserved water amount or water content per active layer;
- only genuinely physical additional state if later processes prove it necessary.

Derived quantities should not be persistent column state:

- head;
- conductivity;
- MFP;
- face candidate fluxes;
- interface-head brackets;
- equal-potential brackets;
- temporary source/sink vectors.

MFP tables belong to immutable hydraulic-material data and are shared by reference. Face arrays and local root-solve buffers belong to worker/job scratch.

## 11. What F-LMFP02 has not established

The following remain explicitly unqualified:

- full multi-layer transient column behavior;
- agreement with historical WATFDGW over complete daily runs;
- agreement with SWAP5 FullRichards;
- infiltration fronts, ponding and surface boundary switching;
- field-capacity gating as acceptable SWAP5 physics;
- a replacement for `max(dry,wet)`;
- root uptake and evaporation coupling;
- drainage coupling;
- groundwater and prescribed bottom head;
- bottom-flux response tangents;
- B12/heavy-clay behavior;
- macropore flow;
- all SWAP hydraulic model families;
- production MFP table resolution/interpolation;
- production solver tolerances;
- SIMD/GPU performance measurements;
- a physical interpretation for any time-dependent upward relaxation constant.

No production `src/` file is changed by F-LMFP02.

## 12. Invariant assessment

- **1, 20:** consistent with one kernel and alternative soil-water implementations behind the common solver boundary; no second SWAP fork is created.
- **2:** testbench is outside the kernel and adds no kernel I/O dependency.
- **3:** parameters, state, forcing/source-sink concepts and numerical controls remain semantically distinct.
- **4:** only layer storage is treated as candidate persistent soil state; MFP is derived/shared.
- **5:** face/root-solve temporaries are scratch.
- **6, 16:** shared tables and bounded local work are compatible with batching; actual SIMD qualification remains open.
- **7, 8:** prototype functions operate from supplied state to a candidate state and require no commit ownership; transaction integration remains F-KT/runtime work later.
- **9, 29:** the WOFOST 0.50-per-step dependency has been exposed rather than hidden. Generic-time reformulation remains a mandatory gate.
- **11, 12, 14, 15:** coupling interfaces and tangents remain design requirements but are not admitted by this primitive workunit.
- **13:** conservative face bookkeeping passes at floating-point precision in the standalone test.
- **18:** no attempt is made to absorb deep-vadose transfer into LayeredMFP.
- **21, 22:** same constitutive hydraulics are the target; no HeadCalc internals are exposed.
- **23:** LayeredMFP remains an explicitly selected soil-water model, never an execution-policy fallback.
- **24:** bounded local iterations are supported by the prototype; full-column cost bounds remain to be shown.
- **25:** FullRichards remains the physical reference for later qualification.
- **26:** iteration counts, residuals, mass residual and table error are explicit diagnostics.
- **27:** MFP table cost scales by active hydraulic material, not logical column.
- **28:** groundwater/deep-vadose composition stays outside the solver.
- **30:** the material findings above are explicitly recorded before any production integration.

## 13. Next workunit

The next workunit should **not yet** jump directly to a broad FullRichards A/B campaign. F-LMFP02 has only qualified primitives, not a complete reduced-order column advance.

Recommended next step:

### F-LMFP03 — Conservative Generic-Time Column Advance Prototype

Build a standalone multi-layer trial advance with:

1. arbitrary `dt` supplied explicitly;
2. conserved layer storage as the only core soil state;
3. explicit top flux input;
4. explicit layer source/sink vector;
5. initially free-drainage bottom flux only;
6. shared constitutive/MFP material providers;
7. bounded local face solves;
8. no post-update clipping without ledgered flux correction;
9. trial result plus mass ledger and diagnostics;
10. one-step versus substep consistency tests;
11. lineage closure and SWAP5-candidate closure kept separately selectable in the testbench;
12. no production registration.

Only after that column prototype passes mass and time-step gates should the workstream proceed to a FullRichards A/B qualification matrix.
