# F-GC30 derivative coverage decision boundary

## Status

**QUALIFIED DESIGN BOUNDARY, NOT CANONICAL ADMISSION**

This record supersedes the earlier F-GC30 execution-policy assumption that the first implementation must be finite-difference-only. The scientific policy is now hybrid:

- use an accepted-trajectory tangent only when explicit derivative coverage is complete for the active production route;
- retain centered finite difference as conservative fallback when analytic coverage is incomplete;
- retain centered finite difference as an independent qualification oracle even after an analytic route is admitted.

This does not change Groundwater Coupling v1 semantics and does not admit a MODFLOW 6 backend.

## Fixed coupling-plane quantity

F-GC30 couples on hydraulic head at the fixed lower face of the SWAP column. This is not the internally diagnosed freatic groundwater level.

For the B1.10 prescribed-`qbot` route, HeadCalc uses the lower-face gradient convention

```text
grad_bottom = (h_n - h_bot) / d + 1
q_bot       = -K_n * grad_bottom
```

where `d = 0.5 * dz_n`.

Therefore the implied lower-face pressure head is

```text
h_bot = h_n + d * (1 + q_bot / K_n)
```

and its directional derivative with respect to native prescribed `q_bot` is

```text
dh_bot/dq_bot = dh_n/dq_bot
                + d * [1/K_n - q_bot * (dK_n/dq_bot) / K_n^2]
```

The corresponding hydraulic head uses the existing datum-aware Groundwater Coupling v1 translation. The datum elevation is constant under the local derivative, so the derivative in metres is `0.01 * dh_bot/dq_bot` when the native pressure-head derivative is expressed in centimetres.

`src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90` implements only this derived coupling information. It owns no hydrologic state.

## Coverage findings

### Richards hydraulic response

For the admitted F-KT21 prescribed-bottom-flux smooth route, the accepted trajectory carries the terminal pressure-head direction vector and only accepted substeps contribute. Rejected/retried candidates do not contribute to the published accepted trajectory.

### Constitutive response

The B1.10 default-MvG directional provider supplies the smooth-route conductivity direction required by the lower-face quotient rule. Constitutive switch points remain fail-closed.

### Dynamic top boundary

The existing F-KT21 route already has explicit dynamic-top directional handling and refuses unsupported or nonsmooth top-boundary regimes.

### Root uptake

A separate active root-sink provider without a qualified derivative already makes the F-KT21 step direction unavailable. F-GC30 preserves that fail-closed behavior.

### Drainage

Production drainage response already exposes `dq_dgroundwater_level` plus derivative-defined and nonsmooth diagnostics. That is not sufficient by itself.

The missing chain is

```text
q_bot -> hydraulic state -> groundwater_level -> drainage -> next hydraulic state
```

The production B1.10 lifecycle recalculates groundwater level in `SoilWater(3)` through `calcgwl()` after the Richards Task2 solve. The immutable SWAP 4.3.1 B0 manifest identifies `SWAP/calcgwl.f90`, but the byte-identical source member is not yet available as an unpacked Git file. The targeted F-GC30 analysis therefore does not invent or substitute a `calcgwl` formula.

Until the exact production groundwater-level postprocessing and its directional semantics are qualified, an active state-dependent drainage owner means:

```text
drainage_active  = true
drainage_covered = false
```

and an analytic F-GC30 tangent must fail closed. Centered finite difference remains permitted as the full-production-trajectory fallback/oracle.

## Signs and units

Native SWAP `qbot > 0` is into the SWAP soil profile. Groundwater Coupling v1 defines positive public SWAP exchange as outward from SWAP. Consequently the historical predictor relation

```text
u   = delta_t / (dH_bot,end/dq_bot)
q_u = u * (H_bot,end - H_bot,start) / delta_t - q_bot
```

has the required public direction when kept in native SWAP length/time units for the algebra. In the zero-head-change limit, `q_u = -q_bot`.

`accepted_storage_change` is not used as a substitute for the historical coupling-storage response.

## Production predictor candidate binding

The drainage-free production predictor now has a separate non-committing candidate-binding seam: `mod_modflow6_swap_predictor_candidate_assembler`.

It does not open candidate private state and does not publish or commit anything. It requires the accepted predictor origin, kernel candidate, kernel result, coupling window and already-qualified tangent endpoint to agree on the following provenance before composing the typed predictor response:

- committed predictor origin time equals the coupling-window start;
- candidate origin lineage and revision equal the accepted SWAP predictor origin;
- candidate origin interval equals the coupling window;
- kernel requested/completed interval equals the same window;
- endpoint worker, trajectory generation, accepted-step count and method agree with the kernel result's accepted trajectory;
- bottom-interface exchange is available.

The native predictor control is recovered only as

```text
q_bot,predictor = -terminal_bottom_outward_flux_native
```

which preserves the established SWAP/public exchange sign boundary. `H_bot,start` is taken from the committed accepted SWAP interface head retained in the F-GC30 predictor origin. A distinct accepted groundwater head is retained as provenance and is not silently substituted.

## Production finite-difference oracle topology

The first production-oracle attempts exposed an important transaction distinction. On the serialized-reference `TX_TEMPORAL_EXTERNAL_FULL_HALF` route, the full-versus-two-half comparator for this B1.10 surface is deliberately an exact state-identity comparator. Any non-trivial nearby `qbot` perturbation therefore fails that temporal acceptance route; shrinking the perturbation or consuming retries would not turn it into a smooth error norm.

F-GC30 does not relax that policy. The qualified production tangent/FD oracle instead uses the already-admitted prescribed-`qbot` model-certificate route:

- `TX_TEMPORAL_MODEL_CERTIFICATE`;
- `FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY`;
- explicit finite head-error budget;
- predecessor right-derivative continuation history seeded at the committed origin, using the already-qualified prescribed-`qbot` temporal-certificate contract;
- one immutable committed/checkpoint origin for nominal and perturbed trials.

The nominal predictor is a non-committing production candidate with the accepted-trajectory bottom-flux direction requested. The centered-FD points are two additional non-committing production candidates from the same origin with that tangent request disabled and only native prescribed `qbot` changed by `+eps` or `-eps`.

Therefore the oracle differentiates the same admitted production candidate map that supplies the nominal predictor rather than manually replaying a solver topology or weakening transaction acceptance. Each perturbed candidate must complete without transaction retry, and its terminal lower-face head is reconstructed with the same qualified fixed-face helper.

This centered FD remains an **independent qualification oracle** for the analytic tangent. It is not, by itself, a runtime finite-difference fallback implementation for analytically incomplete process envelopes such as active drainage.
## Qualification evidence

The F-GC30 predictor-response contract is qualified by a deterministic O0/O2 gate covering:

- typed predictor response;
- tangent `u` algebra;
- independent centered finite-difference oracle;
- tangent/FD agreement on admitted smooth cases;
- incomplete active-drainage coverage failing closed;
- FD fallback with incomplete analytic coverage;
- public/native `q_u` sign translation.

The prescribed-`qbot` lower-face materializer is separately qualified by a deterministic O0/O2 gate covering:

- B1.10 Darcy reconstruction;
- datum-aware head translation;
- quotient-rule directional derivative;
- independent centered finite-difference derivative oracle;
- free-drainage identity;
- invalid conductivity and incomplete derivative provenance failing closed.

GitHub Actions run `35282629916` passed the initial contract and lower-face gates at branch head `37aeae2d5ae928e7123518b05e405bd0a48e9dc6`.

The complete drainage-free production predictor slice is qualified by GitHub Actions run `35284524659` at branch head `e1f086d6f1dc2b60c2b1fc5a2b61b52dc9fa452b`. The run passed all five F-GC30 gates under both O0 and O2, including O0/O2 output identity. Production markers include accepted-trajectory binding, authoritative tangent endpoint, independent centered-FD production-candidate oracle, tangent/FD agreement, candidate assembler, typed predictor response, provenance fail-closed and active-drainage tangent fail-closed.

Earlier runs `35283965123` and `35284199733` exposed that non-trivial perturbations cannot be qualified through the exact external full-versus-half state-identity comparator. Run `35284457161` then exposed a stale manual two-half oracle after the nominal route had been moved to the model-certificate surface. None of these failures was converted to PASS by relaxing production policy; the final qualification uses one coherent model-certificate candidate route for nominal and FD trials.

## Next permitted implementation

The drainage-free predictor response primitives and the production candidate-binding seam are qualified. The next bounded action is admission review of this exact drainage-free envelope against the current canonical head. Admission must preserve these limits:

1. no active drainage analytic tangent until exact production `calcgwl` directional semantics are qualified;
2. no MODFLOW/XMI backend or groundwater execution redesign;
3. no change to Groundwater Coupling v1 transaction/commit semantics;
4. no `accepted_storage_change` substitution;
5. no claim that the qualification-only centered-FD production-candidate oracle is already a runtime FD fallback implementation.

Any later runtime finite-difference fallback for analytically incomplete production routes is a separate workunit/decision surface and must preserve complete-process coverage rather than reusing the drainage-free qualification oracle as if it covered missing physics.
