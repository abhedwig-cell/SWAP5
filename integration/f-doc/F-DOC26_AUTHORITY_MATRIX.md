# F-DOC26 authority matrix — soil-hydraulic constitutive reference

F-DOC26 is documentation-only. It reconciles the scientific role of the soil-hydraulic constitutive relations with the exact qualified/frozen implementation boundaries. It does not create new scientific authority.

| Claim surface | Controlling authority | Documentation ceiling |
| --- | --- | --- |
| Scientific role of constitutive hydraulics | Historical F-DOC18 RB1 science authority | `theta(h)`, `K(h)` and differential water capacity `C(h)` are constitutive inputs to the bounded reference Richards formulation. Historical theory is not current implementation proof. |
| Default constitutive value-provider | F-SI09 `F-SI09_QUALIFICATION.json` and `F-SI09_PROVIDER_CONTRACT.json` | Default MvG analytical branch only; `SWSOPHY=0`, `SWKIMPL=0`, no hysteresis/tabulation/elasticity/frost/macropore/power-tail/saturated-extrapolation broadening. |
| Frozen implementation | `50346642bd565f79134ea17d5462e544b354998c:src/solver/mod_b110_default_mvg_provider.f90`, blob `fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6` | Exact branch logic of `initialize_b110_default_mvg_parameters`, `b110_watcon`, `b110_moiscap`, and `b110_hconduc` may be described. |
| Function-level identity | F-SI09 | `cofgen(25:42)`, `theta(h)`, `C(h)` and `K(h,theta)` were compared bitwise against the corrected B1.10 oracle under the qualified matrix. This does not qualify inverse-pressure-head or `SWKIMPL=1` `dK/dh`. |
| Ordinary provider derivative slot | frozen value-provider + F-SI09 | `dconductivity_dhead` is deliberately returned as zero/reserved in the admitted `SWKIMPL=0` route. Do not describe it as a physical zero derivative. |
| Smooth directional constitutive derivative | F-SI37 `F-SI37_STATUS.json`, executed source `992d524e3a4f5f7e21ddd9b6992c0e043f66c9fd`; directional provider blob `b1e794d2f0e661a2abb14280a59175e1cf1d5724` | A separate sibling capability differentiates the exact smooth constitutive branches for one accepted-step direction. It fails sensitivity closed at branch/switch boundaries. F-SI37 is owner qualification only and is not a general Status-A physics broadening. |
| Parameter semantics | frozen source plus accepted historical/source authority | Use `cofgen(k)` indices wherever a semantic name is not explicitly source-bound. Familiar textbook names may be used only when the accepted authority establishes the mapping; do not infer names from formula shape alone. |
| Transaction/commit ownership | existing solver/transaction authority | Constitutive evaluation is calculation support. It does not own committed state, retry or rollback. |

## Branch facts that may be documented

From the frozen value-provider:

- `B110_H_CRIT = -1.0e-2 cm` is the near-saturation switch used by the default branch.
- `head >= 0` returns saturated water content `cofgen(2)`.
- two retention families are selected by the sign/location of `cofgen(9)` relative to `B110_H_CRIT`; both include explicit transition handling rather than one global textbook expression;
- `C(h)` includes a small `step_duration * 1e-7` floor at saturation and near saturation;
- `K` is bounded by `cofgen(3)`, uses a very-small-conductivity guard below `-1e14 cm`, and contains explicit saturation/air-entry switching;
- ordinary `dconductivity_dhead` is not admitted for `SWKIMPL=1` and remains reserved.

From F-SI37:

- the directional capability differentiates the exact smooth branch currently active;
- exact switch surfaces such as `h=0`, `h=B110_H_CRIT`, `h=1.05*cofgen(9)`, the extreme-dry threshold, saturation-conductivity threshold and air-entry boundary are not differentiated through;
- unavailable derivative routes return fail-closed rather than silently using a derivative from the wrong branch;
- the physical value-provider and mass-acceptance semantics are unchanged.

## Explicit exclusions

F-DOC26 does not claim:

1. a universal Van Genuchten/Mualem parameter naming map for all `cofgen` rows;
2. admission of model families outside the F-SI09 default analytical profile;
3. production `SWKIMPL=1` or a generic `dK/dh` path;
4. differentiability through constitutive or boundary regime switches;
5. that F-SI37's derivative owner qualification broadens the frozen Status-A physical denominator;
6. any production/reference/source change.
