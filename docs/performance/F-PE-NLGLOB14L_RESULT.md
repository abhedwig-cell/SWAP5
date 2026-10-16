# F-PE-NLGLOB14L result — extended dry-horizon saturated-block evolution attribution

Date: 2026-09-29

Status:

`NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION`

Canonical base:

`integration/f-ci-canonical@67e6abbacf53aada2f2613644446eea826602806`

Qualification authority:

- workflow run: `36568451822`;
- job: `109406140099`;
- conclusion: SUCCESS.

## Frozen question

Under the unchanged dry forcing extended to the preregistered fixed horizon of 0.05 d, does the lower saturated block eventually retreat or fully desaturate?

No release switch or solver behavior was changed.

## Coverage

PASS.

All 8 frozen O05/TG fixtures:

- complete the full 0.05 d horizon;
- remain finite;
- retain consistent saturation indicators;
- preserve a contiguous lower saturated block whenever nonempty;
- remain mass-clean.

Process failures:

`0`.

## Saturated-block lifecycle

Every fixture follows the same qualitative lifecycle:

1. initial saturated-node count = 1;
2. saturated block expands to a maximum count of 14;
3. after a finite plateau, the block retreats;
4. final saturated-node count = 13;
5. complete desaturation is not reached within 0.05 d.

Thus all 8 fixtures classify:

`PARTIAL_RETREAT_AFTER_PEAK`.

No fixture classifies:

- `FULL_DESATURATION_AFTER_PEAK`;
- `NO_RETREAT_WITHIN_FIXED_HORIZON`;
- `NONCONTIGUOUS_OR_INCONSISTENT`.

## Retreat timing

HEAD entry fixtures:

- first retreat approximately 0.02175 to 0.022125 d.

RUNOFF entry fixtures:

- first retreat approximately 0.026125 to 0.0265 d.

The retreat timing is stable across dt refinement.

The peak saturated-node count is 14 in all fixtures and final count is 13 in all fixtures.

## Physical admissibility

Physical mass remains near roundoff:

- max accepted-interval ledger about `2.36e-14 cm`;
- max cumulative ledger about `2.71e-14 cm`.

All profiles continue net drying.

## Frozen aggregate classification

The preregistered aggregate positive retreat class required all 8 fixtures to show retreat and at least 4 to fully desaturate.

Observed full-desaturation fixtures:

`0 / 8`.

Therefore the frozen aggregate classification is:

`NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION`.

This classification is retained unchanged.

## Scientific interpretation

The persistent lower saturated block is not permanently pinned.

Under sustained dry forcing it first expands through internal redistribution, reaches a maximum extent, and then begins to retreat.

This supplies the first direct physical release-direction signal in the persistent saturated-mode line.

However, the lower block does not disappear within the fixed 0.05 d horizon, so disappearance of the saturated set cannot yet serve as a qualified release event.

The dt-consistent first-retreat time is now the correct bounded event to study.

## Consequence

A separately preregistered successor may localize the first saturated-block retreat event.

That successor should test whether the retreat event time converges with dt and whether the event can be defined from a state-local change in the moving saturated-block edge without an empirical pressure threshold.

No temporal-mode release switch is authorized by NLGLOB14L itself.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No release rule or numerical default changed.

`LEGACY_NUMERICS` remains production default.
