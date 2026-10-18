# Historical atmospheric nitrogen boundary

Status: proposed implementation contract, successor to the bounded native/rotation
admission in PR1313 at canonical8bf52bf23277d193039ea5162e7100b6889bc7c0.
This contract alone does not qualify or admit the extension.

## Source and ownership

Pinned management_soil lines192,195 read cNH4N_top and cNO3N_top as real scalars
in0..1000kg N/m3. The pinned original Wofost_SoilWaterN accepts independent top,
lateral and bottom concentrations; the existing SWAP5 transport/exchange kernel
already implements those same terms. Only the missing parameter/input binding
and the accepted top-water carrier are extended. Existing mineral/reactive/crop
owners, original organic reaction kernel and Reference Richards stay authoritative.
No additional inventory, transport implementation or solver change is allowed.

Append a default-zero c_top(2) to the existing immutable mineral parameter type.
Bind the two historical named values through the existing activation adapter.
Positive accepted top infiltration contributes c_top*water to the existing
external-input receipt and analytical transport. Negative evaporation removes
water without exporting dissolved N. Top exfiltration/runoff and surface stores
remain unsupported, exactly as in the existing clean-water extension.

## Compatibility and parameter identity

Zero top concentrations preserve the exact preexisting parameter vector bytes.
Nonzero concentrations append an explicit marker and two values to that vector.
The native adapter already stores and compares its complete length and values
against externally supplied immutable parameters. Opaque restore uses the same
identity. Wrong or missing top concentrations must reject before publication,
including otherwise matching old parameter IDs. No new persisted dynamic state,
owner or restart tag is introduced. CRC, profile and decoder checks remain hard.

The existing clean_surface_water runtime option retains its zero-solute meaning.
A separately explicit atmospheric_n_surface option admits the same accepted-water
carrier with configured dissolved N. Calling the clean-only route with nonzero
configured top N rejects before the water trial. Absent options retain the prior
zero-top-flux restriction. Direct mineral/reactive calls explicitly supply both
immutable concentrations and signed surface water.

Invariants1..4,7,9,11,13,21..23,25,26,28..30 apply. Existing clean/default production
and restart bytes remain preservation gates. RossFast is outside this extension.
No full mastercoverage promotion is implied.

## Selected qualification

Start with real mineral/reactive production drivers and the pinned original
analytical transport, then native named-input positives and atomic negatives.
Use small fresh O0/O2 builds before the owning composition. Qualify nonzero
atmospheric input, sorption, evaporative retention, conservation and rejection.
Execute the730-day two-crop/fallow/harvest profile with nonzero atmospheric N and
physically moderate bottom concentrations, including all six fresh-process
transition restarts, wrong-top-configuration rejection and byte-exact rollback.
Preserve the old zero-top profile as a distinct scenario and its immutable bytes.
Reexecute affected retained/thermal/TCS6 admission surfaces; reuse providers only
with exact source, artifact and module-interface identity and actual fresh native
commands. Do not inherit native PASS across changed physics.

The separate B0 cNO3N_seep assignment defect requires an explicit corrected B1
input-reference witness. It must not be silently described as B0 equivalence.
