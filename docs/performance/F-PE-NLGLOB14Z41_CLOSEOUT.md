# F-PE-NLGLOB14Z41 closeout — real reduced HeadCalc active-dimension/profile-size scaling

Date: 2026-09-30

Final status:

`QUALIFIED_Z41_HEADCALC_SCALING_TREND_ONLY`

Qualification authority:

- workflow run `36774027882`;
- job `110087301246`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z41 closes positively as a scaling-trend result.

All six physical cases pass exactly/effectively at machine precision.

The real reduced HeadCalc route becomes faster as:

- full profile size increases;
- active fraction decreases;
- reconstructed tail grows.

Observed timing ratios range from about 0.961 at N16_A13 to about 0.905 at N64_A48.

The frozen full gain class is not reached because no N=64 case crosses the strict <0.90 threshold.

## Strategic conclusion

The mechanism has now demonstrated:

- real reduced Heritage HeadCalc binding;
- exact physical equivalence in the frozen scaling matrix;
- favorable solve-service scaling;
- approximately 9.5% solve-service gain in the strongest N=64 case.

Another isolated scaling point would add little.

The remaining performance question is trajectory-level orchestration: whether the per-solve gain survives when active dimension changes over time and manager/fallback logic executes in a representative larger-profile trajectory.

## Direct successor

Open:

`F-PE-NLGLOB14Z42 — larger-profile production-shaped trajectory timing`.

Use one representative larger profile and one adaptive trajectory, not a broad campaign.

Required outputs:

- full/adaptive physical trajectory differences;
- mass/rollback hard gates;
- active-dimension occupancy;
- fallback incidence and reasons;
- solve-service timing;
- trajectory wall-clock timing;
- cumulative work/timing ratio.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z41

BRANCH: `research/f-pe-nlglob14z41-headcalc-scaling`

RESULT POSTIMAGE BEFORE CLOSEOUT: `bd57c791389fa8e3ead1cc9e091aac430f14abf8`

QUALIFICATION STATUS: `QUALIFIED_Z41_HEADCALC_SCALING_TREND_ONLY`

NEXT SAFE STEP: Z42 larger-profile trajectory benchmark.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
