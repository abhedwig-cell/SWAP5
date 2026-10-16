# F-PE-BASE01 — base q/state Richards solve decomposition

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent authority:
`integration/f-ci-canonical@c79ea4d7efb580eeb55b61a4e93b4bc6f01bfc96`

Immediate parent workunit:
`F-PE-LIVE01 / PR #656`

Branch:
`work/f-pe-base01-qstate-richards-decomposition`

## Trigger

LIVE01 closed with the base q/state Reference Richards solve selected as the primary
remaining SWAP-side performance target for unavoidable live corrector trials.

Current live evidence on the production-admitted c=0.65 groundwater path:

- 32 exact SWAP trials over the frozen 12-group difficult live matrix;
- 72 transaction attempts;
- 20 temporal retries;
- zero solver rejections;
- zero internal retries;
- 236 nonlinear iterations;
- 236 Jacobian builds;
- 380 linear solves;
- 236 backtracking attempts.

LIVE01 P1 measured accepted-direction / tangent work at an aggregate marginal
fraction of about 19.3%, below the frozen 20% primary-successor gate.

LIVE01 P2 showed that a research-only wider temporal floor does not remove the
20 live temporal retries and yields no runtime benefit.

Therefore the next primary question is the cost structure of the base q/state solve
itself.

## Supporting historical evidence

The older SOLVE01-based PROFILE07 P1 decomposition found, within exact participant
trial time:

- forcing materialization: about 1.43%;
- serialized backend: about 82.58%;
- participant postprocessing: about 15.20%.

That result is useful for instrumentation design but is not current authority,
because it predates the final TEMPORAL08 production postimage and has a different
retry pattern.

BASE01 must remeasure on current canonical authority.

## Primary question

Within the base q/state Reference Richards work executed by the frozen live difficult
population, which exact numerical component dominates wall-clock cost and admits a
credible exact-preserving reduction?

## Scope

BASE01 is observation-only.

No production `src/**` change is allowed.

Allowed:
- generated research copies;
- timing instrumentation;
- test harnesses;
- workflow files;
- documentation.

Any production optimization requires a separate preregistered successor.

## Frozen authority

Use the same 12 material/regime/history groups as LIVE01.

Required production semantics:

- TEMPORAL08 c=0.65 history-aware policy;
- floor = 1e-5 cm;
- BALTOL02;
- exact Reference Richards solve;
- current mode-5 fixed-interface groundwater participant;
- no tangent approximation;
- no discarded-trial solve approximation;
- MODFLOW6 6.8.0 live-head population where needed.

For base-solve timing, accepted-direction work may be disabled only in paired
research copies, identically across compared decomposition arms.

## P0 — participant/backend boundary confirmation

Reconfirm on current canonical authority that the serialized backend remains the
dominant component of exact trial cost.

Measure at minimum:

- forcing materialization;
- serialized backend call;
- participant postprocessing/response construction;
- total exact trial wall-clock.

Advancement to backend-internal decomposition requires:

- serialized backend share >= 60% aggregate exact-trial wall-clock.

If that gate fails, BASE01 must close or redirect before deeper solver instrumentation.

## P1 — backend internal decomposition

Within the base q/state backend path, measure wall-clock attributable to at least:

1. transaction/substep control;
2. nonlinear iteration control;
3. constitutive property evaluation;
4. residual assembly;
5. Jacobian assembly/update;
6. tridiagonal factorization/solve;
7. backtracking candidate evaluation;
8. accepted-state/candidate materialization;
9. remaining backend overhead.

Instrumentation must also preserve and report:

- attempts;
- accepted substeps;
- temporal rejections;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- HEADCALC calls;
- backtracking attempts;
- q/state checksum or exact physical identity against the uninstrumented path.

## P2 — target discrimination

For the dominant measured component, determine whether the work is:

- mathematically required and already near-minimal;
- redundant/repeated and removable exactly;
- representationally expensive but replaceable by a previously qualified exact or
  bounded-equivalent mechanism;
- algorithmically reducible without changing accepted state or failure timing.

Do not select a successor merely because a microkernel is expensive.

The target must satisfy both:

1. material contribution:
   - >=20% of base q/state solve time in aggregate, or
   - >=15% broadly across the difficult live groups;
2. a concrete exact-preserving mechanism exists.

If no component satisfies both, close:
`CLOSED_NO_EXACT_BASE_SOLVE_TARGET`.

## Explicit exclusions

BASE01 does not:

- change c=0.65;
- change the 1e-5 cm floor;
- retune temporal acceptance;
- change BALTOL02;
- change nonlinear tolerances;
- change retry scale;
- alter timestep/substep policy;
- change tangent mathematics;
- change MODFLOW equations or solver settings;
- reopen the rejected response surrogate;
- admit AHL/direct-retention or another approximation by inference from old timing.

## Relationship to existing lines

AHL remains a secondary representation track. Historical direct-retention evidence
may be used to formulate a later candidate only if current BASE01 attribution shows
constitutive evaluation is a material part of the base q/state live solve.

Accepted-direction optimization remains deferred, not rejected, after LIVE01 P1.

SOLVE01 discarded-trial elimination remains a conditional mechanism for future
reuse-rich workloads, but it is not the current live primary target.

## Closeout requirement

BASE01 must close with exactly one of:

- one measured exact-preserving successor target;
- `CLOSED_NO_EXACT_BASE_SOLVE_TARGET`;
- a real blocker that prevents trustworthy attribution.

Negative measurements are retained.

