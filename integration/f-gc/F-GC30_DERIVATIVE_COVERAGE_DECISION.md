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

The serialized-reference production route used by this qualification has `TX_TEMPORAL_EXTERNAL_FULL_HALF` temporal acceptance. For this B1.10 route, the model's external full-versus-two-half temporal comparator is deliberately an exact state-identity comparator: any non-trivial nearby `qbot` perturbation changes the state and therefore returns an effectively infinite temporal error. Reducing the FD epsilon does not make that comparator into a smooth numerical error norm.

Consequently, a valid centered finite-difference oracle for the accepted production map must not weaken the transaction tolerance or increase retries until a perturbed trajectory happens to pass. Instead, the qualification replays the **accepted two-half discrete solver topology directly** from the same physical origin:

1. two B1.10 half-step nonlinear solves;
2. identical top forcing and all source/sink inputs;
3. only native prescribed `qbot` is perturbed by `+eps` or `-eps`;
4. no tangent/interface-sensitivity request is made;
5. both half-solves must converge without internal retry or alternative solver use;
6. the terminal lower-face head is reconstructed with the same qualified fixed-face helper.

This is an independent derivative oracle for the accepted discrete trajectory. It does not alter production transaction semantics and is not itself a new runtime fallback implementation.

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

The complete drainage-free production predictor slice is qualified by GitHub Actions run `35284444327` at branch head `df44b416169b58325a6bb55f826650ffdbc9bae5`. The run passed all five F-GC30 gates under both O0 and O2, including output identity where asserted. Production markers include accepted-trajectory binding, authoritative tangent endpoint, independent centered-FD oracle, tangent/FD agreement, candidate assembler, typed predictor response, provenance fail-closed and active-drainage tangent fail-closed.

Two earlier oracle iterations, runs `35283965123` and `35284199733`, failed only because the perturbed trials were sent through the exact full-versus-half temporal-identity comparator. Those failures are retained as evidence for the topology decision above; they were not converted to PASS by relaxing policy.

## Next permitted implementation

The drainage-free predictor response primitives and the production candidate-binding seam are qualified. The next bounded action is admission review of this exact drainage-free envelope against the current canonical head. Admission must preserve these limits:

1. no active drainage analytic tangent until exact production `calcgwl` directional semantics are qualified;
2. no MODFLOW/XMI backend or groundwater execution redesign;
3. no change to Groundwater Coupling v1 transaction/commit semantics;
4. no `accepted_storage_change` substitution;
5. no claim that the direct two-half FD oracle is a runtime FD fallback implementation.

Any later runtime finite-difference fallback for analytically incomplete production routes is a separate workunit/decision surface and must preserve complete-process coverage rather than reusing the drainage-free two-half oracle as if it covered missing physics.
