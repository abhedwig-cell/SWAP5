# F-PE-NLGLOB14K result — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Status:

`NLGLOB14K_UPPER_TG_NOT_UNIFORMLY_ADMISSIBLE`

Canonical base at preregistration:

`integration/f-ci-canonical@e803842a434d792ba5209f71e3681bd78be90560`

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

The intervening canonical delta admits NLGLOB14J and related research authority and does not alter the frozen NLGLOB14K fixtures, constitutive provider, mixed-state definition, physical mass contract or diagnostic equations.

Qualification authority:

- workflow run: `36567898133`;
- job: `109404281431`;
- conclusion: SUCCESS.

## Coverage

PASS.

All 8 frozen O05/TG forcing-reversal fixtures:

- contain mixed dry-phase states;
- complete the requested horizon;
- remain mass-clean;
- remain finite;
- preserve the clean contiguous lower saturated block.

Process failures:

`0`.

## Constitutive split

The constitutive split is clean in every mixed state of every fixture.

Observed:

- minimum clean-split fraction: `1.0`;
- all upper unsaturated nodes have finite positive constitutive capacity;
- all lower saturated nodes sit on the existing saturated branch with the expected provider capacity floor;
- accepted head/moisture states remain constitutively consistent.

Thus the mixed profile has a numerically coherent unsaturated-upper / saturated-lower partition.

## Upper-region TG predictor admissibility

The original current-step TG moisture predictor is not uniformly admissible in the upper unsaturated region.

Observed admissible fractions by dt:

HEAD:
- 0.00025 d: about `0.5814`;
- 0.000125 d: about `0.7791`;
- 0.0000625 d: about `0.9017`;
- 0.00003125 d: about `0.9510`.

RUNOFF:
- 0.00025 d: about `0.6486`;
- 0.000125 d: about `0.7973`;
- 0.0000625 d: about `0.9054`;
- 0.00003125 d: about `0.9596`.

No fixture reaches 1.0.

Frozen classification:

`NLGLOB14K_UPPER_TG_NOT_UNIFORMLY_ADMISSIBLE`.

## Scientific interpretation

The mixed profile does not fail because the constitutive state cannot be partitioned.

The failure is temporal.

As dt decreases, upper-region TG predictor admissibility improves monotonically and approaches one, which is consistent with a temporal-resolution limitation of the explicit current-step predictor.

Therefore the current evidence does not support an immediate whole-column return to TG at mixed-profile onset.

It also does not rule out a spatially split method at sufficiently resolved upper-region time integration.

## Consequence

Do not implement a hybrid solver yet.

Open a bounded observational successor that tests whether one fixed half-step diagnostic in the upper unsaturated region removes the remaining predictor-domain failures at mixed states.

That successor must remain diagnostic only and must not change the accepted-state method, saturated lower-block evolution, mass contract or physical forcing.

No adaptive subcycling rule is authorized by NLGLOB14K.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No temporal-mode ownership policy changed.

`LEGACY_NUMERICS` remains production default.
