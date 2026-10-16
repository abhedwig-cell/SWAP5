# F-PE-NLGLOB14K result — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Status:

`NLGLOB14K_MIXED_MODE_OWNERSHIP_SIGNAL`

Canonical base:

`integration/f-ci-canonical@e803842a434d792ba5209f71e3681bd78be90560`

Canonical authority rechecked before result persistence through:

`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

The intervening canonical delta does not alter the frozen NLGLOB14K fixtures, complete dynamic-top research policy, accepted-state logger, constitutive provider, saturation indicators or physical mass contract.

Qualification authority:

- workflow run: `36567749566`;
- job: `109403793045`;
- conclusion: SUCCESS.

## Coverage

PASS.

All 8 O05/TG forcing-reversal fixtures:

- enter persistent saturated mode exactly once;
- contain mixed-profile dry states;
- complete the full 0.012 d horizon;
- remain finite and mass-clean;
- retain a contiguous lower saturated block.

## Upper-region TG admissibility

The unsaturated upper region is often, but not persistently, compatible with the ordinary current-step TG moisture predictor.

Observed admissible fractions by dt:

### HEAD fixtures

- dt 2.5e-4 d: about 0.581;
- dt 1.25e-4 d: about 0.779;
- dt 6.25e-5 d: about 0.902;
- dt 3.125e-5 d: about 0.951.

### RUNOFF fixtures

- dt 2.5e-4 d: about 0.649;
- dt 1.25e-4 d: about 0.797;
- dt 6.25e-5 d: about 0.905;
- dt 3.125e-5 d: about 0.960.

In every fixture:

- upper-region TG admissibility is reached at least once;
- admissibility later becomes false again;
- therefore the preregistered persistence gate fails.

The minimum normalized predictor distance to the retention bound is negative but shrinks strongly with dt, approximately linearly.

Final mixed state in all fixtures:

- shallowest saturated node = 3;
- upper unsaturated nodes = 2.

## Frozen classification

No fixture qualifies `UPPER_TG_REGION_ADMISSIBLE`.

No fixture qualifies `UPPER_TG_REGION_NOT_ADMISSIBLE`.

All 8 classify `UPPER_TG_ADMISSIBILITY_MIXED`.

Aggregate classification:

`NLGLOB14K_MIXED_MODE_OWNERSHIP_SIGNAL`.

## Scientific interpretation

Full-column persistent KLAG is broader than the local TG-domain requirement for much of the dry mixed-profile phase, especially at refined dt.

However, the moving saturation boundary repeatedly makes the upper-region TG predictor temporarily inadmissible.

This is therefore not a clean fixed-domain split where the upper region can simply return to TG permanently.

The dt dependence is consistent with a moving temporal event boundary: the upper-region predictor overshoot becomes smaller and rarer as dt is refined.

A hybrid upper-TG/lower-KLAG solver would require explicit moving-interface event semantics and is not justified by NLGLOB14K alone.

## Consequence

Do not introduce a spatially split temporal solver from this result.

Because NLGLOB14J established that the expanding lower saturated block is physically mass-consistent, a longer fixed dry horizon is now justified to test whether the lower block eventually stops expanding and retreats/desaturates.

Open:

`F-PE-NLGLOB14L — extended dry-horizon saturated-block evolution attribution`.

The successor must use a single preregistered longer horizon and unchanged dry forcing. It must remain observational and must not implement release.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No release rule or numerical default changed.

`LEGACY_NUMERICS` remains production default.
