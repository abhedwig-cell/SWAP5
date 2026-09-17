# Soil-hydraulic parameter provenance

This page records what can — and cannot — be said from repository authority about the B1.10 `cofgen` parameter rows used by the frozen Status-A default-MvG constitutive provider.

It is a provenance page, not a new hydraulic-model specification. The executable equations remain documented in [Soil-hydraulic constitutive relations](soil-hydraulic-constitutive-relations.md).

## Why the mapping is deliberately partial

The frozen production provider is `src/solver/mod_b110_default_mvg_provider.f90` at scientific baseline `50346642bd565f79134ea17d5462e544b354998c`. It requires at least 24 supplied rows, copies those rows into its node-local parameter object, and computes rows `25:42` internally.

F-SI09 binds that provider to an exact corrected B1.10 `MOD_MvG_functions.f90` oracle and qualifies the derived rows plus `theta(h)`, `C(h)` and `K(h,theta)` by bitwise executable identity for the admitted profile. The legacy oracle is retained in the repository as an immutable compressed reference payload with a fixed SHA-256.

That evidence establishes executable behaviour very strongly. It does **not**, however, expose a separate complete table mapping every original SWAP input keyword, user-facing parameter name and input unit onto `cofgen(1:24)`. The SWAP-012 patch exposes several legacy local variable names and four direct row-to-local bindings in one model-specific branch, but not a complete original input-field mapping.

For that reason this page does not fill the remaining gaps from textbook convention.

## Supplied rows `1:24`

“Internal role” below means only what the frozen provider itself proves. “Original field” and “input unit” remain unresolved unless directly bound by acquired repository evidence.

| Row | Frozen-provider internal role | Original input field/name | Input unit | Provenance status |
|---:|---|---|---|---|
| `1` | Lower/asymptotic water-content term in retention; lower term in the provider's local saturation ratio | unresolved | unresolved | source-bound internal role |
| `2` | Saturated/upper water-content return value; upper term in retention | unresolved | unresolved | source-bound internal role |
| `3` | Conductivity scale and upper cap returned by the admitted conductivity branch | unresolved | unresolved | source-bound internal role |
| `4` | Head-scaling coefficient; the frozen provider names this local value `alfa` | unresolved | unresolved | source-bound internal role; code-local alias only |
| `5` | Exponent used in the admitted conductivity relation and several derived rows | unresolved | unresolved | source-bound internal role |
| `6` | Power applied to the scaled pressure-head magnitude in retention/capacity | unresolved | unresolved | source-bound internal role |
| `7` | Outer retention exponent and exponent used in the admitted conductivity relation | unresolved | unresolved | source-bound internal role |
| `8` | Copied into the 42-row parameter object; no direct dependency is present in the inspected frozen default-provider initializer or admitted `theta/C/K` evaluators | unresolved | unresolved | provider-local direct role unresolved |
| `9` | Constitutive transition/entry-head value controlling the two admitted branch families; also enters derived transition quantities | unresolved | unresolved | source-bound internal role |
| `10` | Copied into the parameter object; no direct dependency in the inspected frozen default-provider initializer or admitted evaluators | unresolved | unresolved | provider-local direct role unresolved |
| `11` | Same bounded finding as row 10 | unresolved | unresolved | provider-local direct role unresolved |
| `12` | Same bounded finding as row 10 | unresolved | unresolved | provider-local direct role unresolved |
| `13` | Input to derived row `37` | unresolved | unresolved | source-bound algebraic dependency; user meaning unresolved |
| `14` | Input to derived rows `37:39` | unresolved | unresolved | source-bound algebraic dependency; user meaning unresolved |
| `15` | Input to derived rows `37`, `39` and `40` | unresolved | unresolved | source-bound algebraic dependency; user meaning unresolved |
| `16` | Copied into the parameter object; no direct dependency in the inspected frozen default-provider initializer or admitted evaluators | unresolved | unresolved | provider-local direct role unresolved |
| `17` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |
| `18` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |
| `19` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |
| `20` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |
| `21` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |
| `22` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |
| `23` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |
| `24` | Same bounded finding as row 16 | unresolved | unresolved | provider-local direct role unresolved |

The “no direct dependency” statements are intentionally local to this frozen **default provider**. They do not mean that those rows are meaningless elsewhere in historical SWAP, another hydraulic-model family, an input parser, or another provider.

### Direct legacy local aliases exposed by SWAP-012

The frozen SWAP-012 patch provides a narrower kind of provenance than the provider table above. Inside the corrected B1.10 inverse-retention logic for `imod == 3`, it makes four direct assignments:

```text
omega1 = cofgen_in(16,node)
alpha2 = cofgen_in(13,node)
npar2  = cofgen_in(14,node)
mpar2  = cofgen_in(15,node)
```

Therefore the repository directly supports the following **code-local aliases in that branch**:

| `cofgen` row | Legacy local alias | Proven scope |
|---:|---|---|
| `13` | `alpha2` | SWAP-012 B1.10 `imod == 3` inverse-retention branch |
| `14` | `npar2` | SWAP-012 B1.10 `imod == 3` inverse-retention branch |
| `15` | `mpar2` | SWAP-012 B1.10 `imod == 3` inverse-retention branch |
| `16` | `omega1` | SWAP-012 B1.10 `imod == 3` inverse-retention branch |

These aliases are **not** promoted here to original parser keywords, user-facing field names or input units. The patch also reads `cofgen_in(18,node)` as a lower search bound for selected model identifiers, but does not provide a source-local semantic name for row `18`; its original field/name and unit therefore remain unresolved.

## Derived rows `25:42`

Rows `25:42` are not independent supplied parameters for this provider. `initialize_b110_default_mvg_parameters` recomputes them from the supplied rows for every active node.

With `c_k = cofgen(k)` and `Hcrit = -1.0e-2`, the source establishes:

```text
c25 = c2 - c1
c26 = c1 + c25 / (1 + |c4 Hcrit|^c6)^c7
c27 = (c2 - c26) / (-Hcrit)
c28 = (1 + |c4 c9|^c6)^(-c7)
c29 = c6 c7 c4
c30 = c6 - 1
c31 = c7 + 1
c32 = 1 / c7
c33 = c6 (2 + c7 c5)
c34 = c5 + 2
c35 = c7 - 1
c36 = c5 - 1
c37 = c14 c15 c13
c38 = c14 - 1
c39 = c15 + 1
c40 = 1/c15, when c15 > 0; otherwise 0
```

Rows `41` and `42` are transition coefficients. When `c9 < 0`, the provider evaluates the retention value and capacity-like slope at

```text
h105 = 1.05 c9
```

and constructs coefficients `a` and `b` from that transition state, then stores

```text
c41 = a
c42 = a b
```

When `c9 >= 0`, both are set to zero.

The exact algebra for this construction remains authoritative in the frozen source; this page does not rename `a` or `b` as independent physical parameters.

## What F-SI09 proves

F-SI09 qualification compiles the exact corrected B1.10 oracle separately from the production provider and compares ordered IEEE real64 output bit patterns. The admitted comparison covers:

- `cofgen(25:42)` after legacy `calc_cofgen_extra` versus provider initialization;
- `theta(h)`;
- `C(h)`, including the timestep-dependent near-saturation minimum;
- `K(h,theta)`.

The qualification uses heterogeneous 24-row input vectors, multiple step durations and a pressure-head matrix. This is strong evidence that the executable transformation is preserved. It is **not** evidence for user-facing names or units that the qualification never records.

## Legacy names that are visible but not completely bound

The admitted SWAP-012 patch around the corrected legacy source exposes local names including:

```text
thetar, thetas, alfamg, npar, mpar, h_enpr
```

and, in its `imod == 3` branch, directly binds `alpha2`, `npar2`, `mpar2` and `omega1` to rows `13:16` as recorded above.

The patch still does not provide a complete `cofgen(index) -> local name -> original input field` assignment table. In particular, the familiar form of the other visible names is not sufficient authority to back-fill unresolved rows by convention. The four direct aliases above narrow the uncertainty without closing the original input-field/unit provenance gap.

If a later immutable source or input-definition authority supplies the missing assignments, this table can be extended without changing the constitutive equations themselves.

## Units

This page intentionally leaves the **original input unit** column unresolved. Some dimensional behaviour is apparent from the equations, but dimensional inference is not the same thing as a source-bound input contract. Units should be added only when the originating input/parser/manual authority is reconciled to the exact B1.10 parameter rows.

The operational units used by the admitted Richards and constitutive route remain documented on the corresponding science and numerical reference pages.

## Nonclaims

This page does not claim that:

- `cofgen(1:24)` are all independent user-entered parameters;
- conventional Mualem–Van Genuchten symbols can be assigned row-for-row from equation shape alone;
- code-local aliases are necessarily identical to original parser keywords or user-facing parameter names;
- rows without direct use in this provider are unused elsewhere;
- the F-SI09 default-MvG qualification covers other hydraulic-model families;
- any production, input or scientific semantics have changed.

The unresolved cells are an explicit traceability boundary, not missing prose.
