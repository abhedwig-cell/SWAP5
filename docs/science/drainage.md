# Drainage

This page documents the scientific and accounting meaning of the bounded Drainage-v1 capability admitted for the SWAP5 Status-A review baseline. It does not replace the capability-specific F-PM and F-VQ qualification records and does not widen the frozen Drainage-v1 denominator.

## Scientific role

Drainage removes water from the soil/groundwater system represented by a SWAP column toward an external drainage system. In accounting terms, accepted drainage is an outward external water transfer from the column domain.

The process representation is intentionally separated from transaction ownership. A drainage evaluator may calculate a candidate transfer during a trial, but only the transfer belonging to the accepted interval may be booked as committed water loss.

## Frozen Drainage-v1 denominator

F-PM19 closes the unchanged eight-variant Drainage-v1 denominator established earlier by F-PM13. The qualified denominator contains:

1. restricted single-level linear-resistance drainage response;
2. restricted spatial distribution / positive single-level `DIVDRA`;
3. `DRAMET=1` tabulated drainage response;
4. `DRAMET=2` Hooghoudt response family;
5. `DRAMET=2` Ernst response family;
6. empirical interflow drainage-side response;
7. multi-level drainage exchange aggregation;
8. restricted fixed-weir transactional surface-water runtime.

F-PM19 records all eight as scientifically qualified and runtime-qualified or preserved on its controlled postimage, with hard-mass, rollback, restart, MultiSWAP and diagnostic checks in the supporting chain.

This list is the v1 review denominator. It is not a claim that every drainage option in the historical SWAP family is included.

## Restricted single-level linear response

The frozen production baseline contains an explicit single-level linear drainage evaluator in `src/process/mod_drainage_process.f90`.

Let

```text
h_gw    = groundwater level
h_drain = drain head
R_drain = positive drainage resistance
```

and define

```text
delta_h = h_gw - h_drain
```

For `delta_h > 0`, the evaluator returns a nonnegative soil-to-drain transfer rate

```text
q_drain = delta_h / R_drain
```

with local derivative

```text
dq_drain / dh_gw = 1 / R_drain
```

For `delta_h < 0`, this restricted response returns zero transfer. At exact equality the transfer is zero and the evaluator marks the activation kink, so a derivative is deliberately not claimed there.

This is a one-way restricted response. The absence of reverse flow in this evaluator must not be generalized into a claim about every historical drainage formulation.

## Detailed formulations for the other seven families

F-DOC22 reconciles the exact frozen source identities with the variant-specific independent qualification authorities and publishes the equations and branch rules in [Drainage-v1 formulations](drainage-formulations.md).

That page covers:

- positive single-level `DIVDRA` spatial partitioning;
- `DRAMET=1` tabulated response;
- `DRAMET=2` Hooghoudt `IPOS=1..3`;
- `DRAMET=2` Ernst `IPOS=4..5`;
- empirical interflow drainage-side response;
- deterministic multi-level exchange aggregation;
- restricted fixed-weir surface-water storage, supply and discharge.

The formulation page keeps branch kinks, singular tangents, fail-closed degenerate cases and exact mass-booking rules explicit. It does not infer equations or options merely because they occur in historical SWAP material.

## Interaction with the soil-water balance

Drainage is a sink from the soil-column accounting domain. A nonnegative process-local `soil_to_drain_rate` therefore represents outward water transfer, not positive water entry.

At the normalized verification layer the same accepted transfer is represented with the external-accounting convention, where inflow is positive and outflow is negative. The adapter/accounting layer owns that sign translation.

The physical transfer must be booked once. Process diagnostics, drain-level attribution and mass-ledger records may describe the same transfer, but they do not create additional water losses.

See [Water balance, signs and units](water-balance-and-conventions.md).

## Transaction, restart and MultiSWAP meaning

The Drainage-v1 completion authority is stronger than a set of unit-level response checks. F-PM19 records that its frozen denominator is covered for:

- transaction-safe runtime composition;
- hard mass accounting;
- rollback of rejected work;
- restart behaviour;
- serialized MultiSWAP isolation and order-independence checks;
- explicit diagnostics;
- current-postimage preservation within that qualification chain.

These claims remain bounded to the exact admitted v1 denominator and protected dependency surface.

## Fully implicit coupling is not part of the v1 completion claim

F-PM19 explicitly records that fully implicit drainage-response coupling into the nonlinear soil-water solve is **not** a Drainage-v1 exit requirement. The v1 completion claim therefore cannot be used to infer a stronger monolithic solver formulation.

Likewise, no new reverse-exchange law, new drainage equation or unstated legacy behaviour is admitted by this page.

## What this page does not establish

This page does not claim:

- all historical SWAP drainage options;
- unrestricted reverse drain-to-soil exchange;
- a universal unit convention independent of the owning process/caller contract;
- fully implicit drainage coupling as a v1 requirement;
- new drainage physics beyond the frozen eight-variant denominator;
- preservation after an unqualified future change on the drainage dependency surface.

## Traceability

The principal authorities used here are:

- frozen scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`;
- `src/process/mod_drainage_process.f90` for the restricted single-level linear response;
- branch-pinned F-PM19 completion authority `work/f-pm19-drainage-v1-authoritative-100-percent-completion`, file `integration/f-pm/F-PM19_DRAINAGE_V1_FINAL_COMPLETION.json`, blob `f4ddf0b9ed945ccb6f8a66c4611de624d10dc4a8`;
- `integration/f-doc/F-DOC22_AUTHORITY_MATRIX.md` for the formulation-level authority reconciliation;
- [Drainage capability review](../capabilities/drainage.md) for the bounded Status-A capability statement;
- [Status-A traceability](../status-a/TRACEABILITY.md) for current review authority and preservation context.

The F-PM19 completion artifact is not mirrored at the same path in the current canonical `integration/f-pm` directory. It is therefore cited by immutable branch and blob rather than presented as a current-canonical file.

## Post-Status-A signed ordinary DIVDRA successor (16 October 2026)

MC-DRAIN01 extends the existing explicit single-level distribution/runtime contract
to negative soil-to-drain rates with frost OFF and `SWDIVDINF=0`. Positive rates
remove water; negative rates supply water from the external drainage system.
The signed adapter invokes the unchanged admitted positive partition on the
absolute rate, then reverses the nodal orientation. It introduces no scalar
response law, water store, solver policy or restart schema. The caller retains
ownership of the explicitly supplied immutable hydraulic view and scalar.

The existing source/sink and accepted transaction ledger book the final nodes
once. Nodal attribution is not another external transfer. Mode-2 constant-face
trials independently check `storage_change = -q * duration` when top and bottom
throughflow cancel; mode-7 trials retain the existing free-drainage owner.
Qualification uses O0/O2 production contracts, 24 signed Richards compositions,
four real reject/replay/empty-registry restart controls and column isolation.
The hard column mass bound is 1e-12 cm; the existing nodal roundoff bound is
1e-14 cm. Numerical continuation uses the already admitted temporal-history
state and fixed-flux top provider, not the earlier unfinished test fixture.

The versioned recovery/admission authority is
`integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json`; its source-bound
archive and verifier define the exact qualified postimage. Only
`SW431-DRAIN-DIV-SIGNED` is eligible for closure. Separate infiltration,
interacting multilevel partitions, altered discharge-layer bounds and native
DRAMET3/OWLTAB remain separate ledger entries. The frozen Status-A denominator
above is unchanged.

## Post-Status-A interacting ordinary DIVDRA successor (16 October 2026)

Canonically admitted MC-DRAIN01 PR1109 extends the explicit serialized request with paired
`distribution_parameter_refs(:)` and `scalar_transfers(:)` for more than one
level. Both vectors are required together; their lengths must match. Scalar
request fields must remain at their zero defaults when vectors are supplied.
All levels share exactly the same grid, saturated conductivity and anisotropy;
the drain spacing is level-specific. The original single-level request remains
available. This is an explicit forcing/partition interface, without a new
response law or a persistent state owner.

With frost OFF, `SWDIVDINF=0`, `SWDISLAY=0` and no highest-interflow override,
B1.11 orders active levels by descending drain spacing. Cumulative absolute
`q * spacing` determines the nested transmissivity and discharge-layer bottoms;
the quarter-spacing/anisotropy depth cap is applied per level. Each resulting
nodal row retains its own signed authoritative scalar. Zero levels contribute
nothing; nonzero rates at or below the legacy `1e-10` activation seam reject
without publication. The existing positive and signed single-level bodies
remain byte-exact.

Each positive nodal rate removes soil water and each negative rate adds it.
Opposing levels can have zero net external transfer while changing the spatial
forcing. Level attribution creates no second external booking. Preflight checks
every active column before materialization; the existing runtime discards
materialized scratch after acceptance or rejection. Committed physical state,
temporal history and restart remain owned by the admitted runtime.

The existing recovery record
`integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json`, phase
`multilevel_phase_20261016`, freezes the exact admission conditions and links
O0/O2 original-source/literal partition, hard mass, rejection/replay,
empty-registry restart, isolation and incumbent preservation evidence. Only
`SW431-DRAIN-DIV-MULTI` closes through this admission. Separate infiltration,
DRAMET3, highest-interflow, altered discharge-layer tops and frost-ON multilevel
remain separate capabilities. [PR1109](https://github.com/abhedwig-cell/SWAP5/pull/1109)
merged at `5d2518abd2b285b13f9b5f7d2177918589fd7abc`, with source tree
`9ce06f8381c006dbc16f95880632695abbec12d5` identical to the qualified successor.
The existing recovery record links the frozen conditions, raw O0/O2 receipts,
parallel annual/B1.12 preservation and mastercoverage closure receipt.
## Qualified ordinary separate infiltration successor (16 October 2026)

MC-DRAIN01 `SW431-DRAIN-INF-SPLIT` selects the existing B19 transmissivity
partition through explicit per-level separate-infiltration controls. The shared
partition remains the sole infiltration algebra. Its ordinary opt-in accepts
source-valid surface/GWL placement in one compartment and a zero unsaturated
span; existing frost calls retain their original geometry guards and arithmetic.
The immutable corrected oracle is the already admitted `FROST-DIVDRA-03`, under
`integration/audits/PPA_WU05B20_CURRENT_REVIEW.json`. No reference bytes change.
A zero saturated conductivity span is source-undefined and fails closed.

For interacting levels, the original effective spacing factor FDisInf changes
the spacing order, cumulative transfer and positive discharge layers before
negative rows use the shared unsaturated/saturated integral. Each row closes to
its signed authoritative scalar. Positive removes soil water and negative adds
it; internal nodal attribution does not create another external booking.
The existing accepted ledger, rejection cleanup, temporal history and restart
codec retain state ownership. Controls are explicit request data, without a new
persistent store or scalar response law.

The existing recovery record, phase `inf_split_phase_20261016`, freezes the
conditions and links 15,192 source cases per optimization, including 720
same-compartment cases, 48 actual single/multilevel serialized cases per
optimization, invalid-input publication guards, rejection/replay, empty-registry
restart and column isolation. O0/O2 outputs agree exactly. Original signed and
multilevel process/runtime contracts and all original B18 component assertions
are preserved. Only `SW431-DRAIN-INF-SPLIT` is eligible for this closure;
DRAMET3, altered layer tops and new frost-ON capabilities remain separate.
Canonical admission and mastercoverage receipts are recorded in that phase.
