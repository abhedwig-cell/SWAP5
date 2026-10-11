# F-DOC32 authority matrix — B1.10 `cofgen` legacy alias provenance

## Decision surface

F-DOC32 is a documentation-only refinement of the admitted F-DOC27 partial provenance map. It records only legacy code-local aliases that the frozen SWAP-012 patch binds directly to `cofgen_in` rows. It does not convert those aliases into original input-field names, input units or a complete hydraulic-parameter dictionary.

## Controlling authorities

| Authority | Exact identity | Permitted use |
|---|---|---|
| Live canonical at branch start | `8e0de81a62527bc7d8e49068f1ffd4a8a85aeec3` | Documentation integration base |
| Frozen scientific production baseline | `50346642bd565f79134ea17d5462e544b354998c` | Scientific denominator |
| Frozen production tree | `3b085d7dea3d3f3fce42ad9d8f259a8350205846` | Production-tree denominator |
| Admitted F-DOC27 | PR #179, canonical `74051e113fcef19e021d69854f3ab99066eb30cb` | Existing partial provenance map and unresolved-field policy |
| SWAP-012 frozen patch | `reference/swap-4.3.1/patches/SWAP-012/fix.patch`, blob `77f4b63689a6f72116280cbd019852b3b181e34a` at baseline `50346642...` | Direct source-local alias bindings in the corrected B1.10 inverse-retention branch |
| Corrected B1.10 `MOD_MvG_functions.f90` | decoded SHA-256 `4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1` | Immutable oracle identity only |

## Directly proven bindings

Within the SWAP-012 `imod == 3` branch, the patch directly assigns:

```text
omega1 = cofgen_in(16,node)
alpha2 = cofgen_in(13,node)
npar2  = cofgen_in(14,node)
mpar2  = cofgen_in(15,node)
```

F-DOC32 may therefore state that rows `13:16` have these **legacy code-local aliases in that branch**.

The same patch also reads `cofgen_in(18,node)` to bound `hlow` for selected model identifiers, but it does not name row 18. F-DOC32 must leave its original field/name and unit unresolved.

## Claim ceiling

Permitted:

- record `13 -> alpha2`, `14 -> npar2`, `15 -> mpar2`, `16 -> omega1` as source-bound legacy local aliases for the SWAP-012 model-3 inverse-retention logic;
- preserve F-DOC27's provider-local internal-role findings;
- preserve unresolved original input names and units.

Forbidden:

- present the four aliases as proven original parser/input keywords;
- infer units from the alias names or equations;
- project those aliases onto other hydraulic-model families or all historical SWAP uses of the rows;
- infer a semantic name for row 18 from its use as an `hlow` bound;
- change production, reference, tests, equations, parameter values or numerical policy.

## Documentation verdict

`TARGETED_ALIAS_PROVENANCE_REFINEMENT_SUPPORTED`
