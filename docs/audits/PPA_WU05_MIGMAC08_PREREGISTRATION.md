# PPA-WU05-MIGMAC08 covered hydrostatic rapid-drain reference

Date: 2026-10-05. Canonical base 52821447904244f738649086706a43565f0f00c8.
Local bb8061f02 matches canonical tree 6907db327ab27b54ae0b29789f8b44132ef064db.

Scope: remove MIGMAC06 adapter's blanket top_node==1 restriction for a typed
rigid covering layer with exactly zero static macropore capacity above top_node.
Require explicit rigid law selectors above that node before reference preparation.
Then the unchanged section-D per-cell source equation contributes zero there.
Hydraulic owner still supplies hydrostatic moisture; existing covering transfer
owner remains authoritative. No new coefficient equation or runtime/state owner.

Source macropore.f90 SHA256 f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f.
Covered top input comes from the independently admitted covering-layer matrix
transfer, not the surface-connected A9 forcing carrier. Tests must respect that
ownership seam, keep rigid cover crack volume zero and conserve whole-column water.

Gates: covered mixed-law Reference dry/wetting/two-domain rapid drainage,
source/adapter prepared coefficient versus supplied coefficient identity,
partial drain level, rejected smaller retry, A/B/A, accepted restart and O0/O2;
invalid cover law/capacity leaves configuration unchanged. Existing shared
MIGMAC02/03/04/05/06/07 cases plus A8/A10/MIGMAC01/PERCH20 preservation.
Unchanged pure constitutive/reference oracle evidence is inherited by exact
postimage comparison. No numerical tolerance changes.

Excluded: deforming/nonrigid cover reference geometry, new surface owners,
whole-model equivalence and alternative solvers. Keep broad migration incomplete
and frozen Status A unchanged.
