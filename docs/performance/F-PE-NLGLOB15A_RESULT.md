# F-PE-NLGLOB15A result — route-flexible drying/release attribution

Date: 2026-09-29

Status:

`NLGLOB15A_NO_RELEASE_SIGNAL`

Canonical base:

`integration/f-ci-canonical@c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

Qualification authority:

- workflow run: `36565911619`;
- job: `109397633328`;
- conclusion: SUCCESS.

## Frozen question

Does the unchanged representational release criterion RLS0 become observable under the frozen zero-supply drying protocol once provider-selected dynamic-top route changes are allowed after saturated-mode entry?

No temporal-mode release to TG was performed.

## Coverage

PASS.

All five preregistered trajectories:

- enter persistent saturated KLAG mode;
- execute through the full 0.004 d horizon;
- remain finite;
- remain mass-clean;
- retain valid provider-selected route codes;
- exhibit at least one provider route transition.

Observed route changes:

- cases with route changes: 5/5;
- total route-change records: 5.

Process failures:

`0`.

## Release signal

RLS0 release-eligible trajectories:

`0 / 5`.

Persistent release trajectories:

`0 / 5`.

Therefore the frozen classification is:

`NLGLOB15A_NO_RELEASE_SIGNAL`.

## Physical admissibility

All trajectories remain mass-clean under the unchanged physical accounting.

No RLS0-positive unsafe state occurs.

The negative result is therefore not caused by route coverage, nonfinite state or water-balance failure.

## Interpretation

The earlier NLGLOB15 coverage blocker is removed.

Allowing the dynamic-top provider to change route faithfully does not expose representable desaturation at the event node over the frozen 0.004 d zero-supply drying horizon.

The release problem is therefore no longer a same-route test-driver artifact.

The next bounded question is whether the accepted saturated-mode event-node state is moving toward desaturation at representable precision or remains pinned to the saturated constitutive manifold.

## Consequence

Proceed to the already preregistered dry-phase saturation-manifold drift attribution.

Do not introduce:

- a release threshold;
- ULP multiplier;
- hysteresis band;
- fixed head threshold;
- route-based release;
- longer horizon before drift direction is established.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
