# MC-NUT01 historical named-field activation: bounded integration receipt (2026-10-17)

Owner: MC-NUT01. Existing PR #1280; candidate tested at `03f2298029a421f2052e4da0f082bc844996cc26`; base `6c3f59617fa11593ae69ead5eed7891a8ac66dab`.

## Precisely admitted boundary

- Explicit, opt-in `SWCROPSNM=1` / `SW_WOFOST=1` selector, not project-default activation.
- Strict named `name = numeric value` export of 26 historical initial-state/rate/boundary fields, no TTUTIL parser or complete original `.snm` file semantics.
- Eight historical FOM stores, biomass/humus and original ammonium (water plus sorption) / nitrate (water) initial mass conversion using the already-owned Soil-N state.
- Selected reference temperature, NH4 sorption, nitrification, denitrification, wetness, C-dissimilation, uptake and distinct lateral versus seepage concentrations bound to the existing reactive parameter owner.
- Explicit material-event reader and the typed Soil-N input bind atomically: invalid/missing/duplicate/overlong input must not publish a plan or committed N state.
- Existing actual Richards/reactive composition retained, including whole-N balance, rejected trial atomicity and opaque/native continuation checks.

## Evidence and strict limitations

Actual GitHub-hosted O0/O2 execution at head `03f2298029a421f2052e4da0f082bc844996cc26`, workflow run [39037181165](https://github.com/abhedwig-cell/SWAP5/actions/runs/39037181165): completed success, two native historical activation PASS and two Richards/reactive native PASS; raw archive artifact ID `12102861635` (31971305 bytes). The overlong-record negative test is exercised in the focused native driver. Previous runs 39035387508 and 39033868312 cover positive eight-pool application and negative incumbent preservation.

This is a **bounded typed/export-input capability**, not full original 4.3.1 Soil-N equivalence, and no complete mastercoverage capability is promoted. The original TTUTIL parsing, full project setup and default selector activation, full historical organic parameter-family interpretation, source-reference correction for `cNO3N_seep`, and the untested physical ranges remain open. The historical source defect is not silently preserved: laterally and bottom-supplied NO3 input are kept distinct.

The new named reader and route are additive. No physics rate equations, mass tolerances, WOFOST81 growth authority, restart codec, water solver, drainage or irrigation providers are changed. Broad F-CI, RossFast and highest-low-air tests not selected by dependency impact.

The post-test change adding this receipt only documents observed evidence; none of the seven implementation/test/workflow files that were executed at the pinned commit is changed. Admission requires actual PR merge SHA and comparison to canonical after merge.
