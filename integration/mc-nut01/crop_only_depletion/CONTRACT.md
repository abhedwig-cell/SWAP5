# Sole constant crop sink after mineral depletion

Candidate MC-NUT01 extension, baseline46ad5dbbb2cc222e452e0f72453dc4bd89bbc32c.
Owner: daily mineral exchange. Invariants3,7,13,21,23,25,26,30.

Within explicit signed-top mode, admit an exhausted selected branch only when
its original top concentration is exactly zero, net mineralisation is
nonnegative and its signed constant production is negative. Thus the sole
negative constant contribution is crop demand. Concentration-dependent root,
nitrification and denitrification terms remain in the original equation.

Reuse the existing corrected finite-donor endpoint and time-mean response.
The surrogate top receipt divided by depth is actual signed production; its
unmet part belongs to unmet crop demand, not to the physical top boundary.
Restore zero top actual/unmet and leave the existing historical crop-supply
identity unchanged: root mass flow plus prescribed production minus actual
production. Mineralisation remains fully accounted. Existing NH4-first, juvenile
and demand/supply selection equations remain unchanged. Exhausted unused demand
still loses ties. No public interface, state/restart schema, tolerance or default
changes. Nonzero prescribed top-N sink or negative net mineralisation remains
fail closed after genuine depletion; competing constant-sink allocation is open.

Require real O0/O2 direct production driver, independent event-constrained ODE,
nonnegative endpoints/uptake and whole N balance; exact preservation of all384
previous signed cases and all default cases. Compare unmodified historical
WaterN, retaining measured discrepancies rather than forcing equivalence.
Require actual Richards/crop/N juvenile-depletion profiles with inventory-limited
uptake, native process restart, whole-state rejected-trial equality and all13
incumbent profiles exact. All original HIST assertions and all198 predecessor
controls remain. Fresh changed/transitive compile closure and all78 native
processes, with source/flags/compiler/module-bound reuse only. Full F-CI,
RossFast and retired highest low-air are not selected. Snow/persistent-surface
N, genuine competing-constant-sink allocation and full NUT remain open.
