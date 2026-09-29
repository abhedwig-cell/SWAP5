# F-PE-NLGLOB14M result — first saturated-block retreat event localization

Date: 2026-09-29

Status:

`NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`

Canonical base:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Qualification authority:

- workflow run: `36569151757`;
- job: `109408478863`;
- conclusion: SUCCESS.

## Coverage

PASS.

All 8 frozen O05/TG extended-dry fixtures provide a valid first-retreat bracket:

- last accepted 14-node saturated state;
- first subsequent 13-node state;
- node 3 saturated at the lower bracket endpoint;
- node 3 unsaturated at the upper bracket endpoint;
- nodes 4:16 remain saturated across the bracket;
- state and mass remain valid.

All eight event estimates lie inside their brackets.

## Event-time estimates

HEAD family, from coarsest to finest dt:

- 0.0219739518 d;
- 0.0220907744 d;
- 0.0218522826 d;
- 0.0217307446 d.

RUNOFF family:

- 0.0262678681 d;
- 0.0263339185 d;
- 0.0261844339 d;
- 0.0261086933 d.

The frozen convergence gate compares the two finest estimates against:

`2 * dt_finest = 6.25e-5 d`.

Observed refined differences:

- HEAD: about `1.21538e-4 d`;
- RUNOFF: about `7.57406e-5 d`.

Both exceed the frozen gate.

## Frozen classification

`NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`.

The physical event is consistently bracketed but its linear accepted-state interpolation is not yet temporally converged under the existing four-level ladder.

## Scientific interpretation

The failure is not an event-existence problem.

The first retreat event is present and physically consistent in every fixture.

The remaining uncertainty is event-time resolution.

The nonmonotone coarse estimates also show that a single accepted-state linear interpolation should not yet be treated as a qualified event locator.

## Consequence

Do not relax the convergence threshold.

Open a separately preregistered refinement successor using finer dt levels and the same node-3 constitutive event definition.

No release switch is authorized by NLGLOB14M.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No release rule or numerical default changed.

`LEGACY_NUMERICS` remains production default.
