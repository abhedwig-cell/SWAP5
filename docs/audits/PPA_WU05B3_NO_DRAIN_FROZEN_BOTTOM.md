# PPA-WU05B3 no-drain FrozenBounds successor

Status: locally qualified on current canonical Walsum-salt/root-frost composition;
not yet canonically admitted. Baseline `a370f6f487c017af9931ffc46d4c5c9fb1288d8c`.
The preregistration and qualification are in `integration/audits/PPA_WU05B3_*.json`.

The explicit physical option applies the original no-drain FrozenBounds rule on
ordinary prescribed-qbot Reference columns. It suppresses both signs only when
the deepest frozen node is greater than one and the available air volume is
strictly less than 0.01 cm. Bottom-up air traversal always includes the bottom
node and stops before a preceding node whose hydraulic factor is <= 0.01.
Air equality is allowed; the temperature comparison uses TFROSTEND + 1e-6 C.

Compatibility deliberately retains the original deepest-node search over 1:n-1,
including its last-node omission. This is not a corrected-reference claim.
The no-drain rule only needs a node index, so the migrated code never evaluates
the unused frost-depth interpolation or its possible zero denominator.

One pure typed selector consumes immutable trial-start temperature, water content,
saturation, thickness, hydraulic factors and the unmodified boundary proposal.
Its final proposal goes into the existing Richards boundary. The solver's actual
flux remains the sole mass-accounting and accepted-publication authority. Every
trial recomputes the selector; no modified proposal is cached as original forcing,
and no committed state, restart field, solver or ledger is added.

A separate numerical config requires finite positive head and temperature budgets.
Full/half error is their dimensionless maximum. Different terminal blocking decisions
force refinement. The qualification fixture uses 1e-6 cm and 1e-7 C local budgets.
An initial 1e-6 C local budget failed the retained 1e-4 C cumulative horizon bound
against 2048 direct continuations: measured 1.015612e-4 C. Tightening the local
budget gives 2.163335e-5 C maximum horizon difference and 3.078497e-10 cm in head.
No cumulative 1e-7 C claim is made, and the horizon tolerance was not weakened.

Unit oracles enumerate independent freeze/barrier/sign cases, exact and adjacent
thresholds, last/top/one-node behavior, invalid inputs and exact OFF identity.
Real runtime tests cover saturated blocking for both signs, allowed flux for both
signs, independent storage/flux accounting, actual temporal retries, direct fine
continuation, fresh replay, committed restart into an empty registry and the normal
application owner. Water residual remains bounded by 1e-12 cm. Missing budgets,
combined root/boundary scope and drainage redistribution fail closed.

All focused O0/O2 outputs agree. Existing B1 hydraulic frost, B2 root frost,
Jarvis/Walsum, both salinity compositors and both transport variants pass. The
entire moving canonical preservation gate passes at executed merge
`5d08bb936da38b199f504b664b2fa6177c069b0c`; production source tree
`12575996d9ffd1558363054650b612670966fe7c` equals remote reconciled checkpoint
`32aafef400efce1fc08dc3dfc5f85e1135794b37`. Durable replay evidence is
`docs/audits/evidence/PPA_WU05B3_LOCAL_REPLAY.json.gz`.

Excluded: active drainage, joint root uptake/bottom-frost composition, salt/frost,
Bartholomeus, macropores, groundwater-owned boundary, corrected last-node geometry,
latent heat and ice inventory. This does not complete all frost migration.
The source reassessment is [FrozenBounds source reassessment](PPA_WU05B_FROZEN_BOUNDS_REASSESSMENT.md).
