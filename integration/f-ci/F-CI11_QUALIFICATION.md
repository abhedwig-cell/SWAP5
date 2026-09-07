# F-CI11 — Controlled Legacy Trial-Mass Wiring and Generic Time Controller Refactor

## Scope

F-CI11 promotes the F-CI10 unrounded mass-wiring candidate into complete, fail-closed legacy source postimages and introduces an explicit physical interval seam. No physical formula, constitutive relation, Jacobian formula, solver policy or mass tolerance is changed.

The new interval boundary is independent of the calendar day boundary. Calendar-day processing remains tied to the existing `flDayStart/flDayEnd` events; an interval may finish earlier, later, or across a day boundary without manufacturing a calendar event.

## Controlled postimages

`tools/fci/fci11_apply_controlled_interval_mass_port.py` accepts only the exact F-CI06 controlled postimage and replaces complete postimages for `integral.f90`, `timecontrol.f90`, `swap.f90` and `swap_main.f90`. The source materializer pins both preimage and postimage SHA-256 identities.

The trial-mass accumulator remains explicit worker/job-local input. The generic interval object is likewise explicit call context and is not persistent column state.

## Qualification

Source-bound Hupsel qualification used the exact B1.10/F-CI06 physical basis. Standalone F-CI11 is numerically identical to the qualified F-CI10 mass-wiring candidate at O0 and O2 for `result.bal`, `result.blc` and `swap.wrn` after generated metadata is excluded. An earlier comparison against an incomplete header-only F-CI06 run is explicitly not used as qualification evidence.

Two full-versus-two-half suites were executed at O0 and O2:

- four day-start profiles (offsets 499, 520, 760, 800): 8/8 PASS;
- four arbitrary interval profiles, including non-midnight starts and intervals crossing a calendar-day boundary: 8/8 PASS.

All trajectories preserve continuation/cursor semantics and satisfy the hard `1e-6 cm` mass bound. O0/O2 results are identical. Full-versus-two-half physical state differences are expected numerical-path differences; F-CI11 does not convert them into a qualified temporal-error metric.

## Non-admissions

F-CI11 does **not** yet admit `b1_10_transaction_model_t%advance`, a physical temporal-error policy, `execute_reference_interval` for B1.10, snow/macropore complete storage accounting, or a reentrant parallel legacy backend.
