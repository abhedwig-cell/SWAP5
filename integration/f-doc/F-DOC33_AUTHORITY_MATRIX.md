# F-DOC33 authority matrix — B1.10 `cofgen` alias and activation provenance

## Decision surface

F-DOC33 is a documentation-only refinement of the admitted F-DOC27/F-DOC32 provenance page. It records source-bound internal aliases from the exact corrected B1.10 `MOD_MvG_functions.f90` oracle and the exact model-dependent copy rules from `paramvg` into `cofgen`.

It does **not** claim that these aliases are all original user input keywords, and it does not infer input units from equations or familiar Mualem–Van Genuchten terminology.

## Controlling authorities

| Authority | Exact identity | Permitted use |
|---|---|---|
| Live canonical at branch start | `0d493886a53626bd32bf9247669d5a709391849e` | Documentation integration base |
| Frozen Status-A authority | `992a5c657bfe10a10100f92e0cb77c4825ae65b6` | Frozen review denominator |
| Frozen scientific production baseline | `50346642bd565f79134ea17d5462e544b354998c` | Scientific denominator |
| Frozen production tree | `3b085d7dea3d3f3fce42ad9d8f259a8350205846` | Production-tree denominator |
| Admitted F-DOC27 | PR #179, canonical `74051e113fcef19e021d69854f3ab99066eb30cb` | Existing partial provenance map and unresolved-field policy |
| Admitted F-DOC32 | canonical `0d493886a53626bd32bf9247669d5a709391849e` | Existing direct legacy aliases for rows 13:16 |
| B1.10 immutable `MOD_MvG_functions` payload | `reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64`, git blob `6cfcec4e38b02343ba48e7e6fb5d595158e19653` | Exact legacy source payload |
| B1.10 payload manifest | `reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.manifest.json`, git blob `c64942d2964bb67c200f973b76e05222ad73067f` | Decoding/provenance contract |
| Corrected decoded B1.10 source identity | SHA-256 `4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1` | Byte-verified oracle identity |
| B1.10 snapshot definition | `reference/swap-4.3.1/snapshots/B1.10.yml`, git blob `8d768f00d47224a663941f79bb2d35eacc66d16b` | Corrected-reference identity and SWAP-012 provenance |
| SWAP-012 patch | `reference/swap-4.3.1/patches/SWAP-012/fix.patch`, git blob `77f4b63689a6f72116280cbd019852b3b181e34a` | Exact corrected inverse-retention context |
| SWAP-013 parser patch | `reference/swap-4.3.1/patches/SWAP-013/fix.patch`, git blob `525ebdafb317b705a9ffd3055e1ee0cb54473526` | Exact B1.10 parser field names for `h0`, `ha`, `apar`, `omega_K`; not a complete parser listing |
| SWAP-009 PDI qualification harness | git blob `c49c46280b7f1479283eac94ba3611d468d7456f` | Qualified row 18:21 PDI labels/units for model 8 test material |
| SWAP-010 model-7 capacity gate | git blob `a0cda8063f9a1ed338d592e9a687dc9d6ef0490e` | Qualified relation `cofgen(17)=1-cofgen(16)` and model-7 row use |
| Official SWAP repository parser | `SWAP-model/SWAP`, `src/io/readswap.f90` at commit `c22bd832ddf3e53e330a552f5e31e74f183362d1` | Secondary corroboration of `paramvg` assignments only; not promoted to frozen B1.10 byte identity |

## Exact B1.10 pointer aliases

The byte-verified `set_cofgen_pointers` routine directly binds:

```text
1  -> wcr
2  -> wcs
3  -> ksatfit
4  -> alfamg
5  -> lambda
6  -> n
7  -> m
8  -> alfamgwet
9  -> h_enpr
10 -> ksatexm
11 -> relsatthr
12 -> ksatthr
13 -> alfa_2
14 -> n_2
15 -> m_2
16 -> omega_1
22 -> h_power
23 -> k_power
24 -> elas
```

Rows 17:21 deliberately have no global pointer aliases in `set_cofgen_pointers`.

## Exact B1.10 copy/activation rules

For `swsophy == 0`, `fill_cofgen` establishes:

```text
cofgen(1:12,node)  = paramvg(1:12,lay)                       ! all parameterized models
cofgen(13:17,node) = paramvg(13:17,lay)                      ! models 3,6,7,10,11
cofgen(18,node)    = paramvg(18,lay)                         ! models 5,7
cofgen(18:21,node) = paramvg(18:21,lay)                      ! models 8,9,10,11
cofgen(22:24,node) = paramvg(22:24,lay)                      ! all parameterized models
```

The same source identifies `iHWCKmodel`: 1 default MvG, 2 exponential, 3 bi-modal MvG, and 4:11 as eight PDI variants.

For `swsophy == 1` (tabulated soil hydraulics), only `cofgen(1:3)` are populated as residual-water-content placeholder, saturated water content and saturated conductivity; F-DOC33 must not present the 24-row parameter mapping as the table-mode input contract.

## Additional bounded provenance for rows 17:21

The exact B1.10 pointer routine supplies no aliases for rows 17:21. Additional qualification evidence may therefore be recorded only with its precise scope:

- SWAP-010 model-7 capacity gate constructs row 17 as `1 - row 16`; this proves the relation in that qualified model-7 material, not a global parser keyword.
- SWAP-009 model-8 PDI harness labels rows 18:21 as `|h0| [cm]`, `|ha| [cm]`, `PDI a`, and `omega_K` for the qualified model-8 material.
- SWAP-013 parser patch independently proves the legacy parser field names `h0`, `ha`, `apar`, `omega_K` and their validation context.
- The official SWAP repository parser at commit `c22bd832...` corroborates `paramvg(17)=1-omega_1` and `paramvg(18:21)=h0,ha,apar,omega_K`, but this external source is secondary corroboration, not the frozen B1.10 byte authority.

## Claim ceiling

Permitted:

- record exact B1.10 pointer aliases for rows 1:16 and 22:24;
- record exact B1.10 model-dependent copy/activation rules for rows 1:24;
- state that rows 17:21 have no `set_cofgen_pointers` global aliases;
- record the bounded model-7 relation for row 17;
- record the qualified model-8 PDI labels/units for rows 18:21, clearly marked as harness/parser corroboration rather than a complete B1.10 parser table;
- preserve unresolved original parser keyword/unit cells where no exact frozen binding exists.

Forbidden:

- treat every pointer alias as a user-facing input keyword;
- infer units for rows 1:16 or 22:24 solely from equations or conventional notation;
- promote the external `SWAP-model/SWAP` parser commit to frozen B1.10 byte authority;
- assign one universal semantic to row 18 without model context;
- claim all 24 rows are active simultaneously;
- change production, reference, tests, physics or numerical policy.

## Documentation verdict

`FULL_INTERNAL_ALIAS_AND_MODEL_ACTIVATION_REFINEMENT_SUPPORTED`
