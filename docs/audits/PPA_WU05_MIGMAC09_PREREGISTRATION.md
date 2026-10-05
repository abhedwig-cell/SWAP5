# PPA-WU05-MIGMAC09 source covering compartment mask

Date: 2026-10-05. Canonical base 5e696aeb42ad22ca05ac844115cc82f95bf789ec.
Local baseline 9e1ca31eb matches canonical tree 70117d7c94fa4bb5407cc0e678afd54ffd07aba4.

Source macropore.f90 SHA256 f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f.
Section E zeros all above-IcTopMp static volumes and domain fractions; MPVOLUME
starts its dynamic loop at IcTopMp irrespective of the covering soil shrink law.
Section D multiplies its reference geometry by the zero domain fraction.

Contract: optional dynamic-profile top_node defaults to 1; covered cells are
excluded before constitutive evaluation and remain zero. Nonzero accepted dynamic
volume above top is invalid and must never mutate accepted authority. Production
provider passes its actual geometry top. Reference preparation requires exactly
zero static volume and every domain fraction above top, replacing the narrower
rigid-law restriction. Typed soil configuration remains validated.

Gates: pure dynamic, constitutive, fit, mixed geometry and reference KD O0/O2;
exact source section-D nonrigid covered oracle; all prior shared MIGMAC02-08 plus
nonrigid covered mixed Kim/peat Reference dry/wetting/partial two-domain drainage,
prepared fit carriers, supplied/derived KD identity, retry/A-B-A/restart O0/O2.
Requalify A8/A10/MIGMAC01/PERCH20 affected runtime dependencies. Docs strict build
and postimage manifests precede canonical admission and closeout.

No new physics, state owner, surface forcing owner, solver policy or tolerances.
Existing covering matrix transfer remains authoritative. Broad migration and
whole-model equivalence remain incomplete; frozen Status A is unchanged.
