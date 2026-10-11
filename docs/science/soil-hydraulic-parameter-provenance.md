# Soil-hydraulic parameter provenance

This page records what can — and cannot — be said from repository authority about the B1.10 `cofgen` parameter rows used by the frozen Status-A soil-hydraulic route.

It is a provenance page, not a new hydraulic-model specification. The executable equations remain documented in [Soil-hydraulic constitutive relations](soil-hydraulic-constitutive-relations.md).

## Why the mapping remains deliberately bounded

The frozen production provider is `src/solver/mod_b110_default_mvg_provider.f90` at scientific baseline `50346642bd565f79134ea17d5462e544b354998c`. It requires at least 24 supplied rows, copies those rows into its node-local parameter object, and computes rows `25:42` internally.

F-SI09 binds that provider to an exact corrected B1.10 `MOD_MvG_functions.f90` oracle and qualifies the derived rows plus `theta(h)`, `C(h)` and `K(h,theta)` by bitwise executable identity for the admitted profile. The legacy oracle is retained in the repository as an immutable compressed reference payload with a manifest-pinned decoded SHA-256.

The byte-verified B1.10 source now closes two provenance questions that earlier documentation intentionally left open:

- `set_cofgen_pointers` gives exact internal aliases for rows `1:16` and `22:24`;
- `fill_cofgen` gives exact model-dependent copy/activation rules for supplied rows `1:24`.

It still does **not** provide one complete table proving every original user-facing input keyword and input unit for every row. Rows `17:21` deliberately have no global pointer aliases in `set_cofgen_pointers`, and supplementary parser/qualification evidence is model-specific. This page therefore closes the internal alias/activation mapping without filling the remaining parser/unit gaps from textbook convention.

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
| `17` | Same bounded finding as row 16 | unresolved | unresolved | no global pointer alias; qualified model-7 relation documented below |
| `18` | Same bounded finding as row 16 | unresolved | unresolved | no global pointer alias; model-dependent qualified evidence documented below |
| `19` | Same bounded finding as row 16 | unresolved | unresolved | no global pointer alias; model-8 qualified evidence documented below |
| `20` | Same bounded finding as row 16 | unresolved | unresolved | no global pointer alias; model-8 qualified evidence documented below |
| `21` | Same bounded finding as row 16 | unresolved | unresolved | no global pointer alias; model-8 qualified evidence documented below |
| `22` | Same bounded finding as row 16 | unresolved | unresolved | exact B1.10 pointer alias available below |
| `23` | Same bounded finding as row 16 | unresolved | unresolved | exact B1.10 pointer alias available below |
| `24` | Same bounded finding as row 16 | unresolved | unresolved | exact B1.10 pointer alias available below |

The “no direct dependency” statements are intentionally local to this frozen **default provider**. They do not mean that those rows are meaningless elsewhere in historical SWAP, another hydraulic-model family, an input parser, or another provider.

## Exact B1.10 internal pointer aliases

The immutable `MOD_MvG_functions.f90` payload decodes to SHA-256 `4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1`, matching its repository manifest and the B1.10 snapshot definition. Its `set_cofgen_pointers` routine directly binds the following aliases:

| `cofgen` row | Exact B1.10 pointer alias |
|---:|---|
| `1` | `wcr` |
| `2` | `wcs` |
| `3` | `ksatfit` |
| `4` | `alfamg` |
| `5` | `lambda` |
| `6` | `n` |
| `7` | `m` |
| `8` | `alfamgwet` |
| `9` | `h_enpr` |
| `10` | `ksatexm` |
| `11` | `relsatthr` |
| `12` | `ksatthr` |
| `13` | `alfa_2` |
| `14` | `n_2` |
| `15` | `m_2` |
| `16` | `omega_1` |
| `17` | no global pointer alias in `set_cofgen_pointers` |
| `18` | no global pointer alias in `set_cofgen_pointers` |
| `19` | no global pointer alias in `set_cofgen_pointers` |
| `20` | no global pointer alias in `set_cofgen_pointers` |
| `21` | no global pointer alias in `set_cofgen_pointers` |
| `22` | `h_power` |
| `23` | `k_power` |
| `24` | `elas` |

These are exact **internal B1.10 source aliases**. They are stronger evidence than names inferred from equation shape, but they are not automatically identical to original parser keywords or user-facing documentation names.

## Exact model-dependent copy and activation rules

For parameterized soil hydraulics (`swsophy == 0`), B1.10 `fill_cofgen` copies `paramvg` into node-local `cofgen` as follows:

| Rows copied | `iHWCKmodel` scope | B1.10 meaning of the model identifiers |
|---|---|---|
| `1:12` | all parameterized models | common supplied block |
| `13:17` | `3, 6, 7, 10, 11` | bi-modal MvG and the listed bi-modal/PDI variants |
| `18` | `5, 7` | model-specific row 18 only |
| `18:21` | `8, 9, 10, 11` | four-row PDI block |
| `22:24` | all parameterized models | common supplied block |

The same immutable source identifies model `1` as default MvG, model `2` as exponential, model `3` as bi-modal MvG, and models `4:11` as eight PDI versions.

This table matters because the 24-row storage layout is **not** a claim that all 24 values are active simultaneously for every hydraulic model.

For tabulated soil hydraulics (`swsophy == 1`), B1.10 follows a different path: `cofgen` is cleared and rows `1:3` are populated from the table route as residual-water-content placeholder, saturated water content and saturated conductivity. The 24-row parameterized mapping above is therefore not the table-mode input contract.

## Additional bounded provenance for rows `17:21`

Rows `17:21` have no global aliases in `set_cofgen_pointers`, so their evidence must remain model- and source-specific.

The qualified SWAP-010 model-7 capacity gate constructs:

```text
cofgen(17) = 1 - cofgen(16)
```

while row `16` is the exact B1.10 pointer alias `omega_1`. This proves the relation in that qualified model-7 material; it does not by itself establish an original parser keyword for row `17`.

The qualified SWAP-009 model-8 PDI harness supplies:

| Row | Harness label/value role | Harness unit evidence |
|---:|---|---|
| `18` | `|h0|` | `cm` |
| `19` | `|ha|` | `cm` |
| `20` | `PDI a` | no explicit unit claim in the harness |
| `21` | `omega_K` | no explicit unit claim in the harness |

The frozen SWAP-013 parser patch independently exposes the legacy parser field names `h0`, `ha`, `apar` and `omega_K`, including the PDI validation `0 < abs(HA) < abs(H0)` for models `8:11`.

As secondary corroboration, the official `SWAP-model/SWAP` repository at commit `c22bd832ddf3e53e330a552f5e31e74f183362d1` assigns `paramvg(17)=1-omega_1` and `paramvg(18:21)=h0,ha,apar,omega_K`. That external source is useful provenance evidence but is **not** promoted here to the byte identity of the frozen B1.10 oracle. Therefore the main table above continues to leave original B1.10 parser-field/unit cells unresolved where the exact frozen chain does not bind them directly.

## Direct local aliases exposed by SWAP-012

The frozen SWAP-012 patch supplies an additional local view inside the corrected B1.10 inverse-retention logic for `imod == 3`:

```text
omega1 = cofgen_in(16,node)
alpha2 = cofgen_in(13,node)
npar2  = cofgen_in(14,node)
mpar2  = cofgen_in(15,node)
```

These code-local names are consistent with the exact global pointer aliases `omega_1`, `alfa_2`, `n_2` and `m_2` above. The local assignments remain useful because they prove the row use inside that specific inverse-retention branch.

The same patch reads `cofgen_in(18,node)` as a lower search bound for selected model identifiers. Because the meaning of row `18` is model-dependent and `set_cofgen_pointers` gives it no global alias, F-DOC33 does not collapse that use into one universal semantic name.

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

## Units and user-facing input names

This page distinguishes three different evidence levels:

1. **exact internal alias** — directly bound by the byte-verified B1.10 source;
2. **qualified model-specific label/unit** — recorded by an admitted qualification harness or frozen parser patch in a bounded context;
3. **original user-facing input contract** — requires an exact parser/manual-to-row binding.

The first level is now substantially complete for rows `1:24`; the second adds bounded PDI evidence for rows `17:21`. The third remains incomplete and is therefore not reconstructed from conventional Mualem–Van Genuchten symbols or dimensional analysis.

The operational units used by the admitted Richards and constitutive route remain documented on the corresponding science and numerical reference pages.

## Nonclaims

This page does not claim that:

- `cofgen(1:24)` are all independent user-entered parameters;
- all 24 rows are active for every hydraulic model;
- internal pointer aliases are necessarily identical to original parser keywords or user-facing parameter names;
- conventional Mualem–Van Genuchten symbols or units can be assigned from equation shape alone;
- model-8 PDI qualification labels automatically generalize to every model that uses rows `18:21`;
- the external official-SWAP parser commit is byte-identical to the frozen B1.10 reference source;
- rows without direct use in the frozen default provider are unused elsewhere;
- the F-SI09 default-MvG qualification covers every hydraulic-model family;
- any production, input or scientific semantics have changed.

The remaining unresolved cells are an explicit traceability boundary, not missing prose.
