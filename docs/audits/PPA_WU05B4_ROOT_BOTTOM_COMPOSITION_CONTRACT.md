# Joint empirical root and no-drain bottom frost contract

Status: preregistered implementation candidate, not canonically admitted.
Authorities are the separately admitted PPA-WU05B2 root cutoff/compensation and
PPA-WU05B3 no-drain FrozenBounds rule. PPA-WU05B4 composes those physical options
without introducing a new equation or changing their cutoffs, ordering or indexing.

The bottom selector and the root cutoff consume the same immutable trial-start
state. One final root sink, after selected Jarvis/Walsum or OFF compensation,
goes through the existing root provider. One final prescribed bottom proposal
goes through the existing boundary. Existing solver flux and actual root sink
remain the only mass and accepted-publication owners. No saved modified proposal,
new committed state, restart field, solver or ledger is introduced.

Joint numerical policy is the maximum of the independently specified B2 root
norm and B3 boundary norm. Both configurations must retain finite positive local
budgets. This policy cannot weaken either independent acceptance condition.
A root zero-cutoff disagreement or terminal boundary-blocking disagreement in
full/half states requires refinement. A local budget does not imply the same
cumulative horizon accuracy.

The required actual matrix includes both signs of allowed/blocked bottom proposal,
OFF/Jarvis/Walsum, mixed and fully frozen root profiles, no resurrection of frozen
roots, independent storage = bottom exchange minus accepted transpiration,
1e-12 cm hard water closure, actual retries, fine direct continuation, fresh
committed restart and normal application execution. Incumbent B1/B2/B3 and
canonical selected salinity behavior must be preserved on the final source.

Drainage redistribution, salt/frost, Bartholomeus, macropores, groundwater-owned
boundary, corrected last-node indexing and phase-change physics remain separate.
Affected invariants: 3, 4, 5, 7, 13, 22, 23, 25 and 26. Shared runtime/application
admission and temporal-policy composition are the owned surfaces; physics modules,
state/restart schema, solver, mass ledger and salinity owners are held fixed.
