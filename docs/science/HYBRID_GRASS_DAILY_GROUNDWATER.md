# Caller-prescribed Grass groundwater through the shared daily transaction

Application successor to canonical `4f0688b03f8ec00cc75f4be4b4f16ab07a273770`.
This extends the existing external daily adapter to the original Grassgrowth
SWBOTB1 boundary. It reuses the same transaction, worker, state and restart owners
as original forcing and Andelst Cauchy input; no separate physical kernel is added.

## Actual input consumer

```python
from daily_coupling import CoupledDailyColumn, GROUNDWATER_FORCING
column = CoupledDailyColumn(bundle, reference, output, grass_project, coupling_id,
    origin=day2, day=2, adopt_native=True, forcing_mode=GROUNDWATER_FORCING)
segment = column.groundwater_forcing(-88.0, -87.999, 'caller-groundwater-source')
proposal = column.prepare(groundwater=segment)
checkpoint = column.accept(proposal)  # or discard without changing accepted state
```

The new mode is `grass-groundwater-daily-v1`. Its distinct frozen
`GroundwaterDayForcing` type means **original signed GWLEVEL in cm relative to the
original soil surface**. The inherited `head_start_cm/head_end_cm` document fields
carry those water-level coordinates. They do not mean an Andelst deep-aquifer head,
a compartment pressure or an automatically converted external elevation datum.
Mode/type/keyword and project mismatches are refused.

The original BBC retains its complete sparse `DATE1/GWLEVEL` table, existing
decimal spelling and boundary option. Caller day knots are inserted or replaced
in date order. The original `afgen` and water solver own leading clamping and
interior interpolation. No datum conversion, pressure projection or clipping is
introduced. Finite original scalar bounds are checked before attempt creation;
the original reader's additional five-unsaturated-cell geometry check stays active.

`ReadSwap` initializes GWLTAB before restore. The original hydrostatic
reinitialization branch applies to SWINCO2; the native route uses SWINCO3.
Restored initial stocks and the complete pressure profile must match the accepted
receipt before a step. Original forcing stays the default for all three projects.
Hupsel's original zero-flux boundary cannot be selected as a head boundary.

## State and qualification

The same coupling ID, accepted origin SHA/day, exact day1900 support and caller
provenance bind each request. Nonfinite/bool/out-of-range/foreign/stale/missing
input and wrong boundary kind refuse before attempt or advancement. The public
proposal remains uncommitted and its forcing view is a detached copy. Private
packages identify `external_groundwater_trial`, never original-only input.
External acceptance binds the request document/digest and actual worker BBC SHA
to both complete native payloads. No new native codec or shared Fortran change.

Actual Windows and Ubuntu26.04 original donorO2/kernelO0/O2 qualify two distinct
original-table supports:

| Window | Distinguishing condition | First prescribed segment,cm |
| --- | --- | --- |
| 2→4 | Before the first original1980-04-24 observation; original curve is clamped | -88.0→-87.999 |
| 114→116 | First measured interval,1980-04-24 toward1980-05-02 | -88.0→-92.124 |

Each modified first day is discarded and retried with byte-exact physical/native
results, then accepted. The second day starts from that **modified state**; live
and cold-disk continuations match all physical fields and both complete native
payloads exactly. Separately edited original full BBC controls match both days
exactly, including the second day's modified parent. Actual stored table knots,
SWBOTB1, forcing digests, applied-file hashes and parent lineage are independently
audited. Constant leading levels retain exact original2→4 state and receipts.

Six malformed persisted forcing cases refuse for each input kind on both
platforms. Leap/year/terminal table preparation checks are input-only, not new
externally forced full-year simulations. Existing Cauchy20→22 O0/O2 and all six
original-forcing project/optimization cases per platform pass, including native
corruption, peer/ownership, stale decisions and publisher-failure recovery.
The Andelst numerical platform sensitivity retains its previous qualified limits;
these preservation checks do not promote its scientific equivalence.

The successful initial WindowsO2 leading proof is retained and reused only after
exact application-source, BUILD and terminal-state hash checks; its separate
executed source report remains in the raw capsule. Other selected new cases run
once. Current114 origins use a bounded2→114 warm prefix, not a full project run.
Previously qualified compatible Cauchy day20 origins are verified and reused on
both platforms; no accepted18-day Cauchy prefix is repeated or old ZIP rebound.

Original physical blocks, numerical policy and water tolerance1e-10cm remain
unchanged. Complete original Grassgrowth1827, Andelst481 and Hupsel1096 results
retain their exact source/profile evidence. No externally controlled1827/481
trajectory, implicit peer solve, thermal feedback, whole energy or whole scientific
equivalence is newly qualified. Original day188/day584 failed comparisons remain.

## Reproduction and next functional scope

```sh
python -B research/hybrid-water01/qualify_grass_groundwater.py --workspace /work/original-proof --output /work/grass-groundwater
python -B research/hybrid-water01/audit_grass_groundwater.py --runs /work/grass-groundwater --output /work/groundwater-audit.json
```

The owning source/build/input/results record is
`integration/f-ci/HYBRID_GRASS_GROUNDWATER_20261112.json`. Actual source snapshots,
native states, input tables, controls, source-distinct successful probe and complete
Linux log are retained under `research/hybrid-water01`. No Fortran build or full
project/reference execution is selected. Controller/publisher costs and actual
cohort elapsed times are reported separately; native-only CPU/wall remain UNKNOWN.

The next coherent input consumer is original Hupsel fixed irrigation with its
required water/solute pairing, through the same transaction discipline. First
inspect the original irrigation event units/timing and the complete irrigation
context already persisted in S5HUP010. A pre-start SWP edit must not be presented
as runtime control if restore overwrites it. Use the original consuming routine
or a justified controlled entry after restore, retain whole native context and
both1e-10 water/solute guards, and compare a short saline-gift window against an
independently specified original event. No new general framework or full run.
