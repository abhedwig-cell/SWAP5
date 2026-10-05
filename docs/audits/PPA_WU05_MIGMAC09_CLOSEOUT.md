# PPA-WU05-MIGMAC09 source covering compartment mask

Date: 2026-10-05. Status: QUALIFIED_PENDING_CANONICAL_ADMISSION.
Canonical base: 5e696aeb42ad22ca05ac844115cc82f95bf789ec.

The pinned B1.11 source does not construct macropore cracks in a covering layer,
even when its soil shrink selector is nonrigid. Initialization section E zeros
static volume and all domain fractions above IcTopMp. MPVOLUME starts its dynamic
loop at IcTopMp. Section D multiplies reference geometry by the domain fraction.
Consequently, the remaining covering task was source compartment masking, rather
than an additional covering crack law or a new reference coefficient equation.

The pure dynamic-profile API now accepts optional top_node, defaulting to 1 for
existing callers. The production inner provider supplies the actual geometry top.
Covered geometry and subsidence remain zero; nonzero accepted covered crack volume
is rejected without changing accepted history. The reference adapter requires
exactly zero covered static volume and every covered domain fraction. This
replaces MIGMAC08's narrower explicit-rigid-selector condition. Typed soil laws
still undergo configuration validation. Supplied coefficients retain their owner.

Existing covering-layer matrix transfer remains the covered-input owner. The A9
surface precipitation carrier is absent in covered tests. No new persistent state,
water owner, solver policy or numerical tolerance is introduced. Full Richards
remains the production reference path, with trial/accept/retry/restart boundaries.

The independent section-D source oracle checks nonrigid covering soil with zero
macropore-domain masks. Its reference coefficient is
0.2068154836193743352226502591721680, identical to the rigid covered case.
The exact assembled source runs at O0/O2, alongside independent pure geometry
and reference tests. Shared Reference tests exercise Kim/direct peat, Kim/segment
peat and rigid/Kim/peat beneath nonrigid cover, dry growth, wetting displacement,
partial two-domain rapid drainage, prepared parameter carriers, supplied/derived
KD identity, rejected smaller retry, A/B/A and accepted restart.

Initial failed evidence is retained in qualification: the exact-zero origin
check triggered the strict compare-reals compiler warning. A relational absolute
zero guard preserves its exact requirement without relaxing tolerance. A covered
two-domain fixture overwrote zero fractions while assigning 0.3/0.7 proportions;
the mask is now applied after assigning those active-domain proportions.

All seven controlling gates exit zero. Pure geometry/constitutive/fit/reference,
provider and all shared MIGMAC02-09 Reference gates pass at O0/O2. A8/A10/
MIGMAC01/PERCH20 preservation passes against the final postimage. Both docs gates
pass, and all 159 pinned source/test postimages are reconciled.

Controlling evidence: `integration/audits/PPA_WU05_MIGMAC09_QUALIFICATION.json`.
Canonically admitted state is controlled by the work-unit status record. Frozen
Status A remains unchanged. Wider source-relevant surface compositions and
whole-model equivalence remain outside this scope; broad migration is incomplete.
