# TAB-HYD-CTX01 timestep-context capability result

Date: 2026-09-23

Status: **PASS — research contract recommendation**

Run: `35819421154`

Canonical preimage:

`integration/f-ci-canonical@b7d9c976e9b474545d54fa79b71ae134c25da156`

## Decision

**Select Option B: a generic fail-closed constitutive-provider context capability.**

Recommended contract shape:

`context_compatible(step_duration) -> logical`

The existing hot vector-valued `evaluate(...)` ABI remains unchanged.

## Gate results

### CTX-G1 — analytical identity: PASS

Across all five bounded profiles the capability-based temporal indicator
reproduced the canonical analytical indicator under the existing tight
equivalence gate.

Representative analytical/table head bounds remained the already qualified
values:

| profile | analytical Binf | generated table Binf |
| --- | ---: | ---: |
| coarse_dry_free | 1.3784398416230255 | 1.3784312239877143 |
| loam_mid_free | 0.7996648119042483 | 0.7996646096841126 |
| clay_wet_free | 0.6474189031127979 | 0.6474184467332830 |
| coarse_dry_pulse | 8.962293571359421 | 8.962357808213341 |
| loam_capillary | 1.3120751570491664 | 1.3120751262958033 |

Every profile reported:

`TABHYD_CTX01_ANALYTIC_IDENTITY=PASS`

### CTX-G2 — generated-provider availability: PASS

Every profile reported:

`TABHYD_CTX01_TABLE_AVAILABLE=PASS`

The temporal mathematics can therefore remain provider-generic.

### CTX-G3 — mismatched timestep fails closed: PASS

For each profile, provider timestep was deliberately rebound to 1.25 times the
request timestep while the request itself remained unchanged.

Both provider types reported the same failure class and route:

- analytical MvG:
  `TABHYD_CTX01_ANALYTIC_DT_MISMATCH_FAIL_CLOSED=PASS`;
- generated raw-head table:
  `TABHYD_CTX01_TABLE_DT_MISMATCH_FAIL_CLOSED=PASS`.

The generic temporal indicator uses no concrete constitutive-provider type
dispatch for this check.

### CTX-G4 — default fail closed: PASS

A dummy constitutive provider implementing only the existing required
`evaluate(...)` operation inherited the base capability and returned
incompatible context:

`TABHYD_CTX01_DEFAULT_FAIL_CLOSED=PASS`.

Thus unsupported/new provider implementations do not become temporal-indicator
eligible accidentally.

### CTX-G5 — hot ABI preservation: PASS

The complete abstract-interface block for

`constitutive_evaluate_ifc`

was compared before and after the candidate patch and remained textually
identical:

`TABHYD_CTX01_HOT_EVALUATE_ABI_UNCHANGED=PASS`.

Option B therefore avoids the broad provider/call-site ABI churn inherent in
Option A.

### CTX-G6 — analytical performance preservation: PASS

Balanced baseline/capability provider benchmarks:

- baseline analytical median: `0.26118875 s`;
- capability analytical median: `0.26003400 s`;
- observed delta: `-0.4421%`.

There is no material analytical hot-path regression. The candidate capability
is outside repeated constitutive evaluation.

## Why Option A is not carried forward

Option A would pass timestep explicitly through every constitutive
`evaluate(...)` invocation.

That design remains conceptually valid, but after Option B passes all required
invariants it has no compensating benefit in this work unit and would:

- change the frozen hot-provider ABI;
- require all constitutive providers and callers to migrate;
- expose every Newton constitutive evaluation to an unrelated timestep-context
  argument;
- increase the production delta without improving the demonstrated safety
  property.

Option A is therefore not falsified scientifically; it is **superseded by a
smaller qualified design** for the present K0 capability.

## Recommended production semantics

The production form should preserve the research semantics:

1. `constitutive_hydraulics_provider_t` gains a non-deferred
   `context_compatible(step_duration)` operation;
2. default implementation returns false;
3. default MvG overrides it using its bound `step_duration`;
4. generated table provider overrides it using its bound `step_duration`;
5. temporal-indicator owner requires compatibility before generic constitutive
   evaluation;
6. mismatch fails closed as `constitutive-dt-mismatch`;
7. no TAB-HYD-specific type check enters the temporal-indicator owner.

The precise public name can be changed by the production owner, but the
semantics above are the qualified contract.

## Disposition

**CONTRACT_RESEARCH_CLOSED / OPTION_B_RECOMMENDED_FOR_PRODUCTION_WORK_UNIT**

This run does not itself mutate or admit canonical production code.
