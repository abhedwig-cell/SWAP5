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

GitHub Actions run `35282629916` passed both gates at branch head `37aeae2d5ae928e7123518b05e405bd0a48e9dc6`.

## Next permitted implementation

The next surgical step may bind the already-qualified lower-face reconstruction to an actual accepted prescribed-`qbot` candidate plus F-KT21 terminal direction on a drainage-free admitted route.

That adapter must:

1. consume existing candidate state and accepted trajectory direction, not own state;
2. obtain terminal `K_n` and its direction through the qualified B1.10 constitutive providers;
3. materialize `H_bot,end` and `dH_bot,end/dq_bot` through the qualified lower-face helper;
4. publish derivative coverage explicitly;
5. refuse root uptake, drainage or other active state-dependent owners unless their derivative coverage is separately qualified;
6. remain non-committing candidate information.

Do not implement the drainage chain rule, MODFLOW/XMI backend, irrigation, Ribasim or a second transaction/runtime architecture in this slice.
