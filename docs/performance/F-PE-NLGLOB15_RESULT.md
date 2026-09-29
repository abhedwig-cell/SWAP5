# F-PE-NLGLOB15 result — physical desaturation/release semantics

Date: 2026-09-29

Status:

`BLOCKED_NLGLOB15_RELEASE_COVERAGE`

Canonical authority rechecked before result persistence through:

`integration/f-ci-canonical@e46985908b19f83cf2f17f86507aa3495df971a2`

Qualification authority:

- workflow run: `36564258322`;
- job: `109392235771`;
- conclusion: SUCCESS.

## Frozen question

Can persistent saturated mode expose a threshold-free representational desaturation signal under the preregistered zero-supply drying phase?

The candidate release quantity was:

`Delta_theta = theta_s - theta_event`

with representation scale:

`U_theta = ulp(theta_s)+ulp(theta_event)`.

No mode switch was performed.

## Execution result

All five frozen saturation-entry trajectories:

- enter persistent saturated mode;
- produce multiple accepted drying-phase saturated-mode records;
- remain finite and mass-clean in the observed records;
- then terminate before the extended horizon as:

`ENDPOINT_PROVIDER_ROUTE_MISMATCH`.

Counts:

- process failures: `0`;
- complete extended trajectories: `0 / 5`;
- route-transition terminal outcomes: `5 / 5`;
- observed RLS0 release-eligible states before termination: `0 / 5`.

## Why the raw classifier is not accepted

The initial analysis script returned:

`NLGLOB15_NO_RELEASE_SIGNAL`.

That interpretation is not scientifically valid.

The drying forcing changes the physical dynamic-top regime. The inherited same-route TIMEINT17 test driver treats a provider route transition as terminal, so all five trajectories stop before the release question is fully observed.

Absence of an RLS0 signal before that artificial same-route stop does not establish absence of physical desaturation.

The preregistered workunit requires a drying/release probe that can be executed faithfully.

Therefore the correct bounded classification is:

`BLOCKED_NLGLOB15_RELEASE_COVERAGE`.

## Interpretation

The first new fact from the drying experiment is that surface-supply removal drives a dynamic-top route transition before the current same-route harness can complete the release trajectory.

Release/desaturation semantics therefore cannot be separated from dynamic-top route-transition semantics in this fixture.

This does not invalidate the representation-based release quantity.

It means the next diagnostic harness must permit provider-selected route changes while preserving the same physical state, forcing and mass contracts.

## Consequence

Open:

`F-PE-NLGLOB15A — route-flexible drying/release attribution`.

The successor must:

1. reuse the exact five NLGLOB15 initial configurations and zero-supply drying protocol;
2. preserve the dynamic-top provider unchanged;
3. permit provider-selected FLUX/HEAD/RUNOFF route transitions after saturation entry rather than terminating on mismatch with the initial fixture route;
4. remain observational: persistent saturated KLAG stays active and no release to TG occurs;
5. record route transitions explicitly;
6. evaluate the unchanged RLS0 representation criterion at every accepted drying interval;
7. preserve exact physical interval/cumulative mass accounting.

No release threshold or hysteresis is authorized.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
