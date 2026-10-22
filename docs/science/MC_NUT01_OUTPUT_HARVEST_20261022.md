# MC-NUT01 joint generation at existing harvest boundaries

Status: implementation candidate. Admission remains separate from testing.
Baseline: `80dbce8d325e9197a53b7189ad184bcdf91f6f5c`.

The existing crop/soil owner already owns configured harvest, one-time residue
incorporation, end-status observation acknowledgement and compact retirement.
The new adapter stages one selected phase on a local chemical copy, writes the
existing complete physical/diagnostic/history generation, then publishes chemical
state. Unknown, premature and repeated phases reject. A failed save cannot publish
the biological phase. CSV-only failure means the new generation and chemical phase
are already committed, exactly as in the existing daily output API.

Water, diagnostic state and report history are intent-in. No hydraulic time,
revision, lineage, diagnostic clock, totals, extrema or report row advances at a
biological boundary. The physical codec already owns harvested/consumed/retired
phase identity. No new schema, cursor, shadow crop, event receipt or N inventory
is introduced. Retirement still requires the existing detached observation
receipt. It acknowledges an application observation, not proof that external I/O
occurred. The adapter does not acknowledge automatically or bypass that contract.

Authenticated `swap.f90` orders harvest before output and reset after output.
`management_soil.f90` task6 uses saved previous-day `_1` residue values. The eight
existing diagnostic quantities are therefore preserved, not incremented with
harvest exports or current retained residues. This is joint persistence of the
existing biological phases, not complete historical harvest-day/fallow/rotation
diagnostics. Subsequent-day saved harvest-return reporting needs its own traced
contract. Active-crop negative allocation and general/default orchestration also
remain open; aquifer and new RossFast are excluded.

Invariants2,3,4,7,9,13,21,23,26,29,30: one physical owner, immutable diagnostics,
atomic save/publication, explicit biological phases outside the hydraulic solver.
No existing production source or shared backend changes.

Selected tests: current cold/native O0/O2 closure once, then actual original and
output-aware thermal two-day execution, new harvest-phase composition, exact manual
physical bytes and independent-process continuation at pending, incorporated and
retired phases. Check premature/replayed phases, missing/stale acknowledgement,
late save rejection, CSV-only failure and complete generation reconstruction.
Existing original chemistry, crop/N, water balances, harvest and physical restart
assertions remain active. Hash-reuse only same-execution current provider artifacts.
The roughly331-provider closure is necessary for real accepted states and physical
codecs; expected360s cold plus150s thermal/phase drivers, explicitly selected once.
No full730-day, broad F-CI, highest low-air or unrelated component requalification.
Keep failed/censored events; unmeasured physics/controller time is UNKNOWN.
