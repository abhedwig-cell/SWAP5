# Unused exhausted demand candidate, bounded correction

Locally qualified implementation; canonical admission pending.

The historical Management_Soil rate routine compares demand and supply candidates
and selects the higher final concentration for each mineral form. The admitted
nondepleting mode rejects a demand trial immediately when it exhausts its donor,
before testing the potentially valid mass-flow-limited supply candidate.

An exhausted trial is now marked explicitly inside the private transport adapter.
Only that diagnosed exhaustion may pass the demand-branch preliminary check.
The existing supply branch must still execute successfully with strictly positive
end concentration, no depletion and no unmet extraction. The exhausted demand
candidate has C_end=0 and therefore cannot win the existing comparison. Its
partial average, adjusted production and top removal never become authoritative.
Any ordinary invalid transport or exhausted selected supply still rejects.

This is the original selector ordering extended to an unused trial, not a new
allocation rule after physical exhaustion. Juvenile single-candidate semantics,
NH4-first ordering, net mineralisation, N balances and all default routes retain
their equations. No public interface, persistent schema or tolerance changes.
Actual exhausted competing-sink partition and automatic snow/pond binding remain
open. No master promotion. Affected invariants:3,7,13,21,23,25,26,30.
