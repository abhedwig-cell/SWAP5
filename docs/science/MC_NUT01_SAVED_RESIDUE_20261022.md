# MC-NUT01 saved next-day residue diagnostics

Explicit opt-in successor of the admitted harvest-generation boundary at
`0be6037b670fdd3cb004ff616b0925291ae56728`. Not full MC-NUT01 admission.

## Source and contract

The authenticated B1.11 `management_soil.f90`, SHA256
`0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b`,
task6 accumulates the old `_1` organ inputs, replaces them with current
`idw*` and `iNLOSS*`, then optionally emits/resets the reporting interval.
Replacement is unconditional, including nonreporting days. Root is the bottom
term; leaf, stem and storage are the surface terms. Units remain kg/ha.
`wofostnut.f90` adds harvest returns to current daily dead-organ inputs, not
to yesterday's values and not to exported crop material.

The new opt-in companion owns nine diagnostic values: accepted clock, four
saved dry-matter values and four saved nitrogen values. Existing 17-value
diagnostics and S5NO0001 generations remain unchanged. A consecutive accepted
day stages both diagnostic states, adds the previous values through the
existing task6 component, and saves the current values. Invalid/replayed/gapped
days publish neither state nor a row. This is not a second physical inventory,
and must never be passed to incorporation or mass accounting.

## Execution selection

Immediate feedback selects the two-provider source-exact O0/O2 diagnostic driver
and snapshot/restore/replay/invalid-state controls, expected under five seconds.
No physical provider or incumbent implementation changes. Full F-CI, retired
highest low-air, RossFast expansion and aquifer are NOT_SELECTED_IMPACT/POLICY,
not PASS. Physical harvest capture, one authoritative combined restart and actual
accepted Richards fallow days are selected separately, expected150 seconds.
The accepted-state closure remains331 unchanged providers; five adapters compile
freshly per optimization. Same-session old object/module hashes, exact source
inputs, flags and execution streams are retained; compilation reuse is not a new
incumbent qualification. Fresh original driver endpoints must equal the admitted
endpoint exactly. Costs and source identities belong to retained runner results.

## Physical capture and persistence boundary

`capture_crop_soil_n_saved_harvest` requires matched cold water/chemical and output
clocks, a staged not incorporated harvest, and uninitialized diagnostic memory.
It captures four returned harvest organs plus three current daily-death organs.
Missing, consumed and retired records are rejected. The physical harvest record
remains the authority for transfer and export.

`run_crop_soil_n_saved_harvest` stages the existing harvest, incorporation or
observation-bound retirement owner. Capture precedes clearing pending material.
Neither the phase nor its memory is published until the complete generation is
saved. No diagnostic day is synthesized at this boundary.

S5NS0001 is a new same-platform POSIX opt-in envelope, not a silent extension of
S5NO0001: magic, 32-bit nested byte count, nine binary64 diagnostic values, the
entire old CRC-protected physical/17-value/history generation, and outer CRC32.
Writers sync a complete pending file before one authoritative rename. Readers
validate length, bounds, both CRCs, existing physical identity, history/extrema
and clocks on local states before publishing any owner. No authoritative sidecar
pair exists. Thermal templates are explicitly rejected. Like the old envelope,
this is not cross-platform or power-loss/directory-durability qualification.
Process interruption before/after rename is selected.

`run_crop_soil_n_saved_fallow_day` calls the real material/Richards/N retired-crop
route, requiring zero roots/transpiration. It adds saved organ diagnostics on the
accepted day, then replaces them with fallow zeros. Water, chemistry, diagnostics,
memory and history stage together. Save failure publishes none; a later CSV-only
failure retains saved authority. Memory never enters chemistry or N inventories.

Affected architecture invariants:2,3,4,7,13,21,26,29. I/O stays in adapters;
optional memory is compact/explicit; existing physical equations and hydraulic
solver contracts are unchanged. The daily boundary belongs to this explicit
original-output application contract, not a hidden kernel assumption.

## Scope limits

Thermal fallow output, successor-crop output dispatch, general/default historical
orchestration, full crop seasons, snow/persistent surface-N and corrected active
negative donor allocation remain open. No full MC-NUT01 row is promoted.
Qualification/admission and execution receipts belong to the existing
HIST-COMPLETE successor record, not this prose.
