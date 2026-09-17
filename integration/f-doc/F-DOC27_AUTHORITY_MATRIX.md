# F-DOC27 authority matrix — B1.10 `cofgen` parameter provenance

## Decision surface

F-DOC27 is documentation-only. It reconciles the frozen Status-A default-MvG production provider with the immutable corrected B1.10 F-SI09 oracle lineage. It does not alter constitutive equations, parameter values, input parsing, solver policy or qualification.

## Controlling authorities

| Authority | Exact identity | Permitted use |
|---|---|---|
| Frozen scientific production baseline | `50346642bd565f79134ea17d5462e544b354998c` | Scientific denominator |
| Frozen production tree | `3b085d7dea3d3f3fce42ad9d8f259a8350205846` | Production-tree denominator |
| Default-MvG provider | `src/solver/mod_b110_default_mvg_provider.f90`, blob `fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6` | Exact executable `cofgen` dependencies and derived rows |
| Historical F-SI09 qualification branch | `work/f-si09-b110-constitutive-provider` at `0f9f84e6f98e43c4ada39f1a8d9b180b0f672330` | Immutable qualification/provenance evidence only |
| F-SI09 corrected B1.10 oracle | SHA-256 `4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1` | Reference formula/oracle identity |
| Oracle payload | `reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64`, blob `6cfcec4e38b02343ba48e7e6fb5d595158e19653` | Immutable compressed reference source |
| F-SI09 source resolution | `integration/f-si/F-SI09_SOURCE_RESOLUTION.json` | Exact source lineage and hash binding |
| F-SI09 provider contract | `integration/f-si/F-SI09_PROVIDER_CONTRACT.json` | Admitted profile and formula-binding limits |
| F-SI09 qualification | `integration/f-si/F-SI09_QUALIFICATION.json` | Bitwise qualification scope |
| SWAP-012 patch evidence | `reference/swap-4.3.1/patches/SWAP-012/fix.patch` | Source-local legacy names where present; not a complete row mapping |

## Reconciled findings

1. The frozen provider requires at least 24 supplied `cofgen` rows and allocates 42 rows internally.
2. Rows `25:42` are recomputed by the provider from supplied rows `1:24`; they are therefore derived working values, not independent inputs to this provider.
3. F-SI09 qualifies those derived rows and the admitted `theta(h)`, `C(h)` and `K(h,theta)` outputs bit-for-bit against the corrected B1.10 oracle under the contracted profile.
4. The corrected legacy oracle is repository-bound by exact hash, but is intentionally persisted as a compressed reference payload. The acquired governance, fixture and patch evidence does not provide a separate complete original input-field/name/unit to `cofgen(1:24)` table.
5. The SWAP-012 patch exposes legacy local names such as `thetar`, `thetas`, `alfamg`, `npar`, `mpar` and `h_enpr`, but the patch context does not establish a complete index-to-name mapping. These names must therefore not be projected onto rows solely by convention.

## Claim ceiling

F-DOC27 may document executable internal roles and exact derived-row dependencies. Original input names and units are shown only when directly bound by repository evidence. Missing mappings are marked `unresolved`.

It may not:

- infer conventional Mualem–Van Genuchten aliases from familiar equations;
- infer input units solely from dimensional consistency;
- describe provider-nondirect rows as globally unused;
- reinterpret the F-SI09 qualification beyond its admitted default-MvG profile;
- change production or reference semantics.

## Documentation verdict

`PARTIAL_PROVENANCE_MAP_REQUIRED`

The absence of a complete repository-visible original field/unit mapping is itself a traceability result. Preserving that uncertainty is preferable to fabricating a polished but unauthoritative parameter dictionary.
