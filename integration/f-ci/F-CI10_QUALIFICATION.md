# F-CI10 — Generic Physical Interval and Mass Seam Qualification

## Scope

F-CI10 advances the physical mass-accounting contract without pretending that the B1.10 calendar controller is already a generic `[t0,t1]` physical executor.

Materialized canonical source:

- `src/adapter/mod_b1_10_trial_mass.f90`
- `src/adapter/mod_b1_10_mass_seam.f90`

The trial-mass object is worker/job-local data. It is not persistent column state and contains no file I/O or module-global mutable state.

## Qualified storage subset

For the currently source-bound Hupsel profile with `SWSNOW=0` and `SWMACRO=0`, physical water storage is represented by:

`volact + pond + sicact`

where `sicact` is available from the admitted crop/process continuation state. Snow and macropore configurations fail closed because their persistent storage has not yet been admitted into the canonical process state.

## Source-bound mass formulation evidence

A controlled local source-port candidate fed `b1_10_trial_mass_t` from the same unrounded timestep terms used by `MOD_integral`. The official source archive SHA-256 was `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` and the reconstructed physical basis was B1.10 + the qualified F-CI06 controlled port.

Hupsel offsets 499, 520, 760 and 800 were run at `-O0` and `-O2`. All eight runs were within the hard `1e-6 cm` water-balance limit and O0/O2 were identical. Maximum absolute residual was `1.587818254655815e-07 cm`.

This evidence qualifies the mass formulation and integration candidate. It does **not** claim that the candidate `integral.f90/swap.f90` postimage is already canonical production source.

## Time seam blocker

Exact B1.10 `timecontrol.f90` remains calendar-day based:

- day completion is tied to `tcum = 1 day`;
- next-step event limiting uses the remaining fraction of that day;
- run completion uses rounded calendar-day values;
- the restart task marks the next execution as a day start;
- the DLL exchange path explicitly enforces the legacy single-day convention.

Therefore a reference full/half/half trial over arbitrary physical sub-intervals is not yet admissible.

## F-CI10 gate

The focused gate compiles and executes the new mass contracts at `-O0` and `-O2`, verifies identical output, verifies fail-closed snow/macropore and incomplete-flux behavior, pins the B1.10 time/integral source identities, and verifies that the F-CI09 reference execution lock remains active.

Qualified source/test head: `970d99100a256099343d4b2072ecd543469b23b5`.

Canonical workflow run `34093648750`, job `101652946866`, completed successfully with GNU Fortran 13.3.0 and `FCI10_GATE_PASS`. The complete F-CI03 through F-CI10 dependency chain passed on the same source/test head.

## Non-admissions

F-CI10 does not admit:

- generic physical sub-day execution;
- legacy timestep wiring of the trial-mass accumulator as canonical production source;
- snow/macropore complete storage accounting;
- a physical temporal-error metric;
- B1.10 execution through `execute_reference_interval`.

No physical formula, constitutive relation, Jacobian formula, solver policy, mass tolerance or selective step-doubling policy is changed.
