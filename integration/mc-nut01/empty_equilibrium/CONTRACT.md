# Empty homogeneous mineral pool

Candidate MC-NUT01 extension, baseline03c1c7a41d66924e2d974275cd14d4bdc4101047.
Owner: daily mineral exchange. Invariants3,7,13,21,23,25,26,30.

In the explicit nondepleting signed-top route, accept the exact zero solution
when initial concentration, signed production and top concentration are all
zero and each remaining boundary has zero flux or zero concentration. This is
the homogeneous original WaterN equation: C(t)=0, average=0 and zero
concentration-dependent uptake. The
existing analytical solver, all validity checks, depletion-time and unmet-sink
guards remain active. A demand candidate may exhaust and lose to that empty
supply candidate. Zero NH4 can coexist with positive NO3 supply. An exactly
cancelling mineralisation/juvenile-demand branch also stays at zero while its
prescribed crop uptake equals the mineral source. No tolerance,
allocation policy, public interface, state/restart schema or default changes.
Unbalanced prescribed sinks, including juvenile constant crop demand and net
immobilisation, still reject when selected. Complete mineral depletion with
competing sinks and snow/persistent-surface N remain open.

Require real production O0/O2 direct driver, independent ODE and original WaterN
comparison, all previous288 daily exchange cases byte exact, default byte
preservation, nonzero-sink negatives; actual crop/Richards/N composition with
empty NH4 and both empty forms, exact restart/rejection and all11 incumbent
profiles exact. Execute all original HIST assertions with verified unchanged
closure reuse and fresh changed/transitive compilation; retain all179 prior
controls. No full F-CI, RossFast or retired highest low-air selection.
