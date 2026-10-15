# Daily prescribed Soil-N environment

Proposed MC-NUT01-DAILY-ENVIRONMENT on canonical
`dca8cbd87ceff62406d0d1a38447b7a7bc8fbd1c` (crop supply PR1235).

An explicit `soil_n_day_environment_t` carries exactly one daily interval and
prescribed soil temperature in degrees C. The optional argument propagates through
the actual Richards/crop/soil application to both historical organic and mineral
reaction rates. It replaces the reaction temperature only for that attempt.
Moisture remains the accepted water endpoints. Temperature reference, saturation,
rate parameters and identity are immutable. Absent forcing retains existing
operation. Supplying forcing to disabled reactions rejects rather than ignoring it.

This is prescribed time-varying temperature, not accepted heat-state coupling,
air-to-soil substitution, depth-profile averaging, default weather activation,
amendment/residue routing, pond/source or aquifer. Historical management_soil
lines361..374 choose a depth-derived temperature; that reduction has a strict
layer inclusion condition and is not reinterpreted or admitted here. The existing
source-qualified rate functions retain their own exact literal oracle authority.

One daily attempt accepts water, crop and soil together or publishes none. The
forcing must match t0/t1 exactly and use -20..60 C. Time magnitude is bounded by
1e9 days before subtraction. No forcing or new storage is retained after the
atomic day. Existing schema and exact original parameter vector remain unchanged;
restart callers provide the next day's forcing as they provide weather. Reusing
an earlier day's forcing fails closed. No hidden last-temperature fallback exists.

Affected invariants:3,7,9,13,21,22,23,29,30. Persistent state, water solver,
WOFOST81 fixation and existing reference correction MC-NUT01-R1 are unchanged.

Qualification selects real small O0/O2 process/crop drivers, literal organic,
water/rate and complete uptake oracles, varying temperature trajectories, input
nonmutation, A/B/A, invalid/stale forcing rollback, successful retry, original
no-forcing endpoint equivalence and actual Richards plus opaque/fresh-process
joint restart. Original mineral/reactive/crop physical drivers execute fresh.
Expected direct build15s; joint build120s, native90s based on PR1235. Compiler is
GNU Fortran13.3.0; flags include bounds and invalid/zero/overflow traps.

Stable admission requires the existing four-level full moving preservation
because the shared reactive optional argument and owning application change.
Expected1573s; compile/link/native full split UNKNOWN. Persist first, run once
on the stable candidate; reconcile foreign source eligibility without weakening
original assertions. Highest low-air is NOT_SELECTED_POLICY. No admitted/full
NUT capability claim before terminal proofs and safe expected-head merge.
