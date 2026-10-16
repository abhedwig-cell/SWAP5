# C3A shared crop/runtime integration decision

Date: 2026-10-02
Status: ACCEPTED IMPLEMENTATION CONTRACT, qualification and admission pending.
User continuation explicitly authorizes the central shared-integration role requested
after the source-input audit. This contract records that role and its bounded scope;
it does not assert physics qualification or canonical admission.

WORKSTREAM: PPA-WU05-C3A with central SWAP5 runtime/crop integration.
EXACT BASELINE: canonical 27b271c2f3d1ea54e0110f56b73400e3b6935e11;
candidate 9bbcb7760d7ce802396b1deccd4b33495e0c8162.

## Execution and ownership decision

The existing crop/root process prepares the base extraction sink. Publish a separate
read-only crop oxygen view containing the current nodal root-density kg/m3 and SRL
kg/m conversion parameter; never substitute normalized uptake fractions. The typed
application binds this view and atmospheric temperature as interval forcing.

The actual Reference backend evaluates oxygen from each trial's starting hydraulic
and existing thermal state, before binding the one existing root-sink provider.
This follows the source ordering of uptake before water and thermal advancement.
Reset the worker sink from the original base forcing on EVERY call, including
full/half siblings and retries. Never multiply an already reduced sink again.
No independent oxygen mass booking or accepted oxygen continuation state is allowed.

This narrows the prior proposed contract: optional typed parameter/forcing carriers
and the real backend call site may change. Their root-sink meaning and ledger are
held fixed. A backend forcing-schema change was not intrinsically required by the
physics; optional input carriers are selected here to reach the actual application
without a second solver or an externally precomputed static oxygen factor.

## Merge contract

- OWNED SURFACE: oxygen physics/parameters, separate crop oxygen publication,
  typed backend input binding and standalone production application reachability.
- READ-ONLY AUTHORITIES: exact corrected B1.11; C3Q/C3P; current soil hydraulic,
  thermal, drought/root, transaction, restart and mass contracts.
- INTERFACES ALLOWED TO CHANGE: optional oxygen parameter/forcing carriers and
  diagnostics in serialized Reference backend; bounded standalone application
  admission selection; additive crop oxygen publication and construction APIs.
- INTERFACES HELD FIXED: drought-only crop contract and root process; hydraulic
  and thermal owners; solver ABI; transaction core; restart schema; all water ledgers.
- DEPENDENCY SURFACE: existing root extraction input; matching trial-start
  hydraulic/thermal views; atmospheric forcing; complete immutable soil/crop
  construction, including hysteresis where applicable.
- REQUIRED QUALIFICATION: source-bound assembled response within legacy SOLVE
  accuracy 1e-4; actual application execution; OFF exact preservation; unsupported
  configurations fail closed; all boundary cases from C3A; no repeated reduction;
  reject/replay/restart; single sink and hard unrounded water-balance closure;
  affected current canonical regressions; persisted exact-postimage evidence.
- CROSS-WORKSTREAM CONSEQUENCES: no groundwater analytic tangent or parallel
  worker envelope extension. Active oxygen is limited to homogeneous typed
  standalone Reference admission; other application compositions reject it.
- CANONICAL ADMISSION OWNER: central SWAP5 regie, carried in this task's explicit
  shared-integration mandate.

## Physical and numerical policy

Only mode 2/type 1/analytical MvG with REFERENCE waterfilm activates physics.
OFF preserves the incoming sink exactly. Tabular, WFT300/PRACTICAL and all other
oxygen modes/types reject. The existing backend already rejects hysteresis and
tabular hydraulics; do not widen that envelope. Construction must still identify
the full dependency set and distinguish layer thickness from cumulative depth.

Affected invariants: 3,4,5,7,13,21,22,23,25,27,29,30. Expected effect: compliant
when qualified. Main risks: input units, producer completeness, trial staging,
repeated sink reduction and accidental reachability in nonqualified envelopes.

No new scientific parameter value, formulation, tolerance, timestep policy,
mass-accounting allowance or generic legacy-parser admission is authorized.
