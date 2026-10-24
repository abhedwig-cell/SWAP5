# Nonjuvenile proportional partition candidate

Baseline47a50ea0bcf0dd17e4c32e502ee0917e689cb9f8, after PR1422.
Extend the same default-false forcing option to active nonjuvenile crops.
Organic immobilisation remains excluded. The mineral equation and equal-priority
constant-sink partition are unchanged.

Evaluate both historical alternatives separately: a constant demand-limited
crop sink and a concentration-dependent root supply sink. Select the smaller
actual crop uptake, taking the entire corresponding concentration trajectory
and actual/unmet top receipts. The concentration comparison alone cannot
discriminate exhausted candidates when both endpoints are zero. NH4 uptake
reduces the remaining NO3 request. Demand ties select demand deterministically.

The direct oracle independently integrates both alternatives, locates their
zero events and selects by actual uptake. It covers critical-LAI and DVS-based
nonjuvenile entry, zero/large root coefficients, continuing sources, different
water-capacity trends and zero demand. Bound only64-epsilon subtraction error
at exact uptake limits; larger oversupply rejects. This prevents a negative
remaining NO3 request caused solely by cancellation in source minus production.

Selection: direct2016 O0/O2 cases and2496 byte-exact predecessor executions;
actual4 eight-day crop/Richards runs with8 process restarts; default30 runs and
60 restarts; original HIST78 assertions. The changed daily provider's binary
compiler module interface must remain byte exact before runtime object reuse.
All other source/object/module identities are checked. HIST recompiles the
changed/transitive module closure with unchanged source/flags/object binding
for other providers. Expect under three minutes; no new highest low-air,
RossFast or broad FCI selection by branch advance. Preserve failed raw rounds.

Not admitted until current owning guards, corruption controls, documentation,
canonical overlap and actual merge proof complete. Prior PR1422 capsules retain
their own qualified scope; no current PASS is inferred for the expanded domain.
