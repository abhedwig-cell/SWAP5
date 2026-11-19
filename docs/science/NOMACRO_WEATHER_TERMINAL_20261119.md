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

Qualification must use the exact sealed H physical inputs, local O0/O2,
the affected complete periods, independent daily ledgers and own native cold
windows across day364 and crop/year boundaries. Prior unrelated periods are
not selected. Verify actual composed source and canonical postimage before
claiming admission. Whole historical closure stays PARTIAL; science stays
NOT_QUALIFIED and fixed RC3 is unchanged.
