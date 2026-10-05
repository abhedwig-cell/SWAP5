# PPA-WU05-MIGMAC07 within-compartment rapid-drain geometry

Date: 2026-10-05. Canonical base: 8125ba01b5bfd7377c721caa1105d68e24e77183.
Local f77354656 matches canonical tree 13673c18207fe648684b89c4123052d67647eac1.

Source: exact reconstructed B1.11 macrorate.f90 VOLUNDR. This function already
interpolates the partially intersected compartment as a uniform volume density.
The A10 aligned-only boundary is a first-production restriction, not a missing
source equation or a reason to invent a new subcell state.

Scope: one explicit drain level anywhere inside the existing surface-based column.
Derive volume below drain from overlap with current main-domain compartment
capacity. Preserve aligned arithmetic, snap within the existing 1e-10 cm boundary
tolerance, retain active-domain truncation and one external rapid-drain mass owner.
Remove only the aligned-level rejection. No new persistent state or ledger.

Gates: exact source VOLUNDR assembly and independent heterogeneous-grid volume
values, boundary/partial/active cutoff/invalid inputs; O0/O2. Actual Reference
partial-drain trial/reject/retry/ABA/restart and mixed-law dynamic wetting/drain
composition, including prepared reference KD. Rerun original A8/A10/MIGMAC01/
PERCH20 and MIGMAC02/03/04/05/06 gates for changed dependency surface.

Excluded: multiple rapid-drain levels, new surface owners, partial vertical
subcell constitutive profiles, covering-layer reference preparation, whole-model
equivalence and alternative solvers. Source uniform-compartment reconstruction
is qualified, not an assertion of continuous-field exactness. Frozen Status A
and incomplete broad migration claims remain unchanged.
