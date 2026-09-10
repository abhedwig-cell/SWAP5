# F-WOF43 — Crop-to-ET Canopy View Ownership & Reconstruction Readiness

## Decision

`QUALIFIED_CROP_ET_CANOPY_VIEW_READINESS_READY_FOR_RESTRICTED_PROVIDER_CANDIDATE`

This workunit is readiness-only. It does not add or move production crop physics, does not bind the ET provider into runtime, and does not admit additional ET options.

## Source authority

F-WOF43 starts from canonical head `f49e17c6627717d5dea181808a122f2e35960739`, after F-CI24 admitted the restricted stateless F-PM06A reference-ET demand provider.

Frozen legacy source authority is the user-supplied SWAP 4.3.1 archive:

- outer archive SHA256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- nested `SWAP.ZIP` SHA256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`
- `SWAP/MOD_cropdevelopment.f90` SHA256: `c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf`
- `SWAP/interface_plant.f90` SHA256: `2295a17a9597f016ed8ec538eede7c9400da0819914e96f7d641597ce71f64df`
- `SWAP/fixed.f90` SHA256: `1d57e86f0bf067e8432da69f46cd19e0df6768b9c6bcf560d2221248f3b12f75`
- `SWAP/wofost.f90` SHA256: `3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b`

Upstream architectural evidence:

- F-WOF18 qualified the restricted no-interception reference-ET transpiration equation but explicitly left binding of `vcover`, `CF`, and `fco2tra` open.
- F-WOF19 classified `vcover` and `CF` as reconstructible rather than committed state, and `fco2tra` as a nonpersistent input.
- F-WOF29 qualified compact immutable B1.10 AFGEN table semantics.
- F-WOF42 qualified crop persistence-layout completeness.
- F-PM06/F-PM06A/F-VQ35/F-CI24 qualified the ET process boundary and the canonical restricted stateless demand provider without runtime binding.

## Exact source-bound reconstruction

### Crop emergence

`fl_cropemergence` is crop lifecycle state. It is not reconstructed by ET. The crop owner supplies the corresponding read-only `crop_emerged` value from the exact crop snapshot used for the process evaluation.

### Vegetation cover

Legacy common crop-development code computes:

`vcover = 1 - exp(-kdir * kdif * lai)`

The formula is executed after crop-period/emergence processing. `KDIR` and `KDIF` are crop parameters read for both fixed crops and WOFOST crops. `LAI` is dynamic crop state.

Therefore:

- `LAI` remains crop-owner dynamic state;
- `KDIR` and `KDIF` are immutable crop/template parameters;
- `vcover` is a derived read-only crop/canopy view;
- `vcover` must not become ET persistent state.

The restricted F-PM06A source consumes vegetation cover for surface evaporation demand even when `crop_emerged=false`. A new crop-to-ET provider must therefore not enforce `vcover=0` merely because the crop-emergence flag is false. It must derive the value from the supplied state and parameters. Normal owner lifecycle state may naturally yield zero cover outside the crop period, but that is not an ET-side gating rule.

### Crop factor

For `SWETR=1`, legacy requires `SWCF=1`. The crop factor is reconstructed as:

`CF = AFGEN(CFTB, DVS)`

`CFTB` is crop input/parameter data and `DVS` is dynamic crop state. The old DVS/CF paired input form is deprecated in legacy and is normalized into the same table representation before evaluation.

Therefore:

- `DVS` remains crop-owner dynamic state;
- `CFTB` is immutable shared crop parameter data;
- `CF` is a derived view valid for the active crop;
- `CF` must not be persisted per column solely for ET;
- F-WOF29 `wofost_rate_table_t` is an already-qualified substrate for B1.10 AFGEN endpoint clamp and linear interpolation semantics and should be reused instead of adding another interpolation implementation.

### CO2 transpiration factor

Legacy initializes:

`fco2tra = 1`

When crop CO2 correction is enabled it evaluates:

`fco2tra = AFGEN(CO2TRATB, CO2)`

`CO2TRATB` is crop response parameter data. `CO2` is the atmospheric concentration selected for the current time. Legacy selects it through year/file logic, but that selection mechanism is adapter/forcing preparation, not kernel physics.

Therefore:

- `CO2TRATB` is immutable shared crop parameter data;
- atmospheric `CO2` is forcing with an explicit validity interval/event schedule;
- the enable/disable choice is physical crop configuration;
- `fco2tra` is a derived nonpersistent crop-to-ET view;
- when CO2 correction is disabled, the physical factor is exactly 1;
- no calendar-year lookup, file name, parser, or path belongs in the provider or ET kernel process.

## Minimal crop-to-ET view contract

A later structural provider should expose conceptually:

- `crop_emerged`
- `vegetation_cover_fraction`
- `crop_factor`
- `co2_transpiration_factor`
- validity/diagnostic information sufficient to fail closed on active dependencies

The view is read-only and ephemeral. It is evaluated from an explicit crop snapshot plus immutable parameter references and, where active, atmospheric CO2 forcing.

The interface must not expose legacy globals, crop file structures, calendar lookup internals, WOFOST rate solver scratch, hydraulic state, or ET state.

For an inactive/non-emerged crop route, downstream ET must not require crop-specific `CF` or `fco2tra`. This preserves the dependency-minimal behavior already qualified by F-PM06A/F-VQ35. The cover value remains separately meaningful because the source equations consume it for `peva` and `epond` independent of emergence.

## Parameter substrate gap on current canonical

The current canonical `wofost_rate_parameter_bundle_t` contains `KDIF` as `diffuse_extinction_coefficient`, but it does not contain the complete parameter set needed by this view:

- `KDIR` is missing;
- `CFTB` is missing;
- `CO2TRATB` is missing.

This is an implementation gap, not an unresolved ownership question.

The restricted provider candidate should add the smallest shared immutable crop/canopy parameter contract required by the admitted route. It should reuse the qualified F-WOF29 table substrate for `CFTB` and `CO2TRATB`. It should not duplicate the full WOFOST parameter bundle merely to satisfy ET.

Because `KDIR`, `KDIF`, `CFTB`, and `CO2TRATB` also exist for the common crop-development layer, the logical contract should not be hard-wired to WOFOST-only crop physics. Fixed-crop and WOFOST parameter adapters may both populate the same semantic crop-canopy parameter view.

## State classification

Committed persistent crop state needed by this restricted view:

- `crop_emerged`
- `DVS`
- `LAI`

Immutable shared parameters:

- `KDIR`
- `KDIF`
- `CFTB`
- CO2-correction enable/configuration
- `CO2TRATB` when CO2 correction is active

Forcing:

- atmospheric `CO2` concentration when CO2 correction is active

Derived process view, never persistent continuation state:

- `vcover`
- `CF`
- `fco2tra`

Not owned here:

- reference ET forcing
- `ptra`, `peva`, `epond`
- actual root extraction
- actual soil or pond evaporation
- interception storage
- hydraulic state
- mass-ledger totals

## Time contract

The provider evaluates a view for an explicit process evaluation time/span. No day, month, year or midnight is fundamental.

Legacy daily call order is translated as follows:

- crop lifecycle events determine which crop snapshot is active;
- crop state supplies current DVS and LAI;
- atmospheric CO2 forcing supplies a value valid for the evaluation interval;
- forcing changes or crop lifecycle events create runtime event boundaries where required.

A legacy calendar year may be used by an external adapter to construct atmospheric CO2 forcing. It must not appear as a requirement of the kernel-facing crop-to-ET view.

## Transaction contract

View construction is pure/read-only with respect to crop continuation state.

For a trial:

1. bind the exact trial or committed crop snapshot appropriate to that runtime phase;
2. derive `vcover`, `CF`, and active `fco2tra` without mutation;
3. evaluate ET demand;
4. rejection discards the ephemeral view and ET result;
5. no crop state is advanced or committed by view construction.

A rejected hydraulic trial must not cause crop lifecycle advancement, parameter mutation or CO2 forcing advancement.

If crop evolution itself is trial-local, the view must carry or be associated with the same snapshot lineage/revision so that a retry cannot accidentally mix a new crop state with an old ET demand.

## Mass contract

This view contributes no water mass itself.

It provides dimensionless factors to the potential-demand process. `ptra`, `peva`, and `epond` remain potential demands. Actual root uptake and actual evaporation are separate owners and enter the authoritative water ledger exactly once only after their accepted physical fluxes are known.

## Optionality

- With no active crop, no crop-specific factor table evaluation is required.
- With CO2 correction disabled, no `CO2TRATB` or atmospheric-CO2 forcing is required for this factor; `fco2tra=1`.
- No derived canopy factor is stored persistently per column.
- Shared tables and light-extinction parameters are template/parameter objects, not copied into every column state.

## Migration slices

1. **F-WOF43A, restricted parameter/view provider candidate**: implement the common crop-canopy parameter contract and pure reconstruction of `vcover`, `CF`, and `fco2tra`; reuse F-WOF29 tables; no runtime binding.
2. **Independent F-VQ qualification**: rederive all three formulas from frozen B1.10 source, test fixed and WOFOST-compatible parameter paths, active/inactive CO2, endpoint/interpolation cases, non-emerged cover semantics, invalid active dependencies, O0/O2 identity, and A-B-A replay.
3. **Canonical source admission**: admit exact qualified provider source without changing crop owner, ET demand, root uptake or runtime behavior.
4. **F-MR23 runtime composition**: bind crop snapshot + parameter refs + CO2 forcing to the canonical F-PM06A demand provider; publish `ptra` to the existing root-uptake input seam. Keep `peva/epond` as demands until their actual-flux owners are separately composed.
5. Broader ET/canopy physics only in later units: interception, wet-canopy partition, SWREDU state, Penman-Monteith and actual surface evaporation.

## Invariant audit

- I/O separation: PASS. File/year selection stays outside the provider.
- Data separation: PASS. State, parameters, forcing and derived view are explicit.
- Compact state: PASS. No `vcover`, `CF` or `fco2tra` continuation state.
- Scratch ownership: PASS. No solver scratch.
- Transactionality: PASS by read-only reconstruction, subject to later runtime lineage binding.
- Cheap replay: PASS by deterministic derived view.
- Generic time: PASS. Atmospheric CO2 is interval/event forcing, not a kernel-year lookup.
- Mass conservation: PASS. View has no authoritative mass contribution.
- Shared physics: PASS. ET consumes crop-owner factors and does not implement crop development.
- Solver isolation: PASS. No hydraulic internals.
- Optionality: PASS. CO2 tables/forcing only required when enabled; no per-column derived-factor state.
- MultiSWAP: PASS by shared immutable parameter/table references and stateless view construction.
- No silent dependencies: PASS if the later candidate makes the required parameter set and active validity explicit.

## Exit boundary

F-WOF43 qualifies the ownership, reconstruction equations, data classes, time semantics, transaction semantics and migration route for the restricted crop-to-ET canopy view.

It does **not** qualify a production provider, parser adapter, runtime binding, actual ET flux, interception, Penman-Monteith, SWREDU, or any broader crop lifecycle physics.
