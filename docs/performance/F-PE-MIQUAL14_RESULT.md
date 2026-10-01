# F-PE-MIQUAL14 result — serialized manager break-even scaling

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL14_BREAK_EVEN_REACHED`

Qualification authority:

- workflow run: `36830158211`;
- job: `110264685878`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Aggregate result

The production-shaped serialized manager crosses runtime break-even at larger frozen geometries.

All three geometry banks complete 40,000/40,000 committed intervals in LEGACY and MANAGER modes with:

- zero retries;
- hard mass clean;
- exact final pressure-head state;
- exact final water-content state;
- exact storage;
- exact final saturated-tail identity;
- 100% reduced manager routing;
- zero fallback;
- zero bypass.

Classification:

`QUALIFIED_MIQUAL14_BREAK_EVEN_REACHED`.

## N16 / T13

Active/full fraction:

`13/16 = 0.8125`.

Deterministic work ratio:

`0.8125`.

Median paired wall ratio:

`1.03125`.

Geometric-mean wall ratio:

`1.03256`.

Median CPU ratio:

`1.03117`.

Interpretation:

The manager remains about 3.1% slower than LEGACY at N16.

Status:

`NO_GAIN`.

## N32 / T25

Active/full fraction:

`25/32 = 0.78125`.

Deterministic work ratio:

`0.78125`.

Median paired wall ratio:

`0.99642`.

Geometric-mean wall ratio:

`0.99883`.

Median CPU ratio:

`0.99635`.

Interpretation:

N32 is effectively the observed break-even region. The median result is slightly favorable to the manager, roughly 0.36% faster, but the gain is small enough to regard it as near-neutral rather than a strong production-speed claim.

Status:

`GAIN` under the frozen preregistered criterion.

## N64 / T49

Active/full fraction:

`49/64 = 0.765625`.

Deterministic work ratio:

`0.765625`.

Median paired wall ratio:

`0.97006`.

Geometric-mean wall ratio:

`0.97003`.

Median CPU ratio:

`0.97002`.

All seven paired wall ratios are below 1.0.

Interpretation:

At N64 the moving-interface manager is robustly about 3.0% faster than LEGACY through the complete serialized transaction/runtime route.

Status:

`GAIN`.

## Interpretation

MIQUAL14 resolves the apparent contradiction from MIQUAL09-13.

The manager architecture does produce end-to-end runtime benefit, but only once the active/full dimension reduction is large enough for solve-time savings to exceed fixed solver and manager overhead.

The relevant observations are:

- N16/T13: 18.75% deterministic work reduction, but about 3.1% slower runtime;
- N32/T25: 21.875% deterministic work reduction, approximately break-even runtime;
- N64/T49: 23.4375% deterministic work reduction, about 3.0% faster runtime.

The manager therefore should not be treated as universally faster merely because reduced row work is lower.

Runtime value depends on at least:

- full column dimension;
- active/full dimension fraction;
- reconstructible saturated-tail depth;
- fixed reference-solver overhead.

## Strategic conclusion

The moving-interface manager remains technically justified.

However, the production performance case is conditional:

- small columns such as N16 do not benefit;
- N32 is roughly neutral;
- N64 shows a reproducible positive runtime gain under the frozen equilibrium/basic-Richards envelope.

This supports a future activation policy based on a performance eligibility threshold rather than unconditional manager use.

That threshold is not yet production-admitted and should not be inferred directly from only three geometry points.

## Qualified claim boundary

Qualified:

- production-shaped serialized runtime break-even exists;
- break-even occurs between the tested N16 and N32/N64 regimes;
- N64/T49 is about 3% faster than LEGACY with exact physical equivalence;
- manager overhead and solver fixed cost explain the N16 negative result.

Not qualified:

- universal N32+ speedup;
- dynamic serialized runtime gain;
- a production threshold for active/full dimension ratio;
- optional-process performance;
- MultiSWAP scaling;
- default activation.

## Consequence

Do not continue adapter micro-optimization.

The next genuinely useful work, when resumed, is one of two directions:

1. derive and qualify a production activation rule from a broader dimension/tail-ratio bank; or
2. establish a valid dynamic serialized benchmark inside the manager envelope.

Neither is required to preserve the present technical result.

## Production boundary

No production-default change.

`LEGACY_NUMERICS` remains production default.
