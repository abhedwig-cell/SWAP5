# F-PE-TEMPORAL06 closeout — production-shaped c=0.65 coupling qualification

Date: 2026-09-26

Status: `CLOSED_TANGENT_PUBLICATION_UNQUALIFIED_NO_PRODUCTION_ADMISSION`

PR: #650

Parent: F-PE-TEMPORAL05 / PR #649

Frozen policy under test:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

## Scope result

TEMPORAL06 tested the frozen blind-validated c=0.65 temporal policy under repeated same-origin corrector sequences with production tangent-cache controls.

The workunit remains research/qualification-only. No production temporal-policy source change was made.

## P0 repeated-sequence result

Across 12 difficult dynamic origin/history groups and 64 same-origin requests per group:

### CURRENT_FIXED

- completed 256/768;
- failed 512/768;
- retries 6144;
- temporal rejections 6656;
- solver rejections 0.

### c=0.50

- completed 768/768;
- failures 0;
- retries 768;
- temporal rejections 768;
- solver rejections 0;
- tangent cache fresh/reuse 96/672.

### c=0.65

- completed 768/768;
- failures 0;
- retries 384;
- temporal rejections 384;
- solver rejections 0;
- tangent cache fresh/reuse 96/672.

Median repeated-sequence runtime ratio c=0.65 / c=0.50:

`0.73525`

Thus c=0.65 halved the retry burden and reduced median trial runtime by about 26.5% in the production-shaped sequence matrix.

## Preregistered overlap failure

The original P0 overlap gate was:

- relative q difference <= 1%;
- relative tangent difference <= 1%.

Ten of twelve origin/history groups passed.

O14 mid with history -0.10 and +0.10 failed only the tangent gate:

- q difference about 0.030% at the aggregate sequence level;
- tangent difference about 5.86%.

This negative result is preserved and asserted explicitly in CI. It is not hidden or reclassified as a pass.

## Independent tangent authority

A preregistered fresh-only discriminator then tested O14 mid at both history signs and four unique corrector offsets.

Independent authority:

- same captured dynamic origin;
- fixed-substep Reference backend;
- BALTOL02 effective balance floor;
- central finite difference of MODFLOW-facing q(h);
- epsilon ladder 1e-4, 2.5e-4, 5e-4 and 1e-3 cm;
- N=32 and N=64;
- primary authority fixed at N=64, epsilon=2.5e-4 cm.

All 8 points passed the authority stability gates.

Independent derivative:

approximately `-1.53365e-5 ... -1.53376e-5 1/s`.

Published fresh accepted-trajectory tangents:

- c=0.50: approximately `-1.42866e-5 ... -1.42871e-5 1/s`;
- c=0.65: approximately `-1.34489e-5 ... -1.34491e-5 1/s`.

Relative errors:

- c=0.50: about 6.85%;
- c=0.65: about 12.31%.

All 8 points therefore classify as:

`NEITHER_AUTHORITY_CONSISTENT`

under the preregistered 2% tangent-authority bound.

c=0.50 is closer at every tested point but does not meet the authority bound and does not satisfy the preregistered "clearly closer" error-ratio rule.

## Localization

At every discriminator point:

- c=0.50 uses one temporal retry and two accepted substeps;
- c=0.65 uses zero retries and one accepted substep.

The accepted-trajectory tangent therefore changes materially with temporal subdivision.

The resulting q response remains much less sensitive than the tangent itself.

This means the current tangent publication is not yet a qualified path-independent MODFLOW-facing q(h) derivative for this difficult dynamic origin.

## Cache interpretation

No production cache defect was identified.

The independent discriminator disabled the cache and still found the tangent-authority error.

Therefore the primary blocker is fresh tangent publication / accepted-trajectory directional semantics, not cache age, refresh head or reuse provenance.

A cache follow-up is not useful until the fresh tangent is independently qualified.

## Scientific interpretation

TEMPORAL05 evidence for c=0.65 remains valid within its stated scope:

- state;
- q / terminal flux;
- integrated exchange;
- mass;
- blind physical bounds.

TEMPORAL06 does not show that c=0.65 is physically wrong.

It shows that production coupling cannot admit the policy while the published linear-response tangent is not independently qualified.

## Decision

TEMPORAL06 closes without production admission.

No change is authorized to:

- c=0.65;
- TEMPORAL04/05 physical bounds;
- BALTOL02;
- Richards equations;
- retry scaling;
- tangent-cache production defaults;
- MODFLOW coupling semantics.

The direct next technical work belongs in a separate tangent-repair / tangent-authority workunit.

That workunit should determine why accepted-step directional composition underestimates the fixed-origin finite-difference q(h) derivative, and should repair or redefine tangent publication before temporal-policy admission resumes.

## CI closeout semantics

The historical P0 overlap gate is an expected negative qualification and is asserted as such.

The independent tangent-authority discriminator must pass as a reproducible measurement harness.

Review readiness therefore means:

- the preregistered P0 negative result reproduces exactly;
- the tangent-authority discriminator executes successfully;
- no unrelated current-lineage CI regression is introduced.

No green status is obtained by weakening the original P0 gate.
