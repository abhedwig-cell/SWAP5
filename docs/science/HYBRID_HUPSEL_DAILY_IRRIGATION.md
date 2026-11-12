# Original Hupsel daily surface-irrigation input

## Implemented consumer and state ownership

This opt-in application uses the same serial external daily transaction as the
[Cauchy](HYBRID_CAUCHY_DAILY_FORCING.md) and
[Grass groundwater](HYBRID_GRASS_DAILY_GROUNDWATER.md) inputs.
`forcing_mode="hupsel-surface-irrigation-daily-v1"` is restricted to original
Hupsel, SWIRFIX1, solute1, no scheduled irrigation, surface application type1.
Original-project forcing remains the default for all three original projects.

`irrigation_forcing(depth_mm, concentration_mg_cm3, rate_mm_h, provenance,
enabled=True)` returns an immutable request bound to coupling ID, accepted
origin SHA/day, and the original 2002 day1900 window. `prepare(irrigation=request)`
replaces the fixed event for that day, including explicit absence with
enabled=False and all three values zero. Positive requests retain the actual
original reader limits: depth0.01..100mm, concentration0..1000mg/cm3, positive
rate<=100mm/h and duration<=1day. Bool/nonfinite numeric fields, wrong kind,
foreign/stale identity or clock, absent provenance and inconsistent disabled
requests refuse before model advance.

The private worker consumes its explicit S5IRR001 file within the original
irrigation task3, after native state restoration and crop initialization. An
SWP-only override would be overwritten by the complete saved irrigation context.
The consumer retains the original mm-to-cm and mm/h-to-cm/day conversions,
application rate, event duration, time control, surface water and solute routes.
It suppresses an original same-date fixed event once and retains all future
original table entries. Locals are explicit per invocation; no new SAVE state
or restart format is introduced. Missing input leaves the original branch intact;
a stale, nonfinite, out-of-range or malformed actual worker file refuses.

The complete existing S5HUP010 irrigation/solute/crop context and physical
state remain in the existing schema3 native/auxiliary accepted packages.
A private trial binds its request, provenance, digest and actual worker input
SHA256; external accept persists those bindings. Discard cannot change the
accepted origin, and recovery validates the saved request before a new trial.
Original Hupsel zero-flux bottom and1e-10 water/solute guards are unchanged.
Worker processes continue to isolate legacy globals; thread safety is not claimed.

## Incremental build and exact preservation

`app/hybrid_water/irrigation_forcing.py:build_bundle` validates the original
qualified bundle, compiler target/hash, original provider objects and TTUTIL
library. It recompiles only the original generated irrigation module and relinks
the original donor against the reused original objects. The existing kernel and
shared SWAP5 providers are reused. The resulting BUILD binds the generator,
generated source, object and executable, while all original source/build/input
bindings remain explicit. Old checkpoints are not relabelled with the new build:
a seven-day fresh bounded original control creates its own day4 origin.

Windows and Ubuntu26.04 actual original donorO2/kernelO0/O2 pass all six cases:
modified original January5 saline gift, disabled gift, and unchanged gift.
Each continues through January6, with an extra0.02mm/1mg-per-cm3 gift in the
modified/disabled histories and explicit absence in the identity control.
The seven no-file physical daily records equal the published original proof;
the actual saved original day5 native and auxiliary payloads match byte for byte.
The earlier probe tried to compare a day7 endpoint with a frozen payload actually
saved on day5; that harness assertion remains FAILED in the raw evidence. The
comparison was corrected to its actual saved day, without changing model code.

For every scenario, discard/retry is physical/native exact and fresh durable
recovery from the MODIFIED accepted day5 state equals live day6 continuation,
including both complete payloads. Independently edited full original SWP event
tables, run from initial state without the override, match every physical day5
and day6 record exactly. Their saved irrigation TABLES differ by construction;
no equality of complete native input-context bytes with that independent control
is claimed. This distinction does not weaken exact same-route retry/recovery.

The modified gift introduces48.0044001mg/cm2 solute, the disabled gift zero,
and the new next-day gift0.002mg/cm2. Independent audits recompute actual water
and solute closure, requested versus applied amounts, forcing lineage, payload
hashes and the original object/source reuse. All retain1e-10 limits. Both prior
controlled boundaries and all three original-project daily routes pass their
current O0/O2 preservation and original corruption/terminal checks on both OS.
Seven persisted-input attacks and three actual consuming-routine malformed-file
launches refuse; pretrial attacks cover all six cases.

Measured new-mode cohort including incremental compilation and controls:
Windows33.046s, Linux11.736s. This is bounded event qualification, not a complete
externally controlled1096-day run or an accuracy-matched performance ratio.
No complete application or scientific reference campaign was repeated.

## Reproduce and inspect

Exact source commits, generated builds, executable hashes, commands, original
inputs, reports, archives and independent audits are in
`integration/f-ci/HYBRID_HUPSEL_IRRIGATION_20261112.json`.
The owning Ubuntu run is
[43133683506](https://github.com/abhedwig-cell/SWAP5/actions/runs/43133683506),
executed head4023bd4672df4175797f3f53a2b9175ee1def267. An earlier run stopped at
selection metadata preflight before any model execution; its failure stays visible.
Original sealed references remain separate from current evidence.

```text
python -B research/hybrid-water01/qualify_hupsel_irrigation.py --workspace BASE --output NEW
python -B research/hybrid-water01/check_irrigation_inputs.py --workspace BASE --runs NEW --output GUARDS
python -B research/hybrid-water01/audit_hupsel_irrigation.py --workspace BASE --runs NEW --output AUDIT.json
```

BASE is the extracted hash-bound original platform capsule. NEW must not exist.
The cohort has a240s kill cap; only the two irrigation modules are compiled.
Full physical energy, new crop/solute process formulations, scientific day188/
day584 equivalence and a full controlled-irrigation project remain unqualified.
The completed original1827/481/1096 application evidence retains its own scope.

The next bounded acceptance target is Andelst Cauchy recovery after a genuinely
modified first-day head, compared with an independent original-input second-day
control. Its admitted matching-original-head recovery and modified one-day
control remain narrower evidence; reuse exact compatible published day20 origins,
keep all tolerances and cap the two-day proof rather than repeat481days.
