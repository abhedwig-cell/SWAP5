# TOP03 explicit transition-layer equivalence preregistration

Date: 2026-10-02
Status: PREREGISTERED_RESEARCH_ONLY

## Authority and ownership

Workstream: VQ / SW-RIB-TOP03 explicit-layer prerequisite. Baseline: `99da94ef964052e96d1bf11d975acbb7856353a9`, existing branch `work/sw-rib-top03-transactional-top-exchange`, draft PR #956. Canonical inspected: `800f6a9b429ed2a392e4c3778951bb92eca042aa`.

Owning instruction: `TOP03_EXPLICIT_LAYER_PREREQUISITE.md`. Only test providers, geometry construction, analysis and evidence may change. Production solver, constitutive cutoff, BASE acceptance, mass ownership and receipt/commit semantics are held fixed. Invariants 3, 7, 13, 23, 25, 30 apply. No new branch, admission or default resistance.

Canonical has changed the solver contract, legacy binding and HeadCalc since the previous canonical observation. These are inspected dependency changes, not inherited qualification. This experiment qualifies only its pinned dedicated-branch postimage; current-canonical replay/integration remains required before admission. Shared changes concern typed bottom mode 3 and explicit macropore composition; this study activates neither. The dry main case retains bottom mode 7.

## Hypotheses and alternatives

H1: a storage-free resistance can approximate an explicit saturated thin layer over a bounded envelope. H2: initially dry layer storage materially affects onset and the same saturated resistance is insufficient. A stable reduced model is not evidence that a real surface resistance was previously missing; resistance also slows forcing and may conceal unresolved numerical behavior.

## Matched geometry, head and storage

The underlying 3 cm soil occupies z=[-3,0] cm, with the original parent thicknesses [0.5,0.5,1,1] cm. Each parent cell is split into m=[1,2,4,8] equal cells; centers, thicknesses and face distances are calculated from edges. Local layer refinement uses 2m cells.

An explicit layer occupies z=[0,L] cm. L=[0.02,0.20] cm, R=[0.05,0.50,1.00] day and K_layer=L/R cm/day. Its retention parameters equal the underlying synthetic MvG soil, except Ksat. These are controlled synthetic decompositions, not measured crusts. The underlying soil parameters, initial pressure and lower face are identical between models.

The external stage H is measured above the physical layer top z=L. The reduced comparator removes layer nodes but retains physical water elevation H+L. With soil first-node distance d, its signed upward-positive flux is

```
q_top = -(H + L - h_1 + d) / (R + d/K_face)
```

Pond depth remains H, not H+L. Thus gravity across L is retained and fictitious pond storage is not introduced. The reduced element has no layer storage. An explicit dry layer has its actual storage; that difference must be reported, not removed to make external exchange agree. Compare both total surface-to-profile transfer and transfer entering the underlying soil (explicit top input minus layer storage change).

Primary matched comparisons use distance-weighted harmonic face conductance (legacy HCOMEAN method 6 via the existing FVQ89 test-only reference materializer). This is the physical series-resistance oracle for heterogeneous layers, not a production solver change. Arithmetic method 1 controls are also retained to diagnose finite-grid interface bias. A homogeneous no-layer R=0 control uses the original law. The previous microrelief/contact probe must be replayed unchanged.

## Forcing and origins

Dry main profiles: all initial pressure heads -123 cm, zero initial ponding, original underlying soil and free-drainage bottom mode 7. Additional prewetted-layer cases set only explicit layer pressure to zero, keeping the underlying soil -123 cm; this is a separately labeled origin, never a substitution for the dry case.

For each origin, use the prior six stages [0.005,0.02,0.05,0.1,0.2,0.3] cm, each lasting 0.03125 day. Time subdivision is event-aligned n=[8,16,32,64] per event. Also record the first event separately to identify storage effects before the column approaches saturation. No adaptive retries, tolerance tuning, K-shortcut removal or lower-boundary substitution in these comparisons. Failed trajectories are explicit results and never provide a refinement oracle.

## Independent controls and budgets fixed before execution

1. Geometry asserts complete layer/base thickness, positive distances and correct centers. Reduced R=0 and L=0 is exactly the previous provider on identical geometry.
2. Analytical saturated layered Darcy control: H=10 cm, bottom-face head=10 cm, bottom mode 5, q=-(H+L+3-10)/(R+3/4.75). Initialize the exact piecewise-linear total-head solution. Compare q, head and mass at every geometry. Harmonic controls must agree within 1e-10 cm/day for flux, 1e-9 cm for head and 1e-10 cm for mass. Arithmetic controls diagnose approximation and do not determine physical admission.
3. Accepted solver and independently reconstructed whole-column mass residual <=1e-10 cm. Failed candidates must leave the request origin byte-identical. Negative/unsupported resistance is fail closed.
4. Compare common parent-cell mean theta and pressure sampled at parent centers; never compare unlike node arrays directly. Report eventwise cumulative top input, bottom output, base storage, layer storage and pond storage.
5. Numerical-reference readiness requires complete finest three temporal and spatial trajectories and shrinking non-negligible differences, separately for top, bottom and underlying-water L1. Finest pair discrepancies must fit 0.001 cm + 0.5% of the relevant transfer; pressure differences <=0.1 cm. Differences <=1e-10 cm are roundoff plateaus.
6. Reduced/explicit physical comparison at each event: top, bottom and underlying-interface transfer error <=0.005 cm + 2% of explicit magnitude; parent water L1 <=0.005 cm; parent pressure max <=0.5 cm. Numerical uncertainty must be smaller than this budget. Test both L/K decompositions of each R. Report onset and full trajectory separately. The budgets are bounded research criteria, not global production tolerances.
7. Build O0/O2 with GNU Fortran 13.3.0, f2008, all runtime checks and invalid/zero/overflow traps. Preserve raw records for both builds; compare output exactly. Use local execution. No Actions is required for this physical prerequisite.

## Decision and recovery

Require numerical-reference readiness before physical equivalence. Failure of either model to converge is a numerical prerequisite blocker, not proof against the physical hypothesis. A converged mismatch falsifies the storage-free reduction in that declared scope. Saturated agreement alone does not qualify dry onset. A possible resistance-plus-storage model is a next hypothesis requiring a separate preregistration, not an automatic production repair.

Persist this contract and executable test postimage before the factorial run. Persist raw evidence, source hashes, deterministic analysis, decision and `SW-RIB-TOP03_STATUS.json` afterward. PR #956 stays draft and TOP03 production qualification false until its separate temporal and complete receipt/commit contracts pass.
