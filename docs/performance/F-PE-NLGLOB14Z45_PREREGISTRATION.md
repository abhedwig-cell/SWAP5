# F-PE-NLGLOB14Z45 preregistration — narrow admission scope and eligibility contract

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULT`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Baseline:

`research/f-pe-nlglob14z45-admission-scope-eligibility@e8bcf1a77f4c5180330ec320a9b88c8872f46459`

## Parent authority

- Z35: manager seam + physical binding, explicit fallback/bypass/no-leak qualified;
- Z42: O05 N=64 sequential trajectory physically exact with wall ratio ~0.927 and work ratio 0.765625;
- Z43: broad heterogeneous production-admission candidate not qualified because frozen O14 full-reference holdout fails before manager evaluation;
- Z44: no O14/B12 candidate in the frozen reference-only matrix is trajectory-valid; this is a reference-fixture limitation, not manager evidence.

## Purpose

Decide whether the accumulated evidence supports a deliberately **narrow, opt-in, fail-closed production-admission candidate scope** without pretending that unqualified heterogeneous trajectories are covered.

Z45 is governance/architecture only. No new trajectory result may be introduced.

## Frozen evidence rule

Use only already-qualified repository evidence.

No new timing, no new material tuning, no new tolerance tuning, no new synthetic trajectory search.

## Candidate eligibility contract

The moving-interface manager may be considered eligible only when all of the following hold:

1. explicit moving-interface configuration is enabled;
2. full accepted state remains sole committed authority;
3. full profile has a contiguous saturated lower tail;
4. shallowest saturated node can be retained as active guard;
5. reduced active dimension is strictly smaller than full dimension;
6. prescribed bottom flux is qbot = 0 under the currently qualified reduced-tail reconstruction;
7. top boundary uses the qualified fixed surface-flux provider path;
8. sources/sinks are absent in the currently admitted scope;
9. macropore physics is inactive in the currently admitted scope;
10. reduced constitutive/source-sink provider views are shape-consistent;
11. no interface-sensitivity request requiring unavailable reduced semantics is active;
12. reduced solve converges and reconstructed full candidate satisfies the normal physical/mass gates.

If any condition is false, route must be explicit full bypass or full fallback. No reduced state may be committed or repaired from full.

## Scope boundary

The proposed narrow admission scope is **not material-ID based**.

It is process/configuration based and limited to the exact mechanism class demonstrated by Z35/Z40/Z42:

- Richards matrix flow;
- contiguous saturated lower tail;
- qbot = 0;
- fixed surface-flux top route;
- zero source/sink terms;
- no macropore route;
- explicit opt-in manager profile;
- full-state transaction authority unchanged.

O05 is evidence for this scope; O14/B12 synthetic trajectory failures do not become exclusions by material ID, but they do prevent claiming heterogeneous portability beyond independently reference-valid cases.

## Frozen questions

Q1. Is every proposed eligibility item directly supported by current implementation/evidence?

Q2. Is every currently unqualified process path excluded or forced to full fallback/bypass?

Q3. Does the existing profile/config seam remain default-off and leave legacy execution unchanged?

Q4. Is Z42 sufficient evidence for a **narrow non-default admission candidate**, while explicitly not supporting broad production portability?

## Frozen classifications

### `QUALIFIED_Z45_NARROW_ADMISSION_SCOPE_READY`

Require:

- Q1–Q4 all true;
- no claim broader than existing evidence;
- fallback/bypass remains explicit;
- legacy/default remains unchanged;
- no new physics or numerical tolerance introduced.

### `Z45_SCOPE_NOT_BOUNDED`

Any unqualified process path can enter reduced execution without explicit guard/fallback.

### `Z45_EVIDENCE_INSUFFICIENT_FOR_NARROW_ADMISSION`

The proposed scope requires evidence not already present.

### `Z45_CONFIGURATION_DEFAULT_RISK`

Manager can become active without explicit opt-in or alter legacy default behavior.

## Positive consequence

A positive Z45 result authorizes one separate **canonical admission-candidate integration workunit** for this narrow non-default scope.

That successor must:

- implement/check explicit eligibility guards;
- keep manager default off;
- preserve exact full fallback/bypass;
- run focused CI/smoke only;
- document scope and exclusions prominently;
- not claim O14/B12 portability from failed synthetic holdouts.

## Production boundary

Z45 itself is not canonical admission.

`LEGACY_NUMERICS` remains production default.
