# PPA-WU05-A26H result — RFM wall-hydraulic history ownership

Date: 2026-10-01
Status: QUALIFIED
Qualified postimage: a20618fbaaf9ec513a16641fe754c9a8d7da2a3b
Qualification run: 36893220094 — SUCCESS

Focused gate:

    PPA_WU05A26H_WALL_HISTORY=PASS

## Qualified contract

A22A endpoint wall sorptivity remains event history.

- An accepted wet endpoint retains its stored wall sorptivity exactly; current matrix hydraulics do not overwrite it.
- An accepted dry endpoint that receives new routed water is seeded from the accepted matrix hydraulic view at its explicit endpoint-node mapping, using the already-qualified node-sorptivity operator.
- A dry endpoint with no new input remains at zero wall sorptivity.
- Candidate seeding does not mutate the accepted RFM state.
- Re-evaluation from the same accepted origin is bit-identical.

A22B MB input has no persistent MB storage/history owner in the admitted state. MB wall conductivity and sorptivity are therefore derived trial-locally from the accepted mapped MB wall node. No MB default or calibration parameter is introduced.

## Negative evidence

Run 36882747639 failed before the oracle because the focused compile list omitted existing dependencies required by mod_rfm_physical_state. This was a harness defect.

Run 36887901762 was blocked in the runner package-install step and did not execute the oracle. The workflow was narrowed to use the compiler already present on the runner.

Neither event falsified the contract.

## Decision

    ENDPOINT_WALL_HISTORY_OWNERSHIP = QUALIFIED
    DRY_TO_WET_NODE_HYDRAULIC_SEED = QUALIFIED
    MB_TRIAL_LOCAL_NODE_HYDRAULICS = QUALIFIED
    ACCEPTED_STATE_IMMUTABILITY = QUALIFIED
    RETRY_REPLAY = QUALIFIED
    NEW_PHYSICS_PARAMETER = NONE
    A26_BLOCKER = RESOLVED
    NEXT = resume PPA-WU05-A26 backend dispatch
