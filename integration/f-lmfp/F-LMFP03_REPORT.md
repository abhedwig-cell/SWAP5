# F-LMFP03 — Conservative Generic-Time Column Advance Prototype

**Workunit:** F-LMFP03  
**Branch:** `work/f-lmfp03-generic-time-column`  
**Base:** F-LMFP02 at `4674b2315dff9f783d1fcb72899b5a459775e1ef`  
**Scope:** standalone experimental prototype only  
**Production admission:** none

## 1. Finding

F-LMFP03 provides enough structural and numerical evidence to continue LayeredMFP into direct hydraulic A/B qualification against FullRichards.

The workunit does **not** show that LayeredMFP is physically equivalent to Richards. It shows that a complete reduced-order column trial can be formulated with:

- explicit generic `step_duration`;
- conservative layer storage;
- shared SWAP/B1.10-aligned hydraulic relations;
- MFP-based local face fluxes;
- a bounded scalar solve only at heterogeneous interfaces;
- unit-gradient free drainage;
- external source and sink vectors;
- retry rather than post-update clipping when a trial exceeds constitutive storage bounds;
- no mutation of the committed/base state by a rejected trial.

The material change relative to WOFOST is the face-flux closure. The historical `max(dry flow, wet flow)` rule is not admitted as the SWAP5 candidate formulation.

## 2. Why the WOFOST `max(dry, wet)` closure is not retained

F-LMFP02 had already classified the historical dry/wet maximum as lineage behavior rather than qualified SWAP5 physics. F-LMFP03 gives a stronger reason.

For downward coordinate `x`, the Darcy flux can be written as

`q = K(h) [1 - dh/dx]`.

With matric flux potential

`Phi(h) = integral K(h) dh`,

the matric component over a finite segment is naturally represented by a difference in `Phi`.

For a homogeneous hydrostatic segment, `h_lower - h_upper` equals the vertical center distance. Darcy therefore requires zero flux. In the reconstructed test case with center distance 20 and heads `-30` and `-10`, the historical-style components were approximately:

- dry MFP flow: `-2.8522`;
- wet gravity flow: `+1.1921`;
- historical `max(dry,wet)`: `+1.1921`.

The expected hydrostatic flux is zero.

This is not evidence that all historical WATFDGW simulations are physically wrong; its additional flow gates and daily storage logic modify the final transfers. It is evidence that `max(dry,wet)` is not a generally valid local Darcy face law suitable for SWAP5.

## 3. Candidate MFP-secant Darcy closure

For one material segment of length `L`, with upper/downstream-coordinate start head `h_a` and lower end head `h_b`, define

`K_sec = [Phi(h_a) - Phi(h_b)] / [h_a - h_b]`

when `h_a != h_b`, with `K(h)` used in the coincident-head limit.

The candidate downward-positive face flux is

`q = K_sec + [Phi(h_a) - Phi(h_b)] / L`

or equivalently

`q = K_sec [1 - (h_b - h_a)/L]`.

This has useful exact finite-volume properties:

1. **gravity-only state:** if `h_a = h_b`, then `q = K`;
2. **hydrostatic state:** if `h_b - h_a = L`, then `q = 0`;
3. **dry suction gradients:** the MFP term remains well behaved as conductivity becomes small;
4. **no arbitrary dry/wet branch switch:** gravity and matric contributions are represented in one flux expression.

This is a reduced-order finite-volume Darcy closure. It is not a discrete reproduction of the current FullRichards equations and still requires physical qualification.

## 4. Heterogeneous interface

For different hydraulic materials above and below a face, MFP itself is material-dependent and cannot simply be differenced across the interface.

F-LMFP03 therefore solves one scalar interface head `h_I` such that

`q_upper(h_upper, h_I) = q_lower(h_I, h_lower)`.

The same full MFP-secant Darcy expression is used in both half layers. Pressure head is continuous and the water flux is equal on both sides.

This is a direct evolution of the most useful WATFDGW idea: local equal-flux resolution at a material discontinuity, but applied to the full Darcy face flux instead of to a dry-flow branch alone.

In the deterministic test matrix:

- 500 random heterogeneous face cases were attempted;
- no bracket/solve failures occurred;
- maximum bisection count was 42;
- mean count was 35.788;
- no column-wide nonlinear iteration exists.

The current bisection tolerance is intentionally strict for feasibility testing. Forty scalar table-lookup iterations per heterogeneous face may still be more work than desirable for MultiSWAP. Safeguarded secant/Newton or cached interface starts can be investigated later without changing the physical closure.

## 5. Hydrostatic preservation

Hydrostatic preservation is a useful discriminating property.

For homogeneous material the candidate expression gives zero algebraically when the head difference equals the center distance.

For a heterogeneous test with:

- upper head `-30`;
- lower head `-5`;
- upper half distance 10;
- lower half distance 15;

the hydrostatic interface head is `-20`.

The prototype found:

- interface head `-19.99999999996362`;
- flux `8.26e-12`;
- equal-half-flux residual about `2.4e-11`.

Thus the heterogeneous scalar construction preserves hydrostatic equilibrium to the test tolerance.

## 6. Column state and update

For layer `i` the persistent prototype state is water storage

`W_i = theta_i dz_i`.

Pressure head is reconstructed from the inverse hydraulic relation `h(theta)` for the trial.

The layer update is

`W_i^(n+1) = W_i^n + dt [q_(i-1/2) - q_(i+1/2) + S_i - U_i]`.

Every internal face appears once with a positive and once with a negative sign. The external mass ledger is therefore

`Delta W_total = dt [q_top - q_bottom + sum(S) - sum(U)]`.

In the accepted four-layer test the unrounded residual was about `6.9e-15`.

A separate randomized 200-column trial matrix gave:

- 179 accepted on the initial step;
- 21 deliberately/incidentally too-large trials;
- all 21 were accepted after retry with the advised smaller step;
- zero failures;
- maximum mass residual about `6.8e-15`.

Mass conservation is therefore a structural consequence of the face ledger, not a calibration tolerance.

## 7. Trial rejection instead of clipping

The prototype never clips a post-update water content to residual or saturated water content.

If the explicit trial would leave the constitutive storage interval, it returns:

- `accepted = false`;
- the unchanged base storage as candidate storage;
- the trial face fluxes and rates for diagnostics;
- a conservative advised smaller `step_duration` based on the frozen trial rates.

A stress test with a deliberately excessive top flux rejected a one-unit step and advised approximately `3.48e-5`. Re-running from the same base state at the advised step succeeded with a mass residual about `5.0e-15`.

Repeating the rejected trial produced identical reason, face fluxes and advised step.

This is compatible with SWAP5 transaction ownership:

`checkpoint -> trial -> retry or accept -> runtime commit/discard`.

LayeredMFP itself need not own `commit()` or `rollback()`.

## 8. Generic time

No day, date or calendar concept occurs in the candidate column update. `step_duration` is an explicit scalar duration.

A smooth nonstationary forcing test over duration 0.2 was repeated with 20, 40, 80, 160 and 320 steps and compared to a 2560-step reference.

The L1 endpoint errors were approximately:

- 20: `1.6408e-2`;
- 40: `8.3259e-3`;
- 80: `4.1091e-3`;
- 160: `2.0009e-3`;
- 320: `9.3997e-4`.

Successive error ratios were about 1.97, 2.03, 2.05 and 2.13. This is consistent with the expected first-order behavior of the explicit state update in this test.

This result establishes generic-time numerical coherence, not an acceptable production time-step envelope. Wet/high-conductivity columns may require short steps and are a key performance risk to qualify against FullRichards.

## 9. Lower boundary

F-LMFP03 uses only unit-gradient free drainage:

`q_bottom = K(h_bottom)`.

No field-capacity gate is applied.

Prescribed bottom head, shallow groundwater, deep-vadose transfer and MODFLOW response tangents remain outside this workunit. They should not be added until the basic hydraulic A/B comparison shows that the reduced-order column physics is worth extending.

## 10. Source and sink ownership

Sources and sinks enter as explicit per-layer rates. F-LMFP03 does not implement crop, drainage or evaporation physics internally.

This is intentional. A future LayeredMFP solver should consume the same solver-neutral process outputs as FullRichards wherever possible. The soil solver should not acquire a second crop, ET or drainage model.

Root uptake is therefore represented here only as an external sink vector.

## 11. Constitutive-interface gap found in SWAP5

The current SWAP5 `constitutive_hydraulics_provider_t` evaluates, from pressure head:

- water content;
- conductivity;
- capacity;
- `dK/dh` placeholder/output.

LayeredMFP additionally needs solver-neutral access to:

- `h(theta)`;
- `Phi(h)` or an equivalent shared MFP material service.

SWAP 4.3.1 already contains the inverse `prhead` and the forward hydraulic functions, so this is not a missing physical model. It is an interface capability gap.

F-LMFP03 does **not** modify the production contract. The appropriate extension should be designed only after the hydraulic A/B tests confirm that LayeredMFP remains viable.

## 12. State and scratch implications

The prototype supports the intended memory split.

Persistent per-column candidate state can in principle be only:

- one conserved water amount or water content per active layer;
- any genuinely history-dependent process state owned by other modules, not by LayeredMFP.

Reconstructable quantities are scratch:

- pressure head;
- MFP;
- conductivity;
- face fluxes;
- interface-head brackets;
- scalar iteration diagnostics.

MFP tables are immutable per hydraulic material and should be shared by ID/reference across columns.

This is favorable for SoA/batched layouts and avoids one heavy Newton/Jacobian workspace per logical column.

## 13. Performance interpretation

The structural cost is approximately:

- O(number of layers) constitutive/inverse evaluations;
- O(number of faces) flux evaluations;
- zero global Jacobian builds;
- zero global linear solves;
- bounded scalar work on heterogeneous interfaces.

This is promising for predictable runtime but not yet a demonstrated speedup.

Open performance risks are:

1. repeated `h(theta)` inversion if the production constitutive provider does not expose an efficient inverse;
2. 30-40 bisection iterations on strongly heterogeneous faces with the deliberately strict current tolerance;
3. explicit-step rejection in wet/high-K regimes;
4. table interpolation resolution needed for hydraulic accuracy;
5. branch divergence when different material interfaces require different local iteration counts.

These must be measured, not assumed away.

## 14. Architecture-invariant check

F-LMFP03 is consistent with the relevant invariants within its experimental scope:

- **1, 20:** it remains an alternative solver candidate behind the common soil-water concept, not a separate SWAP fork;
- **2:** no production I/O is introduced;
- **3:** state, forcing/source-sink data, immutable material data and diagnostics are semantically separate;
- **4:** persistent soil state can remain layer storage only;
- **5:** heads, faces and root-search data are scratch;
- **6, 16:** immutable material tables and local face operations are batchable;
- **7, 8:** trial is non-mutating on rejection and deterministic retry from the same base state is supported;
- **9:** time is an arbitrary duration, not a day;
- **11, 12, 14:** no coupling admission is claimed yet, but the design leaves bottom response explicit;
- **13:** accepted-trial mass balance closes structurally;
- **15:** no multi-run coupling algorithm is introduced;
- **18:** deep vadose remains external;
- **21:** the candidate is built around shared SWAP hydraulic relations rather than duplicate soil physics;
- **22:** other processes need only solver-neutral hydraulic views and source/sink contracts;
- **23:** LayeredMFP remains a selected soil-water model, never an execution-policy fallback;
- **24:** local solve cost is bounded, while step-retry cost remains to be qualified;
- **25:** FullRichards remains the scientific reference;
- **26:** rejection reason, face iteration cost and mass residual are explicit diagnostics;
- **27:** MFP-specific tables/work are only needed for LayeredMFP users;
- **28:** no tile or MODFLOW composition enters the solver;
- **29:** there is no hidden daily/calendar/file assumption;
- **30:** this report records the architectural consequences before production changes.

## 15. Qualification boundary

F-LMFP03 qualifies only the following proposition:

> A complete, mass-conservative, generic-time LayeredMFP column trial with bounded local heterogeneous-interface solving is technically coherent enough to compare directly against FullRichards.

It does **not** qualify:

- infiltration-front accuracy;
- evaporation coupling;
- crop/root stress response;
- drainage physics;
- ponding/runoff;
- shallow groundwater;
- prescribed bottom head;
- MODFLOW coupling;
- B12/heavy-clay behavior;
- all SWAP hydraulic model families;
- a production MFP table;
- runtime speedup;
- a final application envelope.

## 16. Recommended next workunit

Proceed to **F-LMFP04 — FullRichards Hydraulic A/B Qualification I**.

Keep it standalone and restricted to hydraulic cases for which F-LMFP03 already has explicit semantics:

1. no-flow/hydrostatic internal-face tests;
2. free drainage;
3. redistribution after wetting;
4. moderate prescribed top infiltration without ponding;
5. homogeneous sand;
6. homogeneous clay;
7. sand-over-clay;
8. clay-over-sand;
9. strong conductivity contrast;
10. time-step refinement.

Compare full profiles and flux histories, not only final storage. The initial outputs should include `theta(z,t)`, reconstructed `h(z,t)`, all face fluxes, bottom flux, storage and full mass balance.

Do not add root uptake, drainage, ponding or groundwater to LayeredMFP merely to make the first A/B matrix broad. First determine where the hydraulic core itself agrees or disagrees with FullRichards.
