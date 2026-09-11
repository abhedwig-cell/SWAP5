# F-TB07 run log

## Live start

- No F-TB07 or equivalent testbank branch existed at start.
- Exact F-TB06 parent authority: `163ed723cc4f2277746bdd54f338c4b06e2eaaa9`.
- Current canonical rechecked at `c7379b6b5b5f529ff96de3087379712bd665276a`.
- Current canonical source tree: `d5aec38b432242d2674885c8b8bd21d7f0fa0836`.
- Current canonical reference tree: `9d08625217d7c0a7385df9da6a04183bcd9cb9e6`.

## Gap selection

F-TB01 requires moving-current preservation for canonical capabilities. Surface evaporation already has permanent release-bank coverage through F-TB03 and restricted soil temperature now has F-TB06. The canonically admitted F-GC10/F-CI44 groundwater application-accuracy contract had no dedicated permanent testbank adoption.

F-TB07 therefore adopts that contract seam only. It does not create a numeric accuracy policy or production coupling claim.

## Authority

- F-GC10 closeout: `a1201dc870e4f5088f50b8d00e92e83457743174`.
- F-GC10 decision: `QUALIFIED_F_GC09_APPLICATION_ACCURACY_CONTRACT_FOR_CANONICAL_ADMISSION_WITH_EXPLICIT_TEMPORAL_INDICATOR_BINDING`.
- Application contract module blob: `c07d573d21e7d013ab962c0a9d28102ab7b5cdfc`.
- Immutable F-CI44 contract test blob: `54200c6ded7b2783375e02cc646ec00f61b70770`.

## Persist-first design

Eight stable F-TB01-compatible cases were registered before execution. The executable gate preserves the historical F-CI44 test matrix but checks the current post-F-CI45 consumer binding directly rather than falsifying the historical F-CI44 backend blob lock.

The work-unit contract, registry, validator, qualification runner, documentation, prequalification status and 30-invariant audit were persisted before qualification.

## FAST precloseout qualification

FAST succeeded on exact head `fb778d2581a18620f6f1a15cd4f00d58e1a2d201` in Actions run `34643569680`, job `103408874460`.

This established exact F-TB06 ancestry, the eight-case registry, profile counts, current-canonical source/reference trees, the immutable F-GC10 closeout and F-CI44 contract test, fail-closed scalar/provenance policy, current post-F-CI45 consumer normalization binding, and preservation of the hard nonclaims.

## First RELEASE attempt and fail-closed remediation

The first final candidate `d584f51340d024f43120fda2cceea2c5af7a69d6` ran as Actions `34643652390`. FAST passed on that exact SHA. RELEASE reached and passed all registry/provenance/static gates, including current consumer binding, dimensionless certificate normalization and F-GC10 nonclaim preservation, then stopped before compilation with:

`testbank/runners/run_ftb07_qualification.sh: line 91: tag: unbound variable`

Classification: testbank runner shell-initialization defect, not production source, physics, solver or scientific-oracle defect. With `set -u`, `local opt="$1" tag="$2" out="$BUILD/$tag"` evaluated `tag` before binding it. Remediation separates the three local declarations. No qualification marker, tolerance, case, source binding or nonclaim was changed.

## Closeout state

No production-source defect has been established. Final closeout still requires FAST and RELEASE success on one later exact `[ftb07-release]` head. RELEASE must execute the immutable contract matrix at O0/O2, require repeat and optimization-level transcript identity, preserve the current consumer binding and confirm zero `src/**` or `reference/**` delta.
