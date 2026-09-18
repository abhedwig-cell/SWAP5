# ROM-0 close-gate reconciliation after F-ROM0TA3

## Purpose

This reconciliation prevents the successful fixed-resolution sample capability and the retained 0.0008 d trajectory candidate from being mistaken for complete ROM-0 closure.

It binds the current evidence back to the original ROM-0 close gates and to the ROM-0R successor preregistrations.

## Current gate state

### Ownership

**PASS_WITH_RESEARCH_SCOPE.**

F-ROM0TA3 uses a separate F-KT-owned Reference-floor candidate/commit type. It does not let research code publish arbitrary solver candidates through the ordinary committed-state API. Lineage, revision and committed time remain F-KT-owned.

### Reproducibility

**PENDING F-ROM0TA4.**

F-ROM0TA3 repeated complete executions bit-identically, but ROM-0 requires continuation/replay authority for the retained refined Reference candidate. F-ROM0TA4 is preregistered to compare uninterrupted and Restart-v1 split continuation at 0.0008 d with a fresh backend after restore.

### Conservation

**PASS for retained TA3 samples.**

Every successful F-ROM0TA3 sample has complete mass accounting and remains inside the frozen hard mass gate. Failed 0.0004 d samples are not retained as accepted states.

### Bidirectional reachability

**NOT YET CLOSED.**

The TA3 TOP_PLUS/TOP_MINUS matrix is a symmetric local top-flux perturbation around the R1 gravity-steady prescribed-qbot state. It proves two local perturbation directions, but it does not replace the ROM-0/ROM-0R requirement for lower-boundary pressure-head influence.

ROM-0R R2 explicitly states that the Reference floor remains incomplete because pressure-head lower-boundary coverage is unqualified and names R3 pressure-boundary preregistration as the next scientific phase after transient authority is available.

### Reference floor

**PARTIAL.**

F-ROM0TA3 supplies a complete 0.0016 versus 0.0008 d comparison for B01/B14 TOP_PLUS/TOP_MINUS over the common 0.0128 d horizon. The 0.0004 d level remains failed evidence and may not be replaced post hoc.

This does not yet satisfy the full original ROM-0 reference-floor matrix. In particular:

- lower-boundary pressure-head transient coverage is still absent;
- the preregistered 16x10 cm versus 32x5 cm vertical-resolution comparison has not been measured.

The temporal pair is therefore a bounded numerical-floor component, not complete ROM-0 floor closure.

### Production semantic mutation

**PASS_WITH_SCOPE.**

F-ROM0TA3 adds a research Reference-floor sample path in F-KT/FMR while leaving the ordinary canonical temporal transaction modes, Reference Richards solver/physics and canonical interval runtime unchanged. It is not an application runtime policy and has no production admission claim.

## Consequence of a future TA4 PASS

Even if F-ROM0TA4 proves exact restart/replay identity for the 0.0008 d candidate, ROM-1A remains blocked.

The evidence-driven continuation is:

1. return to the already preregistered ROM-0R sequence and define R3 lower-boundary pressure-head perturbations before execution;
2. qualify accepted upward/capillary and lower-boundary drying reachability using the Reference-floor sample authority;
3. complete the required vertical-resolution floor diagnostic without changing the frozen material/physical-domain rationale;
4. only then re-evaluate the six ROM-0 close gates and decide whether `PROCEED_TO_ROM1A` is justified.

No downstream ROM error threshold is selected by this reconciliation.
