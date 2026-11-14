# G original hydraulic constitutive/averaging and Darcy evaporation

WORKSTREAM SWAP5-NOMACRO-COVERAGE01, branch codex/nomacro-coverage07 from
canonical2ac504bbc, F admitted PR1680 exact tree2fd7a6185. FrozenRC111529865e.
Peers last read PERF5b68e5438 (pycache only), macro7551d92dc clean; untouched.
Relevant authority: current Status-A, original reader/read_ini/soilwater/functions
and coverage register. Invariants2/3/7/13/21/23/26/27/29/30 preserved. No new
physical/runtime interface, solver, numerical repair or state codec selected.

Source audit: original readswap.f90 accepts SWKMEAN1..7; functions.f90 implements
1/2 arithmetic,3/4 geometric,5/6 harmonic,7 separately read Szymkiewicz tables.
Old SWP comments incorrectly describe7/8 as logarithmic;8 has no implementation
and is outside the original reader. Keep7/8 refused here. Direct3..6 routines
already execute inside unchanged Richards; only experimental adapter admission
prevents general selection. SWREDU0 is the original Darcy evaporation option;
no new physical law. SWSOPHY1 dispatch and native state already exist, but no
hydraulic table files exist in the pinned distribution. Use explicit derived
monotone head/theta/K data as distinct physical input, not claim original MvG
or an independent historical reference. Original reader owns numeric constraints.

Cohort: four mean choices3..6, Darcy evaporation0, chemical soil tables and
water-only soil tables,7 complete1096-day periods. Tables have two distinct
layers and are hash-bound with original input. No SWKIMPL/frost/history/7-table
expansion. Select actual touched-unit/controller O0/O2 builds, full O2 periods,
native2/365 and active530 suffixes at both optimizations, independent instances,
strict water/active-chemical closure, external discard/replay/disk recovery and
refused inconsistent mass. Compare unchanged original executable diagnostically;
retain every failure. Existing physical default source/policies remain exact;
changed preflight SHA requires fresh experimental bundles, no capsule rebinding.
Cost expected under20minutes on own runner, no platform/performance campaign.
This is essential uncovered original-option functional risk, not repeated
qualification of unchanged original physical components. No G PASS claimed yet.
