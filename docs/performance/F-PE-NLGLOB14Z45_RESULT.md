# F-PE-NLGLOB14Z45 result — narrow admission scope and eligibility contract

Date: 2026-09-30

Status:

`Z45_SCOPE_NOT_BOUNDED`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z45-admission-scope-eligibility@12cd8ccd5a5aeacf709bfcbad115dc2aea1cccd6`

## Result

The evidence supports a narrow non-default manager scope in principle, but the current runtime seam does not yet enforce that scope explicitly enough for admission.

Frozen classification:

`Z45_SCOPE_NOT_BOUNDED`.

## What is already bounded

Current manager/runtime evidence establishes:

- full accepted state remains the committed physical authority;
- reduced state/request/workspace is reconstructible scratch;
- contiguous-tail geometry and reduced dimension are explicit;
- ineligible geometry produces full bypass;
- reduced failure produces explicit full fallback;
- diagnostics expose reduced/fallback/bypass route;
- historical Z35 fallback/bypass/no-leak behavior is qualified;
- Z42 demonstrates a physically exact, faster sequential reduced trajectory in the supported O05/N64 mechanism class.

## Missing explicit eligibility guards

The current manager active-view seam does not itself reject all process configurations outside the proposed narrow scope.

In particular, the manager geometry eligibility currently does not enforce:

- prescribed qbot = 0;
- qualified fixed surface-flux top-boundary route;
- macropore physics inactive;
- zero source/sink scope;
- absence of unsupported interface-sensitivity semantics.

The reduced-request builder copies physical, boundary and evaluation context and disables interface-sensitivity capture, but that is not equivalent to an explicit fail-closed admission guard.

Therefore an unqualified process path could be presented to the reduced manager seam unless the caller independently prevents it.

## Configuration seam

A default-off / explicit-opt-in moving-interface numerical-profile seam has been demonstrated on the Z43 production-candidate branch.

However that seam is not sufficient by itself to bound physical eligibility.

The admission contract must combine:

1. explicit opt-in configuration;
2. explicit process eligibility;
3. explicit full bypass/fallback.

## Interpretation

This is not a moving-interface physics failure.

It is an admission-layer safety gap.

The accumulated evidence is sufficient to define the intended narrow scope, but not sufficient to call that scope enforced in the current runtime implementation.

The fix is bounded and architectural: add a typed eligibility predicate/guard at the manager boundary and test fail-closed behavior for every excluded process class.

No further trajectory discovery is needed before that guard exists.

## Qualified claim boundary

Qualified:

- narrow supported mechanism class can be stated from existing evidence;
- full fallback/bypass architecture already exists;
- current geometry-only eligibility is insufficient for production admission;
- no new physical investigation is required to fix the admission-layer gap.

Not qualified:

- `QUALIFIED_Z45_NARROW_ADMISSION_SCOPE_READY`;
- production admission;
- broad heterogeneous portability;
- production default change.

## Consequence

Open:

`F-PE-NLGLOB14Z46 — explicit moving-interface eligibility guard and non-default admission seam`.

Z46 must add/check fail-closed eligibility for at least:

- manager explicitly enabled;
- qbot = 0 / qualified bottom route;
- fixed surface-flux top provider route;
- macropore inactive;
- zero source/sink admission scope;
- unsupported interface sensitivity absent;
- valid contiguous saturated tail;
- active dimension strictly smaller than full dimension.

Every failed eligibility condition must route explicitly to full bypass with a typed/diagnostic reason.

Reduced solve failure must remain explicit full fallback.

Z46 should be a focused compiled smoke/contract workunit, not another long trajectory campaign.

## Production boundary

No production admission is authorized by Z45.

`LEGACY_NUMERICS` remains production default.
