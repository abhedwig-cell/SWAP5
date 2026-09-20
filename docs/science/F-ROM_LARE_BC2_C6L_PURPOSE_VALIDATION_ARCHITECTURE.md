# F-ROM-LARE BC2-C6L purpose-validation architecture

## Decision

Purpose-dependent Layer-ROM research will proceed in a fixed order:

1. qualify a fresh high-resolution **surface-flux Reference**;
2. only then compare the already-frozen Layer-ROM ladder and placement controls;
3. treat ET/root uptake as a separate problem because prescribed extraction and predicted stress-dependent uptake are not the same claim;
4. defer long-horizon water-partition validation until surface and sink semantics are stable.

No new closure or representation is introduced by C6L.

## Why SURF comes first

The current evidence base is dominated by lower-boundary forcing. DYN0A did exercise prescribed top-flux changes, but it was a bounded mechanism/resolution laboratory rather than a blind high-resolution purpose frontier.

A new SURF workload therefore isolates upper-zone memory with:

- a 160-cm homogeneous column;
- free drainage below;
- no root sink;
- prescribed top-flux perturbations around the initial gravity-equilibrium flux;
- B01 and B14 materials;
- fresh histories frozen before Reference generation.

The high-resolution Reference must be qualified before any reduced response is interpreted. C5N's R512/R1024/R2048 plus T8/T16 pattern is reused as numerical-governance structure, not as response evidence.

## Frozen candidate family for later comparison

If the Reference hierarchy qualifies, the later candidate comparison may use only already-existing representations:

- R3, R4, R5, R6, R8, R12 and R16;
- P4_TOP_LOWER;
- U4 and U8;
- CURRENT_LAYER_FACE.

No new top-focused partition may be invented after looking at SURF response.

This is deliberate. The first question is whether the already-qualified representation frontier transfers to a surface-driven purpose, not whether a new partition can be optimized for it.

## Purpose views

Surface-driven profile/soil-moisture evidence must include at least total storage, 0-40 cm storage, 0-80 cm storage and mapped 10-cm profile error.

Drainage evidence must keep cumulative exchange, interval flux and history-wise signed bias separate.

Fast-event timing remains a diagnostic axis: drainage-response peak timing and root-zone storage-extremum timing may be reported, but no event threshold is treated as an application tolerance unless independently governed.

## ET and root uptake are a separate claim

The serialized Reference forcing already has a distributed `root_extraction_sink`, but existing LARE purpose runs set it to zero and the standard reduced runner has no distributed sink term.

Adding a conservative layer-integrated prescribed sink is straightforward from continuity, but a prescribed sink experiment would answer only:

> Can the reduced hydraulic state respond correctly when the extraction is already known?

It would not answer:

> Can the reduced model itself predict stress-dependent root uptake and ET?

Those claims must remain separate. A free-running ET/drought purpose requires a separately qualified root-uptake feedback contract.

## Long-term balance

Exact mass conservation stays mandatory, but it cannot establish correct long-term partitioning among storage, ET, drainage and recharge.

A later long-horizon purpose gate therefore needs all flux partitions reported separately and a horizon selected independently of candidate response.

## Next authority

C6M may preregister and execute **Reference qualification only** for fresh B01/B14 free-drainage surface-flux histories. No Layer-ROM response is authorized until the Reference numerical hierarchy passes its frozen quality gate.
