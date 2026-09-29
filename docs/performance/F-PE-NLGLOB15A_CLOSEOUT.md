# F-PE-NLGLOB15A closeout — route-flexible drying/release attribution

Date: 2026-09-29

Final status:

`NLGLOB15A_NO_RELEASE_SIGNAL`

Canonical authority rechecked before closeout through:

`integration/f-ci-canonical@9ca61a27aa979d5e87ffeffbd3e74fd0f1c5e406`

The intervening canonical delta since the r2 preregistration does not alter the NLGLOB15A release quantity, route-flex testdriver seam, dynamic-top provider, persistent saturated-KLAG mode, physical mass accounting or five frozen fixtures.

Qualification authority:

- workflow run `36565911619`;
- job `109397633328`;
- conclusion: SUCCESS.

## Closure

NLGLOB15A removes the route-coverage blocker from NLGLOB15.

All five preregistered drying trajectories:

- enter persistent saturated KLAG mode;
- complete the full 0.004 d horizon;
- remain finite and mass-clean;
- follow provider-selected route changes without testdriver termination;
- contain valid route diagnostics.

All five undergo at least one provider route change after saturated-mode entry.

No trajectory becomes RLS0 release-eligible.

Observed:

- positive release cases: `0/5`;
- ever release-eligible: `0/5`;
- persistent release cases: `0/5`;
- process failures: `0`.

Frozen classification:

`NLGLOB15A_NO_RELEASE_SIGNAL`.

## Scientific conclusion

The absence of a release signal is not a same-route harness artifact.

Under the frozen zero-supply drying protocol, allowing physically selected FLUX/HEAD/RUNOFF transitions does not make the original event-node representation criterion positive.

This result is consistent with NLGLOB14H and NLGLOB14I:

- the surface dries and route control returns to flux;
- total profile storage decreases;
- the original bottom event node remains saturated;
- the lower saturated block expands upward rather than retreating.

Release semantics therefore require full-profile redistribution attribution before a state-machine switch can be defined.

## Next safe step

Continue with the NLGLOB14I successor:

`F-PE-NLGLOB14J — dry-phase saturated-block redistribution attribution`.

The successor must remain observational and determine whether the expanding saturated lower block is supported by physically consistent compartment storage/flux redistribution under persistent saturated KLAG, or is specific to the persistent temporal-mode formulation.

No release threshold or switch is authorized.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB15A

BASELINE: `c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

BRANCH: `research/f-pe-nlglob15a-route-flex-release-r2`

STATUS: closed negative attribution

TEST STATUS: focused route-flex drying run PASS

QUALIFICATION STATUS: `NLGLOB15A_NO_RELEASE_SIGNAL`

NEXT SAFE STEP: NLGLOB14J redistribution attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
