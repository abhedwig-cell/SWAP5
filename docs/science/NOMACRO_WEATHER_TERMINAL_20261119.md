# Original detailed-weather terminal water receipt

Implementation checkpoint; qualification and canonical admission pending.

Actual canonical `ef5010a83e83f879254af534bf0dd9cfcdbf3a85` reproduces
both sealed H failures on day364 with exact original input hashes. The
independent whole-day and kernel receipts exceed the unchanged `1e-10 cm`
limit although the accumulated soil trial residual remains just inside it.
The failed attempts and unchanged accepted prefixes remain evidence.

This batch composes the existing complete terminal receipt with experimental
compatibility-output CDE, original time stepping, bottom6, explicit
conductivity, analytical soil, hysteresis0, no snow/frost/aquifer, drainage1
and numeric heat. Selection requires original detailed rainfall or detailed
meteorology. This is a bounded numerical coupling change (B), with no new
physical equation or state owner.

Before terminal acceptance, the original double cumulative flux and stock
terms are independently summed in extended precision, as in the existing
terminal receipt. Inactive snow rates and stores are not read. This adds a
strict rejection criterion alongside the unchanged soil trial criterion.
Original Newton iteration and rollback handle rejected trials. No physical
store, flux, checkpoint, input or tolerance is repaired. Invariants3/4/7/13/21/23
remain binding. Other configurations delegate literally.

The first actual terminal-receipt run still refuses day364. Its diagnostic
shows all28 projected terms exactly equal the refused day's published terms;
the projection is correct. Original HeadCalc accepts an exhausted Newton trial
at input DTMIN. The bounded composition therefore also reuses the already
qualified strict implicit rollback/reduction implementation with its selector
changed to this explicit weather domain. Only actual nonconvergence permits
reduction below input DTMIN; the same original factor and8ULP clock floor
remain binding. This is a numerical legacy correction, not a fallback after
a rejected day. This extension remains unqualified until actually tested.

Strict terminal-only reduction reaches the8ULP floor in both actual O0
controls, after363 accepted days. No rejected day is published. Checking only
the final trial discovers an accumulated discrepancy too late. The next
persisted candidate applies the complete receipt at every trial using exactly
the existing elapsed-day `1e-10*(t1900-budget_start+dt)` criterion. Its actual
test outcome must be recorded separately; no successful correction is claimed.

Actual fcfc74dab Windows O0/O2 now completes both1096-day trajectories with
unchanged water/CDE bounds. Pulsed own cold5windows/opt are exact. Hourly
cold530→532 diverges on day532: day531 water/CDE receipts and macro.bin are
exact, but original result.end root-depth/distribution fields already differ.
The read-only root witness at3bdfdd5e9 identifies the missing dependence:
hourly cold day531 has exactly1/6 less integrated wet/dry root stress while
demand, actual uptake, biomass rates and the starting root depths are equal.
Original Integral integrates MOD_re_global.alpwetnoddrz/alpdrynodrtz also
during zero-demand hours, when the root routine leaves their saved values
untouched. The first four hours after cold initialization lose that carry.

The pending bounded hourly codec S5WRH001 therefore appends precisely those
two original saved factors, with108bytes of typed domain/clock/duplicate value
validation. Restoration is deferred until original crop initialization ends.
The accepted day includes the actual original factor witness; preworker and
candidate/publication checks bind it to the native bytes. This introduces no
new physical store, root law, normalization, repaired checkpoint or input.
Actual exact native and affected dependency qualification are still required.

## Acceptance authority and measured scope

The owning historical H gate is `check_hupsel51_repair.check`: the actual daily
kernel and independently recomputed daily water receipt retain their existing
`1e-10 cm` limits. The existing CDE ledger also independently retains its
`1e-10 mg/cm2` daily and integrated inventory limits. The new independent
reader uses these owning criteria, not another family's different full-period
water qualification contract. It additionally reports integrated water drift:
the main1096-day observations are approximately-2.60e-10cm for pulsed rain and
+2.65e-10cm for hourly weather; uniform rainfall is about+1.68e-10cm on Windows.
These are measurements, not a claim of1e-10cm integrated water closure or
whole-model scientific equivalence. No tolerance or prior gate is changed.
Functional historical closure remains PARTIAL, science NOT_QUALIFIED and the
fixed named RC3 profiles remain unchanged.

Qualification must use the exact sealed H physical inputs, local O0/O2,
the affected complete periods, independent daily ledgers and own native cold
windows across day364 and crop/year boundaries. Prior unrelated periods are
not selected. Verify actual composed source and canonical postimage before
claiming admission. Whole historical closure stays PARTIAL; science stays
NOT_QUALIFIED and fixed RC3 is unchanged.
