# F-WOF05 reference resolution

## Scope

F-WOF05 admits only the smallest crop-host composition that can be defended without resolving uncertain leaf-reallocation semantics: stem biomass is transferred to storage organs through the already-qualified F-WOF04 flux component. Leaf reallocation remains fail-closed.

## Source-bound findings

1. PCSE 6.0.13 at `0d51ae84f405fd9b061222f2a0130e5351f460df` defines WOFOST73 reallocation rates and cumulative caps in `wofost73.py`.
2. WOFOST73 imports the ordinary `WOFOST_Leaf_Dynamics` class.
3. The historical proportional leaf-cohort reduction added in commit `3648114b11900222adcec8ae8349503f5c346b05` is present in the N-aware leaf implementation used by WOFOST81. It applies reallocation after leaf death and ageing, before new leaf growth, by proportionally reducing surviving cohorts.
4. PCSE commit `ea9b2c806c7f1c67c2fc7fa7a407608ddcef0d98` explicitly fixed WOFOST73 reallocation to align top-level logic with WOFOST81. Commit `70e731d00fd0f4837852b458844e8042bd3343ca` later fixed another WOFOST73/81 leaf-reallocation bookkeeping error.
5. The ordinary leaf class imported by WOFOST73 still does not provide a source-bound leaf-cohort transformation equivalent to the N-aware path.
6. The proportional reference path contains an edge condition `REALLOC_LV < sum(LV)` rather than `<=`; reproducing it blindly could violate hard dry-matter conservation when requested reallocation equals the surviving leaf biomass.
7. Official WOFOST73 wheat and rapeseed parameterizations keep biomass reallocation disabled.
8. The pinned WOFOST81 winter-wheat parameterization provides a safe active stem-only vector: `REALLOC_DVS=1.5`, `REALLOC_STEM_FRACTION=0.2`, `REALLOC_LEAF_FRACTION=0`, `REALLOC_STEM_RATE=0.0415 d-1`, `REALLOC_LEAF_RATE=0`, `REALLOC_EFFICIENCY=0.95`.
9. Legacy SWAP 4.3.1 maintains independent potential and actual WOFOST states. Reallocation caps and cumulative transfers must therefore be independent for the two tracks.

## Decision

F-WOF05 admits stem-only composition with these conditions:

- potential and actual tracks have separate physical biomass and separate F-WOF04 reallocation bookkeeping state;
- the same immutable parameter set and crop DVS may be consumed by both tracks;
- each trial starts from committed track state and returns candidate state without mutating the committed input;
- stem transfer is subtracted from living stem biomass;
- efficiency-adjusted transfer is added to storage-organ biomass;
- conversion loss is explicit and the reallocation-only dry-matter balance must close;
- any `leaf_fraction > 0` or `leaf_rate > 0` is rejected before a physical endpoint is proposed;
- durations other than the qualified one-day crop-process cadence remain rejected by the F-WOF04 child contract;
- if either potential or actual track fails, the pair candidate is fail-atomic and remains equal to the committed pair state.

## Status

`ADMITTED_STEM_ONLY_REALLOCATION_COMPOSITION_LEAF_FAIL_CLOSED`

This is not an admission of full WOFOST73, WOFOST81 nitrogen physics, or leaf reallocation.
