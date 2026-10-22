# Native daily MET preparation for the solute column

Status: canonically admitted bounded route through PR1364, merge
`48cb945235a86d7a793f9e73c393cb57c051dd0c`. Baseline is
`46ad96ee2cc65fdee48a1f3b47e3290f86f7ffd6`.

This additive file adapter reads original TTUTIL `TSTART`, `TEND`, `METFIL`
and daily `DD MM YYYY TMIN TMAX RAIN ETREF`. Original SWAP 4.3.1
`MOD_meteo.f90::LoadMeteoData` is the source authority for fields, calendar
slicing and mm to cm conversion. `ProcessMeteoDay` defines the diagnostic
daily mean temperature. The existing immutable B1.11 source archive contains
both procedures. Numerical and physical providers are unchanged.

The first execution scope is explicit rain-only fallow: `SWETR=1`, `SWCROP=0`,
`SWRAIN=0`, `SWSNOW=0`, `SWHEA=0`, optional `SWMETDETAIL=0`, `SWFROST=0`,
`SWDIVIDE=0`, a single explicitly supplied `.MET` file and whole-day inclusive
start/end dates. The MET basename must match original `METFIL` after its original
lowercase normalization. All dates in the file must be consecutive and unique.
That last check deliberately strengthens the original one-sided forward-gap
check, whose positional slicing cannot safely admit duplicate/reversed dates.

ETref must be exactly zero on the selected days. Nonzero ETref, crop activity,
snow, frost, subdaily rainfall and heat are rejected, rather than losing a
physical flux or equating atmospheric temperature with a soil boundary.
Temperature remains a source diagnostic and is not applied to the soil.
Daily gross rainfall is net rainfall in this crop-free, snow-free scope.
The selected last historical day becomes the last complete one-day window.
Optional initial pond, bottom flux and runoff parameters remain explicit.
Root extraction, drainage, irrigation, runon and evaporation are zero.

`tools/solute/build_daily.py` builds one adapter plus original TTUTIL, separately
from the production calculation. `run_daily.py` generates a deterministic input
for the unchanged `run_column.py`. It embeds complete original SWP and MET bytes,
their hashes, its own source hash and the reader executable identity in comments.
Consequently existing exact-input restart validation also binds the original
weather bytes, including edits outside the selected period. The existing
complete generation inventory, atomic rename and accepted restart remain intact.
The exact SWP snapshot used by the adapter is passed to the physical application.

Affected invariants: 2, 3, 7, 9, 13, 21, 23, 29. File/calendar handling remains
outside the kernel; physical state, transactions and solver policy are unchanged.

Qualification must compare the native reader with the complete extracted
original `LoadMeteoData`, test leap/year boundaries and slicing, invalid/ambiguous
calendars and unsupported modes, and execute actual O0/O2 water/solute balance
and independent-process restart. Compare resulting physical bytes with the same
explicit forcing through the incumbent launcher. Reuse existing column builds
only after verifying all their input and executable identities. Native adapter
builds are independent for O0/O2. Full F-CI, solver, low-air and annual physics
requalification are not selected: no existing provider or physical contract is
changed. Existing source/evidence owners must retain their original assertions.

This is a bounded opt-in application route. Full meteorological ET partitioning,
live crop evolution, standard historical default orchestration, water age and
nutrient composition remain open. No whole historical capability is closed.

## Local result and invocation

The final 72-process qualification passes: eight complete-original-loader
comparisons (leap day, year crossing, leap/common centuries), 42 rejected native
inputs, eight actual column calculations, two fresh-process continuations,
four rejected output generations, independent hard water/solute balances and
exact explicit-forcing output bytes. The first oracle link failed on the unused
original AFGEN reference; the final harness links its exact archived procedure.
The failed raw observation remains in the evidence capsule.

```bash
python -B tools/solute/build_daily.py --optimization O2 --output /tmp/met-reader
python -B tools/solute/run_daily.py --reader /tmp/met-reader/swap5_read_daily \
  --exe /path/to/build/swap5_solute_column \
  --swp examples/solute_column/daily_fallow.swp \
  --met examples/solute_column/daily_fallow.met --output /tmp/daily-result
```

Use the existing column builder for the physical executable. Repeat the identical
command with `--stop-after 1` for a partial generation, then `--restart` pointing
to that generation for continuation into a fresh output directory. All options,
original source bytes, reader executable and generator must match.

## Canonical receipt,22 October2026

PR1364 head `8488c810a6c7df397e3fbc50bd20857ebf87219a` passes all17
selected PR workflows, including the native daily O0/O2 suite. Actual merge
`48cb945235a86d7a793f9e73c393cb57c051dd0c` has the identical complete tree
`11aa820c9b7d26808804f98373baa8d76ee01a00`. The owning source/evidence
verification and all21 predecessor plus17 daily controls pass on the actual
merge. Concurrent canonicald7c1accc changes only NUT documentation/coverage.
The admitted initial scientific capsule and a separate hosted/actual-merge
capsule retain raw observations and the original failed oracle link.

Duplicate postmerge Actions were explicitly skipped for that identical complete
qualified tree. Actual-merge source/evidence validation is a local check, not a
new numerical replay. The final metadata receipt changes only this contract,
the existing status and the raw hosted capsule; the original native execution
inputs and all physical providers remain exact. Full historical migration,
nonzero ETref partitioning and live crop/default orchestration remain open.
