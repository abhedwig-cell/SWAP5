# F-ROM-LARE BC2-C6K purpose-dependent sufficiency synthesis

## Decision

The Layer-ROM research program now adopts **purpose-dependent sufficiency** as its default direction.

The accumulated evidence does not support a universal minimum state count or a universal very-low-dimensional replacement for Richards. It does support a different and scientifically useful conclusion: representation requirements depend on hydrological output, material, lower-boundary semantics, time horizon and vertical state placement.

C6K is a read-only synthesis. It creates no new hydrological response and no new ROM family.

## What is already demonstrated

Groundwater-output fidelity can require materially fewer retained states than full profile/state fidelity on the same bounded workload.

For B01 fixed-water-table blind validation, C4R found R4 to be the minimum reduced member crossing the frozen R2 and FMC groundwater vector, while R12 was required once mapped 10-cm profile fidelity was retained.

That minimum is not stable across horizon or material. On the B01 one-day prospective test, C4V moved the minimum persistent groundwater member to R8. On B14 fixed-water-table transfer, C4X found groundwater crossing already at lower-zone R3, while profile-inclusive crossing against FMC began at R8.

State placement is therefore part of the representation. Uniform U4/U8 do not inherit the lower-zone-focused frontier simply because they have the same state count.

Dynamic prescribed-head evidence is more restrictive. B01 C4Z retains an R2-relative reduced frontier, but the R2 comparator itself is weak on reversal timing. For B14 with qualified high-resolution Reference controls, C5N finds no reduced R3-R12 high-resolution frontier under CURRENT_LAYER_FACE even though the placement advantage replicates.

The robust conclusion is not “R3”, “R8” or “R12”. The robust conclusion is **purpose-, material-, boundary- and horizon-dependent sufficiency**.

## Evidence-only purpose envelope

The current repository supports three different evidence categories.

**Groundwater exchange/output:** substantial blind and prospective comparator-relative evidence exists. It is strong enough to select candidates for further purpose-specific validation, but not to declare application acceptance.

**Profile/soil state:** existing evidence repeatedly requires more vertical information than groundwater-output vectors. The fixed-boundary B01/B14 tests support this distinction, but no atmosphere/root-uptake drought application has yet been qualified.

**Surface-driven and long-horizon purposes:** dedicated evidence is still absent. Long-term water balance, evapotranspiration/root uptake, operational drought, fast-event decision thresholds and scientific extreme/process inference must not inherit acceptance from the lower-boundary-driven laboratories.

Exact mass conservation remains mandatory everywhere. It does not by itself prove correct seasonal partitioning among storage, ET, drainage and recharge.

## Groundwater application boundary

C4U remains authoritative. Real groundwater application acceptance cannot be inferred from C4R/C4T error magnitudes.

It requires an externally governed head/drawdown requirement (H_{app}) plus an independently governed temporal allocation or direct temporal error budget, with immutable provenance.

So the current purpose matrix is a **scientific evidence map**, not an application-acceptance table.

## Computational value

C4T provides a bounded shared-host cost-fidelity signal: LARE R3-R8 were cheaper than fine R16 on that workload while occupying the measured frontier, whereas R12 was more expensive than R16.

This is useful design evidence, not a portable speedup or production-performance claim. Computational value may only be revisited after a purpose-specific hydrological gate is independently closed.

## Research consequence

The default next task is no longer to invent another universal closure.

C6L should instead design the minimum new fresh-blind workloads needed to close the evidence gaps in the purpose matrix. In particular, ET/root uptake and operational soil-moisture/drought questions require a genuinely surface-driven workload; long-term regional water balance requires a longer horizon and explicit flux partition diagnostics.

No new representation, tolerance or closure may be selected from exposed C4-C6 response errors.
