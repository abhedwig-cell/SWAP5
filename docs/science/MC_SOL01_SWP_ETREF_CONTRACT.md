# Fallow ETref water and solute composition

Status: locally qualified O0/O2; canonical admission pending. Baseline:
`288ba1473c478b9a2a637f0b12d624fbcc63ca4a`.

The opt-in successor composes original daily ETref with the existing production
reference ET demand and hydraulic surface evaporation. Initial scope is fallow,
SWETR=1, SWCROP=0, SWREDU=0, SWCFBS=0, daily uniform rain, heat/snow/frost off.
Soil demand and pond demand are alternatives selected from actual trial surface
conditions by the existing top provider; they are never added as two simultaneous
losses. ETREF is mm/day in the original MET file. The existing demand process
converts to cm/day. The original ETpot and CDE procedures remain reference
authority. Live crops, empirical reduction, exfiltration and implicit empty-pond
evaporation with a positive soil demand are outside this initial scope.

The missing accepted carrier is actual bare-soil evaporation. Add a default-zero
scalar to read-only accepted flux traces and a default-zero demand to pond input.
No accepted state or restart layout is added. The trace publishes the converged
hydraulic value; callers cannot invent an actual evaporation rate. Pond replay
checks its balance as:

`pond_end - pond_start = (rain + irrigation + runon - Epond - Esoil + qtop)*dt - runoff`.

Here qtop is the existing signed net soil-face water flux, upward positive.
Positive qtop is admitted only up to independently observed soil evaporation;
positive exfiltration beyond that remains rejected. Original CDE top solute
exchange still uses this same net qtop and exports no dissolved salt with
evaporation. The original surface-residue/mixing convention is retained; no new
gross infiltration chemistry or volatile solute law is introduced.

The CLI must explicitly select ETref composition. The old rain-only CLI continues
to reject nonzero ETref. Original files, reader/generator identities and complete
input bind fresh restart as before. Existing explicit column forcing gains a
default-zero soil evaporation array; actual soil loss is reported only when that
array is selected, preserving old zero-demand output bytes.

Affected invariants: 2, 3, 7, 9, 13, 21, 23, 29. Potential demand remains forcing;
accepted hydraulic traces own actual flux, joint water/chemical commit remains
atomic, and no solver policy or empirical physical model is silently enabled.

Qualification selects small native process/carrier tests first, then actual
Reference O0/O2 dry-soil, rain/evaporation, ponded and transition calculations,
hard water/solute balances, salt retention, rejection/rollback and fresh restart.
Reference demand must match exact original ETpot. Current zero-demand application,
original SWP chemistry/water/daily and thermal compositions require dependency
reconciliation and preservation. Full F-CI/low-air and unrelated physical models
are not selected solely because the shared backend carries a new default-zero
field. Preserve original authority assertions through a source-bound successor.

The first transition proof retains an original roundoff counterexample: original
CDE subtracts equal available/transferred amounts at exactly zero pond depth and
can produce a negative floating rest. For this new opt-in soil-evaporation route,
use the already implemented analytical zero-pool chemistry limit independently
of the separate implicit-empty-pond water option. An appended default-false
`exact_empty_pool_chemistry` supply flag selects it. The limit sets transfer to
all available mass and remaining pool to exactly zero only under its existing
zero-depth/no-runoff/no-macropore/negative-infiltration conditions. This is an
algebraic identity, not a negative-mass clamp or a relaxed tolerance. All old
zero-soil-demand callers retain the original default branch. No water forcing,
soil sorption equation or accepted/restart state changes as a consequence.

## Local qualification and use

Final 44-process ETref proof passes 40 exact original ETpot comparisons,
24 actual production column runs, eight independent-process restarts and
12 rejected generations. Dry/nonlinear, dry/linear, persistent pond and
rain/pond/dry transitions pass both O0/O2. The unchanged hard 1e-10 balance
threshold is enforced independently against gross rain and accepted evaporation.
Existing `water_in/out` reporting uses signed net external exchange; it must
not be mistaken for separate gross precipitation and evaporation totals.
The appended soil evaporation observation supplies the missing gross term.

Fresh stable builds pass all172 chemistry,110 water,72 old daily and86 file
observations, plus18 prescribed annual thermal/nonlinear cases (30 processes).
152 published primary baseline files are exact. Pending/crash-corrupted
folders are excluded from the published-generation comparison. The frozen
complete predecessor owner and39 controls execute at the exact baseline.
The current source-bound successor qualifies new compiled providers separately.

```bash
python -B tools/solute/build_daily.py --optimization O2 --output /tmp/etref-reader
python -B tools/solute/build_column.py --optimization O2 --output /tmp/etref-column
python -B tools/solute/run_daily.py --etref --temporal-tolerance .0001 \
  --reader /tmp/etref-reader/swap5_read_daily \
  --exe /tmp/etref-column/swap5_solute_column \
  --swp /path/input.swp --met /path/weather.met --output /tmp/etref-result
```

ETref mode additionally requires explicit SWREDU=0, SWCFBS=0 and CFEVAPPOND.
Optional SWEVAP must be1. Existing plain rain-only mode still rejects positive
ETref. Temporal tolerance is an explicit existing numerical option; its default
is unchanged. The selected dimensionless .0001 temporal error budget is not
a relaxation of the hard water or solute balance. It is dimensionless in the
existing transaction metric, not a time step or a guaranteed head error.

Full F-CI, highest low-air and unrelated component research are not selected.
Local compilation and coupled execution provide the integrated qualification;
no new hosted numerical PASS is inferred. Existing native workflow assertions
are retained and an ETref step is added for subsequent native workflow runs.

## Concurrent native NUT preservation

Canonical367ef349 admits PR1365's explicit native crop-output startup while this
ETref work is under qualification. Its five production providers are disjoint
from all190 compiled solute-column inputs. The actual native NUT project does
use the shared backend, so its current O0/O2 Richards/crop/N output and fresh
continuation, native input controls and compiled mutants are selected anew.
Its original source/evidence owner and20 controls execute on exact367ef349.
Both original dispatcher bodies remain intact behind the composed current
owner; the current source guard pins all concurrent admitted files and the
combined scientific delta. This preserves NUT startup, rather than claiming
that ETref has been coupled to nutrient chemistry or live crops.

The composed current NUT run is PASS at O0/O2, including actual native TRUE
startup, original FALSE/default behavior, fresh process output continuation,
26 new/38 incumbent input observations and three compiled rejecting mutants.
All24 selected prior NUT endpoint/output bytes remain exact. Its separate raw
capsule and frozen20-control receipt are bound by the current ETref owner.
