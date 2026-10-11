# F-DOC22 Drainage-v1 formulation authority matrix

Date: 2026-09-17

F-DOC22 completes reviewer-facing formulation documentation for the seven Drainage-v1 families that F-DOC21 deliberately left at capability level. This file is a documentation-control artifact. It creates no new drainage physics and changes no admission denominator.

## Frozen review denominator

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- F-DOC22 start canonical: `356742cb2a24b3335b0eae48d7d02d6194ce04ef`

## Drainage-v1 completion authority

The immutable completion artifact is:

- branch: `work/f-pm19-drainage-v1-authoritative-100-percent-completion`
- file: `integration/f-pm/F-PM19_DRAINAGE_V1_FINAL_COMPLETION.json`
- blob: `f4ddf0b9ed945ccb6f8a66c4611de624d10dc4a8`

That artifact is not mirrored at the same path on the F-DOC22 start canonical tree. Documentation must therefore cite it as a branch-pinned immutable authority, not as a current-canonical file path.

F-PM19 freezes eight variants and records all eight `PASS_COMPLETE`. F-DOC22 does not alter that denominator.

## Variant claim ceilings

| Variant | Scientific / formulation authority | Frozen implementation authority | Publication ceiling |
| --- | --- | --- | --- |
| restricted single-level linear response | F-VQ44 plus F-PM19 completion chain | `src/process/mod_drainage_process.f90` | Already documented in `docs/science/drainage.md`; retain unchanged |
| restricted positive single-level DIVDRA spatial distribution | F-CI32/F-CI33/F-CI36 as identified by F-PM19 | `src/process/mod_drainage_spatial_distribution.f90`, blob `1f538174...` | Explain positive scalar-to-node partition, transmissivity weighting, exact closure correction and explicit low-magnitude/domain bounds; do not invent reverse-flow distribution |
| DRAMET=1 tabulated response | F-VQ40, qualified closed | `src/process/mod_drainage_tabulated_response.f90`, blob `738f57c3...` | Publish exact piecewise-linear/clamped response, knot derivative nonclaim and explicit one-point-zero-depth fail-closed path |
| DRAMET=2 Hooghoudt family | F-VQ38, qualified closed | `mod_drainage_hooghoudt_ipos1_response.f90` `89f26e2d...`; `mod_drainage_hooghoudt_equivalent_depth.f90` `6b7b2bb1...`; `mod_drainage_hooghoudt_ipos23_response.f90` `5637ddb4...` | Publish IPOS1, IPOS2 and IPOS3 equations, equivalent-depth branches, B1.10 cutoff sidedness and stable-branch sensitivities |
| DRAMET=2 Ernst family | F-VQ38, qualified closed | `mod_drainage_ernst_ipos45_preparation.f90` `fa1d5d40...`; `mod_drainage_ernst_ipos45_response.f90` `b00ef0ae...` | Publish IPOS4/IPOS5 prepared resistances, vertical branch resistance, response equation, interface-kink derivative bound and negative-radial-resistance treatment |
| empirical interflow drainage side | F-VQ42, qualified closed | `src/process/mod_drainage_empirical_interflow_response.f90`, blob `eb53096b...` | Publish active power law, inactive branch and activation tangent semantics; negative-side DRAMET3 infiltration remains excluded |
| multi-level drainage aggregation | F-VQ43, qualified closed | `src/process/mod_drainage_multilevel_aggregation.f90`, blob `70d35512...` | Publish deterministic level-order sum and conservative derivative-unavailability composition; do not claim the dynamic scalability extension as historical equivalence |
| restricted fixed-weir transactional surface-water runtime | F-VQ59 plus F-CI52/F-CI52P as identified by F-PM19 | `src/process/mod_restricted_fixed_weir_surface_water.f90`, blob `16da4f6e...`, plus transaction runtime | Publish level-storage mapping, supply rule, rating relation, exact mass-equation discharge, separate rating residual and transactional ownership; do not widen to arbitrary surface-water control |

## Cross-cutting rules

1. A formula is documented only where scientific qualification and frozen source identity agree.
2. Local `signed_soil_to_drain_rate` or `soil_to_drain_rate` conventions are process-local. Normalized verification accounting still uses positive into the accounting domain.
3. Undefined derivatives at knots, activation points or interface kinks remain undefined. Documentation must not smooth them.
4. The scalar drainage transfer remains the authoritative physical transfer where spatial distribution merely partitions that transfer over nodes.
5. An unavailable derivative must not erase an otherwise valid mass transfer.
6. Fixed-weir rating-law residual is numerical evidence, not permission to relax the exact water-balance identity.
7. Fully implicit drainage-response coupling is not an F-DOC22 or Drainage-v1 claim.
8. No formula on this page admits options outside the fixed eight-variant denominator.

## Publication disposition

Authority is sufficient for a bounded technical-reference page covering all seven previously deferred families. The principal remaining documentation gap after F-DOC22 is not missing Drainage-v1 equations, but broader historical option coverage outside the frozen denominator and any future dependency changes that would require new preservation evidence.
