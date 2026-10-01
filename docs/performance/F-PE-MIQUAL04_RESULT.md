# F-PE-MIQUAL04 result — dynamic-top runoff/ponding qualification

Date: 2026-10-01

Status:

`MIQUAL04_REFERENCE_COVERAGE_INSUFFICIENT`

Qualification execution:

- workflow run: `36821927626`;
- job: `110239161370`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked after execution:

`integration/f-ci-canonical@9bad713b0d2ab24d40fcf937d11c850d3fb52a22`

The canonical delta since MIQUAL04 start is confined to macropore/FMR integration surfaces and does not modify the moving-interface manager, timestep numerical profile, Richards reference binding or B110 dynamic-top provider used by MIQUAL04.

## Frozen-bank outcome

Reference-valid: 8/20.

By precipitation class:

- DRY: 5/5;
- MODERATE: 3/5;
- WET: 0/5;
- PONDING: 0/5.

The preregistered coverage gate required at least 15/20 and at least three reference-valid cases in every precipitation class.

Therefore the frozen classification is:

`MIQUAL04_REFERENCE_COVERAGE_INSUFFICIENT`.

No threshold or horizon is changed in MIQUAL04 after exposure.

## Dynamic-top observations before reference failure

The full-reference runs do exercise the intended dynamic-top physics before failure in several WET/PONDING cases.

Examples:

- B12_N64_T49 / WET reaches ponded-head and linear-runoff routes and accumulates about 1.08 cm runoff before reference solve failure at interval 270;
- B12_N64_T49 / PONDING accumulates about 4.88 cm runoff before failure at interval 236;
- B12_N32_T25 / WET reaches linear runoff before failure at interval 82;
- B12_N32_T25 / PONDING reaches linear runoff before failure at interval 134;
- O05 PONDING cases also reach ponded-head and linear-runoff routes before later reference failure.

Mass ledgers remain around 1e-13 cm or smaller in these pre-failure trajectories.

These observations establish that the provider/harness reaches the target physics. They do not qualify a completed dynamic-top manager trajectory.

## Manager evidence boundary

Adaptive execution did not begin because the frozen reference-coverage gate failed.

MIQUAL04 therefore makes no positive or negative claim about manager behavior under dynamic-top ponding/runoff.

The result is a reference-domain blocker, not a moving-interface-manager falsification.

## Consequence

Open a separately preregistered bounded event-window successor.

The successor may use a shorter horizon selected solely from the already exposed full-reference failure times, provided:

- numerical settings remain unchanged;
- precipitation levels remain unchanged;
- the window is fixed before any adaptive result exposure;
- the window is long enough to exercise ponded-head and linear-runoff routes.

The earliest WET reference failure occurs after 81 accepted intervals. A 64-interval window is therefore an admissible pre-failure qualification window.

## Production boundary

No production change.

Moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
