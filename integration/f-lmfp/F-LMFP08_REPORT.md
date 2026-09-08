# F-LMFP08 — Physics-Informed Darcian Correction Representation

## Decision

**QUALIFIED_CONSTRAINED_CONTINUOUS_MFP_DARCIAN_RATIO_REPRESENTATION**

This is an experimental hydraulic qualification only. It does **not** admit a production LayeredMFP solver, response tangent, groundwater coupling, MODFLOW coupling, crop/root uptake, drainage, ponding, or a broader applicability envelope.

## Scope

F-LMFP08 started from the F-LMFP07 finding that a steady Darcian homogeneous-face signal materially improves strong-gradient transient behaviour, but that a direct absolute lookup was not an adequate final representation.

The workunit therefore tested bounded-cost representations around the existing MFP homogeneous-face closure while preserving:

- exact equal-head gravity flow;
- exact hydrostatic zero flux;
- flow direction implied by the total hydraulic gradient;
- conservative transient storage updates;
- fail-closed lookup coverage;
- immutable/shared lookup ownership;
- explicit LayeredMFP model selection rather than numerical-policy switching.

Heterogeneous interfaces remained on the existing MFP equal-flux closure and are not newly qualified here.

## Candidate sequence and negative evidence

The candidate sequence was intentionally retained rather than rewritten away.

1. **Factored residual correction**
   - preserved the nominal identities and improved face-oracle statistics;
   - improved only 3 of 5 strong-gradient transients;
   - rejected.

2. **Constrained direct Delta-q**
   - stored `Delta q = q_Darcy - q_MFP` with zero residual enforced at `g=0` and `g=1`;
   - introduced a local face overshoot/sign problem;
   - improved only 3 of 5 strong-gradient transients;
   - decisive run: `34269295714`, conclusion `FAILURE`;
   - rejected.

3. **Positive log(K_DAR)**
   - represented `q=(1-g) exp(interp(log K_DAR))`;
   - guaranteed positive conductance and gradient-consistent direction;
   - improved face-oracle accuracy but only 4 of 5 strong-gradient transients;
   - decisive run: `34269953671`, conclusion `FAILURE`;
   - rejected.

4. **First multiplicative MFP log-ratio**
   - represented a positive multiplicative correction around the MFP face closure;
   - passed the then-existing gate, run `34269295636`;
   - manual evidence review exposed a point discontinuity at the exact equal-head manifold because the tabulated MFP secant limit and the separate exact `K(h)` branch were not numerically identical;
   - this green run was therefore **not accepted as final qualification**.

5. **Upstream-K normalized Darcian ratio**
   - represented `q=(1-g) K(h_upper) exp(R)`;
   - removed the equal-head discontinuity and passed the new refinement-style continuity check;
   - lost useful MFP structure in the downward clay stress case and improved only 4 of 5 strong-gradient transients;
   - decisive run: `34270377026`, conclusion `FAILURE`;
   - rejected.

6. **Constrained continuous MFP log-Darcian ratio**
   - retains the MFP secant structure away from the equal-head manifold;
   - analytically reconciles only the `g=0` interpolation-row contribution so the equal-head limit equals constitutive `K(h)`;
   - retains the multiplicative positive Darcian correction;
   - passed all strengthened gates;
   - admitted as the F-LMFP08 experimental representation.

## Qualified representation

For a homogeneous unsaturated face within the tested lookup envelope:

```text
q = q_MFPtable_continuous * exp(R_constrained)
```

with raw correction

```text
R = log(K_DAR / K_MFPtable_secant)
```

and the `g=0` cardinal-row contribution reconciled analytically to

```text
log(K_exact / K_MFPtable_limit).
```

Here

```text
g = (h_lower - h_upper) / face_distance.
```

Consequences within the tested representation:

- `g=0`: `q=K(h_upper)` to roundoff;
- `g=1`: `q=0` exactly through the `(1-g)` structure of the continuous MFP baseline;
- effective homogeneous-face conductance remains positive;
- no runtime extrapolation is allowed;
- coverage miss is an explicit failure;
- lookup data are immutable shared hydraulic parameter data, not persistent per-column state.

## Decisive evidence

Final CI run:

- workflow run: `34271007976`
- head: `4ecc84210f6af4cbc4528b8b4a23b8c63093fbd8`
- job: `102212291377`
- conclusion: `SUCCESS`
- artifact: `10073946916`
- artifact digest: `sha256:055c7b80a37043f29852bd75f2e45f0fb0a54edad6ed484e3a71c6c4615622ed`

### Exact identities

- maximum equal-head absolute error: `2.220446049250313e-16`
- maximum hydrostatic absolute flux: `0.0`

### Face-oracle matrix

Across 192 homogeneous face probes spanning two fixture materials and multiple geometry classes:

- coverage failures: `0`
- sign mismatches: `0`
- fraction where corrected face is closer to direct Darcian oracle than MFP: `0.9791666666666666`

Relative-error statistics:

| metric | MFP | corrected |
|---|---:|---:|
| median | 0.040418708748571494 | 0.0005582149424760037 |
| p90 | 0.3074619430431289 | 0.008187294249629357 |
| maximum | 0.9534946772479598 | 0.13516851986332382 |

For the 71 strong-gradient face probes:

| metric | MFP | corrected |
|---|---:|---:|
| median | 0.02074886622511033 | 0.00022366732091858748 |
| p90 | 0.3561958436069287 | 0.0017354638377739542 |
| maximum | 0.6287081587917802 | 0.10898099510314349 |

These are experimental fixture statistics, not an admitted production error envelope.

### Strengthened response-continuity check

The final representation was subjected to a refinement-style local continuity test around the exact physical manifolds rather than only comparing left and right probes.

- perturbation ratio: `0.2`
- maximum observed small/large deviation ratio: `0.2000326399282258`
- gate threshold: `0.35`
- finite: `true`
- result: `PASS`

This test was added because the earlier log-ratio candidate could pass the old response diagnostic while still containing a point discontinuity at `g=0`.

This result establishes continuity behaviour only for the tested finite-difference probes. It does **not** admit a production response tangent.

### Transient matrix

- all candidate steps accepted: `true`
- maximum mass residual: `4.322852975103056e-15 cm`
- strong-gradient cases closer to direct Darcian control than uncorrected MFP: `5 / 5`
- ordinary cases closer to direct Darcian control than uncorrected MFP: `5 / 6`
- transient lookup coverage misses: `0`

The five stress trajectories comprise upward and downward clay gradients and three strong-gradient sand cases. The final constrained-MFP representation retains the improvement in the downward clay case that was lost by the direct log(K_DAR) and upstream-K representations.

## Cost and memory evidence

For the present experimental table geometry:

- stored values per material/geometry class: `432`
- double-value storage per class before metadata: `3456 bytes`
- runtime homogeneous-face operation: bounded interpolation plus elementary arithmetic/exponential;
- table preparation remains outside the transient solve path and is classified as immutable template/material preparation work.

The evidence does **not** establish a production-optimal table density or geometry-class cardinality. In particular, a large number of unique face distances could multiply shared-table memory and preparation cost. That must be qualified separately.

## Important newly exposed issue

F-LMFP08 exposed a numerical inconsistency in the experimental MFP table representation itself: a near-equal-head MFP secant obtained from piecewise table interpolation need not converge numerically to the separately evaluated constitutive `K(h)` branch at the exact equal-head point.

The final homogeneous-face representation reconciles this manifold explicitly. This does **not** yet prove equivalent continuity for heterogeneous half-face MFP evaluations. Heterogeneous-interface continuity therefore remains an explicit next-stage qualification item.

## Applicability limits after F-LMFP08

The qualified evidence is restricted to the current experimental hydraulic fixtures and lookup envelope:

- upper unsaturated head lookup envelope: approximately `[-350, -1] cm`;
- gradient envelope: `[-28, 28]`;
- two fixture hydraulic materials;
- homogeneous-face Darcian correction only;
- existing heterogeneous MFP equal-flux closure retained;
- no saturated or positive-pressure-head lookup qualification;
- no broad dry-tail qualification;
- no production SWAP hydraulic-provider integration;
- no process sinks/sources beyond the existing hydraulic test harness;
- no groundwater or MODFLOW coupling;
- no interface tangent admission.

## Architecture invariant check

- **One kernel / alternative solver openness:** preserved. No production solver implementation was added.
- **Kernel/I/O separation:** preserved. Experimental lookup code has no legacy file-format contract.
- **Data separation:** lookup is immutable shared hydraulic parameter/template data.
- **Compact state:** no new persistent column state.
- **Scratch per worker:** no new persistent solver scratch.
- **Scalable layout:** O(1) face lookup is batch-compatible, but class cardinality is still open.
- **Transactional steps:** experimental transient trials do not mutate committed state on rejection.
- **Generic time:** preserved in the transient harness.
- **Mass conservation:** satisfied to roundoff in the tested trajectories.
- **Interface sensitivities:** explicitly not admitted yet.
- **MultiSWAP:** shared immutable tables are compatible with template batching; memory scaling still requires qualification.
- **Physics/policy separation:** LayeredMFP remains an explicitly configured physical solver choice; no performance policy silently switches solver.
- **Reference mode:** FullRichards and direct-Darcian controls remain reference evidence, not replaced production paths.
- **Diagnostics:** coverage, memory, table builds, mass, transient calls and interface iterations are recorded.

## Exit and next action

F-LMFP08 exits as:

**QUALIFIED_CONSTRAINED_CONTINUOUS_MFP_DARCIAN_RATIO_REPRESENTATION**

The next workunit should qualify the **hydraulic envelope and representation geometry**, before any broader process integration. At minimum it must cover:

1. near-saturation and positive pressure heads;
2. a substantially drier pressure-head tail;
3. a head-coordinate transformation that is regular through `h=0` rather than relying only on `log10(-h)`;
4. more material parameter sets;
5. more face lengths and explicit material/geometry-class cardinality;
6. heterogeneous-interface continuity and accuracy;
7. fail-closed behaviour at every envelope boundary;
8. preservation of mass, exact identities and the F-LMFP07/F-LMFP08 transient stress gates.

Only after that envelope is established should broader SWAP process physics or production-kernel admission be considered.
