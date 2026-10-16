# PPA-WU05-MIGMAC06 hydrostatic rapid-drain reference construction

Date: 2026-10-05. Canonical base: 7a877af47144689bf8f9feb8c5485f6320dda137.
Local baseline 931c5c9c6 has identical tree c7bfc559fc9d8986224ec9ec56bedcae574b4e4a.

Scope: immutable preparation of existing rapid kd_reference from mixed-law
hydrostatic reference moisture. Exact B1.11 macropore authority SHA256:
f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f,
initialization section D. Hydraulic owner supplies watcon(ic, drain_level-z(ic));
no retention model or hydraulic state is added to the macropore owner.

Preserve source 0.01 cm node mapping, reference level min(0.75*level,level+10),
rigid barrier detection, 0.99 saturation cap when static domain ends above drain,
per-node shrinkage, geometry factor, static volume and main-domain fractions.
Reference KD uses no current crack history, wetting correction, matrix-area
multiplier or saturated-top fraction. Drain type1 behind a rigid barrier returns
zero connectivity. Runtime integration must not divide by zero: a zero-KD
preparation is a valid disconnected outcome, not an active zero-resistance route.

Gates: independent numeric reference construction for mixed laws, source-form
assembled oracle, rigid barrier and mapping boundaries, invalid shapes/values,
A/B/A immutable preparation, O0/O2. Reference growth/wetting, supplied versus
derived identical coefficient route, retry/restart preservation. Requalify
changed production dependency surfaces with original MIGMAC02/03/04/05 and
A8/A10/PERCH20 gates. No tolerances changed; no new state or water owner.

Excluded: multiple and within-compartment drain runtime, automatic retention
model selection, covering-layer composition, new surface ownership and whole-model
equivalence. Broad migration and frozen Status A claims remain unchanged.
