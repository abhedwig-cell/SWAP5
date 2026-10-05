# PPA-WU05-MIGMAC08 rigid covered reference preparation

Date: 2026-10-05. Status: LOCAL_QUALIFICATION_COMPLETE_PENDING_CANONICAL_ADMISSION.
Canonical base: 52821447904244f738649086706a43565f0f00c8.

B1.11 macropore geometry section E deletes static volumes and domain proportions
above IcTopMp. This bounded typed rigid route yields the same zero reference
contribution independently of unused above-top domain-fraction padding. It does
not infer a physical matrix shrinkage law from that padding.

The reference-KD configuration adapter admits a rigid covering layer with exactly
zero static macropore capacity in all cells above the active top node. Explicit
rigid law selectors are required there. Existing source section-D reference
geometry then contributes zero in those cells without inventing a cover crack
law, separate reference coefficients, hydraulic provider or persistent state.
The hydrostatic moisture still comes from the hydraulic owner.

Covered trials use the existing covering-layer matrix-transfer owner. The
surface-connected A9 precipitation forcing carrier is absent for these trials.
This respects the source/architecture distinction between water entering surface
cracks and water crossing matrix material above a buried macropore domain.

Invalid nonrigid cover selectors or positive covered static capacity fail closed
before the adapter changes its KD. Existing supplied coefficients remain valid.
The covering reference scope is rigid material only; nonrigid covering reference
geometry requires a separate source reconciliation and is not silently admitted.

An initial fixture failure is retained: the invalid-cover probe wrote its expected
false outcome into a global logical aliased to the initialization output argument.
The physical configuration itself was valid and its reference KD was computed.
Probe outcomes now use a separate local logical. A subsequent replay fixture
validation failure exposed its neutral history top-water node still set to 1
above the covered top node 3. Neutral history and sorptivity templates now use
the actual top node. These are test-fixture topology/isolation repairs; no production equation or numerical tolerance was changed for the failure.

All eight controlling final gates exit zero at O0/O2. Covered mixed-law dry,
wetting/displacement and two-domain partial rapid-drain trials pass, including
prepared characteristic-point carriers. Supplied and adapter-derived coefficients
produce byte-identical Reference trials. Reject/smaller retry, A/B/A and accepted
restart pass. Invalid-cover guard probes leave KD unchanged. A8/A10/MIGMAC01/
PERCH20 and original shared MIGMAC02/03/04/05/06/07 runtime cases pass.

The independent covered coefficient 0.2068154836193743352226502591721680 agrees
with the unchanged assembled B1.11 section D with zero static/domain capacities
in the covered cells. The baseline uncovered source oracle also still passes.
Unchanged pure constitutive/fit/VOLUNDR evidence is inherited by exact postimage
comparison, rather than claimed newly rerun.
Exact qualification authority: `integration/audits/PPA_WU05_MIGMAC08_QUALIFICATION.json`.
The frozen Status A boundary is unchanged; broad migration is still incomplete.
Excluded: nonrigid cover reference preparation, new surface ownership,
whole-model equivalence and alternative solvers.
