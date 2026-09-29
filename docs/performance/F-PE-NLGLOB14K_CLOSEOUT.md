# F-PE-NLGLOB14K closeout — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Final status:

`NLGLOB14K_UPPER_TG_NOT_UNIFORMLY_ADMISSIBLE`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

Qualification authority:

- run `36567898133`;
- job `109404281431`;
- conclusion: SUCCESS.

## Closure

NLGLOB14K closes the first mixed-profile mode-ownership attribution negatively for immediate TG ownership.

All eight fixtures show a perfectly clean constitutive split between:

- an unsaturated upper region with finite positive capacity;
- a saturated lower block on the existing saturated capacity floor.

However the original current-step TG moisture predictor is not admissible in every upper-region mixed state.

The admissible fraction improves monotonically with timestep refinement, reaching about 95 to 96% at the finest tested dt, but never 100%.

## Scientific conclusion

The blocker is temporal resolution of the upper-region predictor, not constitutive ambiguity of the mixed profile.

Persistent whole-column saturated-KLAG remains the only qualified temporal owner for the current mixed-profile bank.

A spatially split method remains scientifically plausible but requires separate temporal-resolution evidence before implementation.

## Direct successor

Open:

`F-PE-NLGLOB14L — mixed-profile upper-region temporal-resolution attribution`.

The successor must remain observational.

At every NLGLOB14K mixed state, evaluate one additional fixed diagnostic predictor over exactly half the nominal interval for upper unsaturated nodes only:

`theta_half = theta + 0.5*dt*theta_dot`.

Do not accept or commit this state.

Record whether both:

- full-step predictor is admissible;
- half-step predictor is admissible.

Frozen question:

does one fixed half-step make upper-region predictor admissibility 1.0 across all mixed states and all 8 fixtures?

Do not test other fractions or adaptive subdivision in NLGLOB14L.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14K

BASELINE: `e803842a434d792ba5209f71e3681bd78be90560`

CANONICAL RECONCILED THROUGH: `667c4b76768f760403e0b58383c386686baa3784`

BRANCH: `research/f-pe-nlglob14k-mixed-profile-mode-ownership`

STATUS: closed negative attribution

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14K_UPPER_TG_NOT_UNIFORMLY_ADMISSIBLE`

NEXT SAFE STEP: preregister NLGLOB14L half-step upper-region predictor attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
