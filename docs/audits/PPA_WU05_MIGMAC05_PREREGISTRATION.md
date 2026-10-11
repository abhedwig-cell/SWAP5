# PPA-WU05-MIGMAC05 mixed constitutive Reference qualification

Date: 2026-10-05. Preregistered before fixture edits.
Canonical base: da26f0f6ece2d6480b3169c9f53317809a8f3d1b.
Local 8c60a7a2f tree e5a0b87421b59946892e8a476a5556f6cfb52ba1 is identical.

Scope: existing typed per-compartment dispatch for Kim/regular Hendriks,
Kim/three-segment peat and rigid/Kim/peat profiles in serialized Reference
Richards. Include characteristic-point-prepared carriers, accepted history across
law interfaces, wetting displacement and supplied-coefficient two-domain rapid
drain composition. This is qualification of the existing implementation, not a
new layer, constitutive law, restart carrier or water owner.

Exact B1.11 macropore SHA256 f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f:
MPVOLUME uses Layer(ic) to select each constitutive law while its wetting rule
reads local/adjacent crack history across layer interfaces. SWAP5 uses synchronous
immutable accepted neighbor history; legacy in-place ordering is not reinstated.
Static matrix fractions remain the existing immutable carrier.

Gates: independent mixed-node numeric geometry values, dry/wet reversal,
accepted-history isolation and A/B/A; heterogeneous matrix fractions and law
selectors; actual Reference growth, contraction/displacement, rejected smaller
retry, A/B/A and accepted restart for each mixed family; two-domain rapid drain
with supplied admitted reference coefficients; byte-identical O0/O2 and existing
MIGMAC02/03/04 preservation through their original fixture cases. No tolerance
change and no production-source edits anticipated. If a production defect is
found, reconcile and requalify its affected admitted surface before admission.

Explicit exclusions: derivation of new mixed-law rapid-drain reference KD from
hydrostatic geometry, multiple/sub-compartment drains, ponding/runon ownership,
Ribasim/fixed-weir composition, field-scale/whole-model equivalence and new solvers.
Immutable A8/A10/MIGMAC01/PERCH20 evidence is inherited if production source and
those controlling runner postimages remain unchanged; changed shared A9 fixtures
must run their existing and new cases together.
