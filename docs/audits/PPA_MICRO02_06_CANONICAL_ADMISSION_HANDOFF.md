# PPA-MICRO02 through MICRO06 canonical admission handoff

Status: candidate for a bounded post-Status-A admission, draft PR #1077.
Canonical target is `integration/f-ci-canonical` at
`e5eab995ef04fc813dd644025fb0f32e4f5050a1`. The stack is a direct
descendant of that target. The frozen Status-A denominator stays fixed.

Owned surface: the optional normal de Willigen MICRO process, corrected
MICRO01 M/K table binding to standard MvG, explicit first-node horizon map,
and its single root sink in the Reference Richards trial. The forcing owner
supplies potential transpiration, root length density and rooted node count.
The existing accepted water transaction owns the final sink and mass receipt.

Read-only authorities: literal B1.11 `RWU_micro.f90`, `MOD_MvG_functions.f90`
and dispatcher `rootextraction.f90`, with the disclosed MICRO01 dry table
correction. Jarvis/Walsum MACRO, Feddes, Bartholomeus, existing ROOT-HYD01,
Richards solver, water transaction, restart schema and other workstream
interfaces remain separate authorities. The MICRO path applies no external
Jarvis or Walsum compensation.

Changed interfaces: optional MICRO parameter and horizon-map carriers on the
physical parameter type, and rooted count and density on the forcing type.
No committed-state, transaction or restart payload changes are proposed.
The default route remains unchanged and incompatible modes fail closed.

Qualification surface: MICRO02 standalone and literal nonlinear oracle,
MICRO04 first-node map, MICRO05 literal MvG and heterogeneous runtime,
MICRO06 actual committed two-interval restart and changed forcing, hard mass,
rejection and ROOT-HYD01 preservation. The O0/O2 stack gate passed on PR
#1076's merge postimage in run 37428720498. Its exact artifact and digest
are in `integration/audits/PPA_MICRO06_STACK_QUALIFICATION.json`. A separate
run on the canonical-target PR merge postimage must pass before admission.
Documentation source and strict build, shared runtime review and relevant
moving preservation must also pass or be explicitly reconciled.

Cross-workstream consequences: other active changes to the serialized
backend or application bootstrap intersect the same source surface and
must be requalified against the eventual canonical merge tree. The next
MICRO work for crop ET generation, oxygen/salt/frost stress, de Jong van Lier
and signed hydraulic lift is not included in this admission candidate.

Canonical admission owner: central F-CI canonical integration. Draft PR
#1077 is a review surface, not the admission record. Keep `canonical_admitted`
false until the actual merged tree and its controlling evidence are checked.
