# MC-NUT01 unified bounded Soil-N export: admission evidence (2026-10-17)

Base canonical: f3eea3f9e35d9d324c68ed88a1b4dda7dcceb708. PR #1284. Exact native-tested implementation: c029d1d0d111688032835a630e072aa236c87fee.

## Bounded input and runtime

An explicit [management] section holds the existing positional material and event records, and [soil_n_parameters] holds 25 required and one optional original named fields. Both parts are validated in memory before publishing a calendar or initializing the original-source eight-FOM reactive N state. Late invalid records and duplicate names fail without publishing the calendar or N owner. Existing hydraulic owner, mass budget, transaction and restart semantics remain unchanged.

This is a transformed strictly sectioned export, NOT an original 4.3.1 TTUTIL or .snm reader. It does not claim whole-project source compatibility, atmospheric/top boundary solute chemistry, residue-age lifecycle, extended rate switches, or complete MC-NUT01 coverage.

## Execution evidence

GitHub Actions 39042826978 (https://github.com/abhedwig-cell/SWAP5/actions/runs/39042826978) at tested code head c029d1d0d111688032835a630e072aa236c87fee: completed success. Native historical O0/O2 2 PASS; actual Richards/reactive N O0/O2 2 PASS including conservation, rollback and restart. Negative late-duplicate record in valid unified file fails closed. Raw artifact 12103849255, 37214917 bytes. The admission documentation commit does not change tested science code or drivers.

Production changes are input composition, not N physics equations or hydraulic solver, therefore focused chemical owner/actual Richards preservation was selected; no unrelated broad low-air or performance gates. Nine broad NUT rows remain open. Recovery: work/nut-unified-input-20261017, PR #1284.
