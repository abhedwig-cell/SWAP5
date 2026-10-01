# PPA-WU05-C3R — Bartholomeus oxygen-process reconstruction

Date: 2026-10-01

Status: `PREREGISTERED_RESEARCH / NO_PRODUCTION_MUTATION`

Canonical base: `integration/f-ci-canonical@2a0b23a2c4e547f6de2613884207d10b2fce462e`

## Question

Before porting the SWAP 4.3.1 `SWOXYGEN=2 / SWOXYGENTYPE=1` Bartholomeus route, determine whether its scientific contract can be represented in SWAP5 with materially simpler state and numerical machinery without changing the intended process model.

## Authority

- PPA-WU05-C admitted review authority.
- Corrected SWAP 4.3.1 B1.11 identities from that authority.
- SWAP-007 is mandatory numerical-reference behavior, not physical-model authority.
- Recovered S9/S11 oxygen cache evidence is corroborating architecture evidence.
- Bartholomeus et al. (2008), Journal of Hydrology 360, 147–165, DOI 10.1016/j.jhydrol.2008.07.029, is scientific intent authority.

## Initial reconstruction

The scientific model separates:
1. oxygen demand, including root respiration and microbial respiration;
2. macro-scale oxygen transport from atmosphere through soil gas;
3. micro-scale oxygen transport across the root-zone water film / root geometry;
4. reduction when oxygen supply cannot sustain potential root respiration.

The existing SWAP routine applies this per rooted node/layer and returns an oxygen reduction factor to root-water uptake. Oxygen remains a modifier, not a water-mass owner.

Recovered source-bound evidence shows six legacy arrays
`d_soil_term1`, `d_soil_term2`, `gfp100`, `capac_term`, `nmin1`, `mplus1`
are immutable-after-construction derived data. They must not become transactional per-column state in SWAP5.

## Hypotheses to falsify

H1. The complete Bartholomeus runtime can be expressed as a pure per-node response from current hydraulic state, temperature, root/crop geometry/configuration, and immutable soil precomputation, with no physical continuation state.

H2. The legacy Newton/restart machinery solves only an instantaneous scalar constitutive/root-oxygen balance and therefore does not require committed numerical state across timesteps.

H3. The scalar solve can be replaced by a bounded robust formulation or precomputed/interpolated response while preserving the B1.11 response surface to a separately declared tolerance.

H4. Most legacy cost is avoidable through immutable precomputation, removal of repeated hydraulic work, and a cleaner scalar solve; no relaxation of water-mass conservation is needed.

## Work plan

1. Reconstruct the exact B1.11 call graph and equations from the available pristine/cumulative source evidence.
2. Map each variable to immutable configuration, current external state, derived precomputation, call-local scratch, or true continuation state.
3. Reproduce the corrected B1.11 scalar response in an independent reference kernel.
4. Characterize solver difficulty and identify why Newton/restart is present.
5. Test three candidates against the kernel:
   - cleaned exact scalar solve;
   - bounded/bracketed solve;
   - response-table/interpolant only if monotonicity and error structure justify it.
6. Select the smallest implementation that preserves scientific intent and reference behavior.
7. Only then open a production C3 implementation slice.

## Gates

No production admission from this research branch.

A production proposal requires:
- exact source-equation reconstruction;
- explicit state classification;
- independent reference kernel;
- wet/dry, temperature, soil, depth and root-geometry coverage;
- SWAP-007 pathological case coverage;
- A/B/A replay where applicable;
- root-sink exactly-once mass ownership;
- fail-closed groundwater derivative behavior;
- measured cost relative to the legacy-equivalent implementation.

## First finding

A literal port of `oxygenstress.f90` is not the default strategy. Existing evidence already proves that part of the apparent state in the legacy routine is immutable derived data, and the 2008 scientific model is naturally decomposable into demand, macro transport, micro transport and a final supply/demand reduction. The next decisive question is whether any true cross-timestep oxygen state remains after exact equation reconstruction.


## Reconstruction checkpoint R1

### Numerical solve identified

The SWAP-007 patch exposes the local Newton residual derivative in the legacy scalar solve:

```text
fi_a = ... exp(-l / shape_factor_microbialr)
       - (r_mroot_z0 / d_soil) * l * exp(-l / shape_factor_rootr)
lnew = abs(l - fi / fi_a)
```

This is strong evidence that the Newton machinery is an instantaneous scalar root solve in a length-like variable `l`, with current root and microbial respiration terms and current soil oxygen diffusivity. No evidence found so far indicates that `l` is committed physical state between timesteps.

The legacy comments also explicitly mention an alternative ZBREND solution inside `SOLVE`. That independently supports classifying Newton as numerical execution policy rather than physical state.

### State classification strengthened

Evidence now supports, but does not yet fully qualify:

- six soil/hydraulic arrays: immutable-after-construction derived data;
- water-film thickness: recomputed from current matric potential and hydraulic precomputation;
- `d_soil`: recomputed from current gas-filled porosity and immutable coefficients;
- Newton variable `l`: likely call-local scalar scratch;
- Newton restart: numerical recovery, not model-time continuation.

Therefore H1/H2 remain live and strengthened. They are not yet admitted facts until the complete pristine equation/call graph is recovered.

### Performance implication

A SWAP5 design should separate:

```text
immutable soil precompute
        +
current node state/config
        -> instantaneous oxygen response kernel
        -> rwu reduction factor
```

and keep scalar-solver policy outside the physical-state object.

### Remaining authority gap

The available cumulative patch contains unchanged legacy equations only as context around changed hunks; it is not a complete pristine `oxygenstress.f90`. Exact B1.11 source materialization remains necessary before an exact independent kernel can be declared qualified. Library evidence is sufficient to continue architecture reconstruction but not to invent omitted equations.


## Reconstruction checkpoint R2 — recovered 2026-09-03 performance evidence

A previously completed SWAP 4.3.1 oxygenstress performance investigation was recovered from the project Library. This materially advances C3R and must be treated as historical experimental evidence, not yet as canonical SWAP5 production authority.

### Exact-preserving findings already demonstrated

1. `waterfilmthickness` redundantly invoked a complete QROMBD integration a second time with identical limits/parameters. QROMBD already owns its convergence loop. Removing the duplicate integration preserved model output and Newton statistics in controlled physical-oxygen tests and reduced total runtime by about 20% in the grass case.

2. `SOLVE` can test the maximum respiration endpoint first. The residual `myfunc` decreases with respiration demand because macro oxygen concentration decreases while the required micro/root concentration increases. If oxygen supply is sufficient at `max_resp_factor`, the exact solution is immediately the maximum respiration factor. Historical instrumentation found about 95% of expensive physical OxygenStress calls in the official grass case ended at `alpwet=1`. This exact early exit added roughly 12–13% runtime reduction on top of finding 1.

3. The legacy implementation already supports a bracketed ZBREND path over `[0,max_resp_factor]`. This further confirms that the root solve is an instantaneous constitutive response, not cross-timestep physical continuation state.

### Approximate/high-performance finding already demonstrated

A 300-point logarithmic cubic-Hermite water-film lookup (WFT300) was tested against the corrected Romberg route for analytical Mualem–Van Genuchten hydraulics.

Historical broad-regression timing gains relative to the already-improved Romberg route included approximately:
- grassgrowth 5 y: 32%;
- sand B02/O02/O01 5 y: 31%;
- B05/O05 5 y: 49%;
- clay-type profile 5 y: 18%;
- peat-type profile 5 y: 22%.

Well-conditioned cases generally retained identical aggregate Newton histograms and differences at/below printed rounding. A demanding stable B05/O05 case showed a small transient crop-output difference but 300/600/1000 table resolutions produced identical daily output to one another, demonstrating a resolution plateau. Pathological homogeneous O05/O13 profiles already had Richards nonconvergence in the Romberg baseline and are not suitable transparent-regression gates.

### Consequence for SWAP5 strategy

Do not reproduce the old execution structure.

The production candidate should be developed in two layers:

A. exact/reference kernel:
- immutable precompute;
- current node state;
- exact no-stress endpoint test;
- one reference water-film evaluation;
- bounded scalar response solve only when stress is possible.

B. optional practical/performance kernel:
- WFT lookup or successor interpolant;
- explicitly qualified approximation envelope;
- reference kernel retained as oracle/fallback.

This matches the broader SWAP5 policy of qualifying exact-preserving waste removal before practical approximation.

### Remaining work

The old experiments establish strong algorithmic evidence but were performed in SWAP 4.3.1. C3R still needs:
- exact pristine source extraction/materialization;
- a standalone reference kernel independent of legacy module globals;
- state/ownership proof at the SWAP5 interface;
- direct comparison of Newton versus bracketed solve cost/robustness;
- requalification on current SWAP5 hydraulic/thermal owner views.


## Reconstruction checkpoint R3 — standalone solver skeleton

The historical C3A/C3B workflow names were recovered only from a failed reconcile-tree transcript. No complete source/result artefacts were recovered and no corresponding PR is present in current repository history. They are therefore classified as provenance clues only and are not used as qualification evidence.

A new independent research component was added under `src/physics/oxygen/mod_oxygen_scalar_bracket.f90`.

Properties:
- pure residual callback;
- no SWAP globals or I/O;
- exact maximum-demand no-stress fast exit;
- explicit full-stress endpoint;
- bounded bisection for an interior root;
- no persistent state;
- no Newton derivative and therefore no SWAP-007 overflow route in this candidate execution policy.

This is not yet the Bartholomeus kernel. It is the solver-policy component into which the exact reconstructed physical residual can later be injected.

A focused standalone test covers no-stress, full-stress and interior-root behavior. No GitHub Actions workflow is added at this stage.


## Reconstruction checkpoint R4 — physical residual boundary

Recovered source-context from the exact no-stress patch establishes the legacy `SOLVE/myfunc` sign contract:

```text
residual(resp_factor) = c_macro(resp_factor) - c_min_micro(resp_factor)
```

where the historical implementation states that increasing respiration demand decreases `c_macro` and increases `c_min_micro`.

Therefore:
- residual at maximum demand >= 0: exact no-stress result;
- residual at zero <= 0: full-stress result;
- opposite endpoint signs: one interior balance point is sought by the legacy bracketed route.

A pure `mod_oxygen_balance_contract` now records this source-bound algebra without importing legacy globals.

### Important boundary

The complete algebra inside legacy `MACRO` and `MICRO` is not yet present in the indexed patch evidence. It will not be reconstructed from variable names or inferred literature equations. The next kernel step requires extraction of the pristine/patched `oxygenstress.f90` payload from the retained source package or another exact source-bearing artefact.

R4 therefore advances the kernel boundary without fabricating omitted physics.


## Reconstruction checkpoint R5 — upstream formula recovery

The public SWAP-model/SWAP source exposes the complete legacy physical oxygen module. Its file history identifies the same 2017/2018 optimized Bartholomeus implementation family that is visible in the retained 4.3.1 patch context.

Recovered formula blocks include:
- `TEMP_DEPENDENT_PARAMETERS`;
- `microbial_resp`;
- `MICRO`;
- `MACRO`;
- `SOLVE/myfunc`;
- water-film `FUNC` and integration machinery.

Cross-version consistency already established:
- the optimization header and cache algebra match retained 4.3.1 context;
- the MACRO Newton derivative is exactly the expression patched by SWAP-007 in 4.3.1;
- the SOLVE residual/sign semantics match the recovered 4.3.1 fast-no-stress patch;
- the same six immutable precompute quantities occur.

This makes the public source a strong reconstruction aid, but not yet a substitute for the pinned 4.3.1 authority. Formula blocks must be classified as unchanged/corrected/version-sensitive before being copied into the independent kernel.

### Newly visible architecture

MICRO is an instantaneous algebraic function of respiration factor plus current node/config quantities.

MACRO is also instantaneous in physical inputs. Its internal Newton iteration solves for a depth `l` at which oxygen concentration becomes zero when total respiration is sufficiently high. That inner Newton solve is distinct from the outer respiration-factor solve.

Therefore the physical route contains two numerical solves in the historical implementation:
1. outer balance: choose respiration factor so c_macro = c_min_micro;
2. conditional inner MACRO solve: determine zero-oxygen penetration depth l.

Neither solve is evidence of cross-timestep oxygen storage.

### New optimization target

The earlier statement that removing the outer Newton route structurally removes all SWAP-007-like risk was too broad. SWAP-007 is in the inner MACRO Newton solve for `l`. A clean SWAP5 kernel should therefore also replace or robustly bound that inner solve rather than merely changing the outer SOLVE policy.


## Reconstruction checkpoint R6 — MACRO inner solve is uniquely bracketable

For the legacy high-demand MACRO branch define

```text
A = shape_microbial^2 * r_microbial_z0 / d_soil
B = shape_root^2      * r_mroot_z0      / d_soil

f(l) = ctop
     - A * [1 - (l/sm) exp(-l/sm) - exp(-l/sm)]
     - B * [1 - (l/sr) exp(-l/sr) - exp(-l/sr)]
```

The exact derivative is

```text
f'(l) = -(r_microbial_z0/d_soil) * l * exp(-l/sm)
        -(r_mroot_z0/d_soil)     * l * exp(-l/sr)
```

which is the derivative visible in the SWAP-007 source patch.

For physically non-negative respiration and positive diffusivity:
- `f(0)=ctop`;
- `f'(l)<0` for `l>0` whenever demand is nonzero;
- `lim(l->infinity) f(l)=ctop-A-B = ctop-dum`.

The legacy code enters this solve when `dum >= ctop`. Therefore for `dum > ctop` there is exactly one positive finite root. At equality the root is asymptotic/infinite.

Conclusion: restart-based Newton is not required by the mathematics. The physical problem is a monotone one-dimensional bracketed root.

A pure bounded candidate `mod_oxygen_macro_zero_depth` was added. It brackets by deterministic upper-bound expansion and then bisects. This removes derivative division and restart policy from the candidate kernel. It is research code pending 4.3.1 numerical parity tests.
