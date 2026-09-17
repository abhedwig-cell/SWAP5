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

## Other admitted response families

The frozen production tree also contains dedicated process modules for the other Drainage-v1 response families, including tabulated response, Hooghoudt, Ernst, empirical interflow, spatial distribution and multi-level aggregation.

F-DOC21 does not restate every equation merely because the module exists. Detailed equations should be published only when the corresponding scientific authority, implementation route and qualification identity are stitched together without ambiguity. F-PM19 provides the accepted variant denominator and points to the variant-specific F-VQ scientific authorities, including F-VQ38, F-VQ40, F-VQ42, F-VQ43 and F-VQ44.

This distinction matters because a correct historical drainage equation is not, by itself, proof that the same parameterization or routing is the admitted SWAP5 production path.

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
- `integration/f-pm/F-PM19_DRAINAGE_V1_FINAL_COMPLETION.json` for the fixed eight-variant completion denominator and authority chain;
- [Drainage capability review](../capabilities/drainage.md) for the bounded Status-A capability statement;
- [Status-A traceability](../status-a/TRACEABILITY.md) for current review authority and preservation context.