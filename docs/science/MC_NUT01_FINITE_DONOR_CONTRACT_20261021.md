# MC-NUT01 finite-donor negative aggregate

Status: production candidate, qualification pending. Baseline canonical
`437d96ff51ac8a5825b605caf788661848c88be5`. Owner: MC-NUT01.
The existing HIST-COMPLETE record remains the recovery/admission authority.

## Corrected reference and donor

The [isolated reference contract](https://github.com/abhedwig-cell/SWAP5/blob/work/nut-negative-reference-20261021/reference/swap-4.3.1/patches/SWAP-020/CONTRACT.md)
defines the finite aggregated soil-N donor, including original linear NH4
sorption. This bounded corrected-reference decision retains the historical
aggregate convention chosen by the programme owner. It does not give pond runoff
the soil concentration or add a pond-N inventory.

Original complete-caller O0/O2 executes14 native models and120 daily N steps.
Independent unrounded form and whole-N books give maximum whole-N residual
2.6020852139652106e-18kg/m2, relative9.173895969097472e-15. Eighty valid and four
invalid direct inputs per optimization cover all five analytical classes,
sorption, empty/depleted/ample donors and continuing sources. An independent
numerical ODE agrees within4.73e-15 in the observed fields. These are completed
local reference observations, pending sealed evidence. Published B1 snapshots
remain immutable; no unrestricted B1.13 is implied.

## Existing production interfaces

The existing transport module adds a bounded evaluation procedure. Existing
mineral/reactive owners, crop fallow entrypoint and direct joint application
accept an additive optional `finite_donor_top` argument, false by default. It
requires explicit negative `historical_top_water` and the existing atmospheric
opt-in at the joint boundary. The joint crop must be retired, without pending
residues or root extraction. Active demand and immobilisation are excluded.

The routine obtains exhaustion time from the analytical trajectory. Its
concentration integral covers the actual pre-exhaustion duration. Continuing
nonnegative production and positive boundary loading supply the constrained
extraction after exhaustion. Actual extraction enters external output; nominal
requested extraction and unmet amounts have separate per-form receipts. Unmet
extraction is a diagnostic, never a stock, source, debt or deferred removal.

Nitrification is debited from NH4 and credited to NO3 once. Denitrification and
transported outflow remain external sinks. Mineralisation cancels between
organic and mineral inventories. Units:kgN/m2, kgN/m3 and m/day.

No physical state, parameter vector, restart schema or solver interface is
added. The optional choice is interval forcing semantics, supplied again after
restart. Cumulative diagnostic receipts belong to the application's test journal
and are qualified separately from native physical restart. Existing absent/false
argument trajectories retain their calculations.

## Qualification and limits

The direct mineral owner O0/O2 gate passes against the corrected reference,
including explicit default rejection, independently known emptying, failure
atomicity and opaque reconstruction. Stable qualification selects the complete
existing HIST physical matrix because active/fallow chemistry consumers compile
the changed providers. All fourteen predecessor endpoints, previous transition
restarts and existing assertions remain requirements.

Additional actual Reference Richards/retired-crop/Soil-N runs use low/high
mineral stocks, wet/drying water steps, source pulses, negative extraction,
original reactions, whole-N closure, hydraulic/chemical rejection and fresh
process continuation after days1/6. The journal contains cumulative per-form
requested/actual/unmet extraction, internal conversions, gas loss and budgets.
The existing retained owner remains required. Full moving F-CI follows actual
compiled dependencies; no new RossFast/aquifer or SOL/PERF production changes.

Automatic persistent-pond/snow binding, active-crop allocation among negative
sinks, immobilisation and near-degenerate analytical coefficients remain
unsupported. Explicit historical aggregate forcing is not automatic pond
chemistry or full migration. Existing common water, solute, age, restart and
numerical contracts are read-only. Affected invariants:3,7,13,21,23,25,26,30.
