# Joint empirical root and no-drain bottom frost contract

Status: canonically admitted via PR #1036, merge
`d3bb48eb2407cdc8a3a089f37cc689f6a940dddb`.
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

## Completed local qualification

The complete current-canonical preservation gate passes at merge `bb599a6ccebf14f8a737d324acc084bd6bfe4a82`, source tree `dfacb3342763c9705dce2b3c5b84c0369ce24203`. Final focal O0/O2 tests additionally cover both signs of top-only/warm profiles on identical production modules. All 18 signed method/regime cases, four thermal cases, application, committed restart, fine direct continuation and B1/B2/B3 preservation pass. Both salinity compositors with both transports pass their full original fresh-build runners, including independent-process restart byte identity. Source manifests match the final current files. Durable replay: `docs/audits/evidence/PPA_WU05B4_LOCAL_REPLAY.json.gz`.

Observed horizon errors against 2048 direct steps are 6.899199e-9 cm in head and 2.163334e-5 C in temperature, within retained 1e-6 cm/1e-4 C bounds. Hard water residual remains 1e-12 cm. This is completed local evidence, without a queued Actions or all-workflows-green claim.

Canonical central admission verifies final tree/source identity and the scoped
local evidence; `PPA_WU05B4_CANONICAL_ADMISSION.json` is the admission authority.
Drainage is still separate and the aggregate frost migration remains open.
