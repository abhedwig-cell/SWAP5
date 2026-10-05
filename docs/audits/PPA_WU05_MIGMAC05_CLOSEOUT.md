# PPA-WU05-MIGMAC05 mixed constitutive Reference closeout

Date: 2026-10-05. Status: CANONICAL_PRODUCTION_ADMITTED_CLOSED.
Canonical base: da26f0f6ece2d6480b3169c9f53317809a8f3d1b.

The existing per-compartment dispatcher qualifies mixed Kim/direct Hendriks,
Kim/three-segment peat and rigid/Kim/peat profiles. No production source,
physical interface, mass owner or restart carrier changed.

Independent heterogeneous matrix-area capacity values, dry/wet reversal,
accepted-history isolation, A/B/A and active-node cutoff pass. Reference runtime
passes dry growth, wetting displacement into matrix storage, rejected smaller
retry, A/B/A and accepted restart for mixed families. Characteristic-point
prepared Kim and positive/negative-P peat carriers also pass. The existing
two-domain rapid-drain route composes with mixed profiles using supplied admitted
coefficients; this does not qualify new mixed-law reference KD derivation.

Both controlling gates exit zero and produce identical O0/O2 results. Original
MIGMAC02/03/04 shared runtime cases pass on the changed A9 fixture postimages.
All other 32 preceding manifest postimages remain identical, including production
and A8/A10/PERCH20 owning tests. Their immutable qualification is inherited;
those gates are not claimed newly rerun. Exact 38-file manifest and receipts:
`integration/audits/PPA_WU05_MIGMAC05_QUALIFICATION.json`.

No numerical tolerance was changed. No new physical negative finding arose.
Remaining scope includes new mixed-law reference KD construction, multiple or
within-compartment drains, additional surface owners, whole-model equivalence,
ambiguous fitting and other solvers. Broad migration remains incomplete and the
frozen Status-A denominator is unchanged.

## Canonical admission

PR #1022 merged qualified tree `a789af124bfd8d487c15c9cdf28c9d1b5ebf0e0c`
at `be067df630e3efd21a43e3afa9c9e542d31a513b`. Published qualified commit:
`6e1520ecd0e12e57f86e7028b5d29b44fb404514`. Merge comparison has no changed files.
All 38 source/test postimages remain exact; closeout changes documentation only.
