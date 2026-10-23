# Sole constant crop sink after mineral depletion

Bounded MC-NUT01 candidate after PR1414. Baseline
`46ad5dbbb2cc222e452e0f72453dc4bd89bbc32c`.
Contract: `integration/mc-nut01/crop_only_depletion/CONTRACT.md`.
Admission requires its separate actual-merge receipt.

For a mineral form with zero prescribed top concentration and nonnegative net
mineralisation, a negative constant production term can only be prescribed crop
demand. There is no choice between competing constant sinks. The existing
corrected finite-donor receipt therefore belongs entirely to the crop. Its
negative surrogate top rate divided by depth becomes actual signed production;
physical top actual/unmet stay zero. The original Management_Soil crop identity
is unchanged: mass-flow uptake plus prescribed production minus actual production.
NH4-first ordering and averaged nitrification supply to NO3 remain historical.

The bounded corrected reference is the unchanged SWAP-020 routine at the pinned
baseline, SHA256 `24cbcd01bb53a9ce054433a8bd62e18e0080fe7bdcd89bdc0c41e8f6ee2dba13`.
It was admitted through PR1350; no new global B1 tag is implied. Direct tests
compile that routine before production and retain all generated adapter bytes.
All576 depleted daily cases match its complete result exactly in the measured
O0 run and agree with an independent event-constrained DOP853 oracle to8.07e-14.
Current whole N residual is below8e-16kg/m2. Immutable B0 WaterN is also executed:
constant-capacity/no-boundary cases with nonempty donors agree within3e-12,
but variable-capacity depletion and continuing boundary loading expose old
accounting defects. Maximum valid B0 whole-N residual is6.00e-5kg/m2 in this
test grid;48 B0 daily cases reject. Those results are retained, not relabelled
as corrected-reference equivalence. Default execution is unchanged.

Actual juvenile crop/Richards/N profiles must demonstrate depleted NH4 and both
forms, finite positive initial uptake, supply below demand, strict whole-N
closure, process restart and rejected-state equality. All13 incumbent profiles,
384 direct predecessors, all original HIST assertions and all198 predecessor
controls remain exact. Negative net mineralisation or a nonzero prescribed
top-N sink remains fail closed after exhaustion. Competing constant-sink
allocation, automatic snow/persistent-surface N and full NUT stay open.
