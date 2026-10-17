# MC-NUT01 residue ages to B1.12 crop/Soil-N owner (2026-10-17)

Base canonical 5864bc10a52d853cc10c56a378afcbae0d019158; PR #1286. SWAP431 source: management_soil.f90 lines 216-240.

The source-derived four-age profile binds to the existing three-organ pending senescence policy and four-organ harvest policy. WOFOST1 defaults root1.27, leaf0.99, stem1.27 and storage1.27. Invalid ages outside the admitted physical intersection [0.67,100], absent harvest and wrong WOFOST selector are rejected without altering the original configuration. No second owner, mass policy, clock or restart codec.

Actual native production gate: https://github.com/abhedwig-cell/SWAP5/actions/runs/39044984604, at implementation SHA 461f61778114e304662a89e34d309ac92ee3b383: completed SUCCESS, O0/O2 B1.12 split and coupled crop/soil-N day native suite. Artifact 12105706103, 2655847 bytes. Both original and sourced pending/harvest policy paths exercised; existing mass, actual owner and crop restart routes remain intact. Code is additive to crop-policy binding; no groundwater solver change. Broad F-CI and unrelated numerical stress not selected by impact.

Boundaries: this is an explicit crop policy adapter, not automatic project startup consumption or original TTUTIL SNM compatibility; whole crop lifecycle and wider NUT capability rows still open. No complete mastercoverage promotion. Admission document-only postimage does not alter tested production source.
