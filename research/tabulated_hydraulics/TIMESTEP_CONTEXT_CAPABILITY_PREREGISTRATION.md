# TAB-HYD timestep-context capability preregistration

Date: 2026-09-23

Status: **research experiment preregistered; no canonical mutation**

Experiment: **TAB-HYD-CTX01**

## Question

What is the smallest generic constitutive-provider contract change that lets the
Reference-Richards temporal-indicator owner verify the existing invariant

`provider timestep context == request%step_duration`

without concrete provider type dispatch and without changing the hot
constitutive evaluation ABI?

## Candidates

### A — timestep passed through every evaluate call

Change the constitutive evaluation signature so every call receives explicit
timestep context.

This is scientifically clean and stateless, but changes the existing hot-path
ABI and therefore all constitutive providers and call sites.

### B — generic context compatibility capability

Keep the existing vector `evaluate(...)` ABI unchanged and add one generic
provider operation:

`context_compatible(step_duration) -> logical`

Contract semantics:

- base/default implementation returns `.false.` (fail closed);
- a provider may override only when it can prove that its bound context is
  compatible with the supplied timestep;
- analytical MvG and generated raw-head provider compare their bound
  `step_duration` to the supplied value using the already existing canonical
  tolerance:
  `16*epsilon*max(1,abs(bound_dt),abs(request_dt))`.

The temporal-indicator owner first requires context compatibility and then
dispatches constitutive evaluation only through the abstract provider ABI.

## Frozen nonchanges

The experiment may not change:

- constitutive formulas;
- raw-head400 representation;
- temporal-indicator mathematics;
- temporal normalization;
- solver residual/Jacobian;
- transaction policy;
- retry policy;
- tolerances;
- state ownership.

## Gates

CTX-G1 — analytical identity

For all five bounded profiles, the capability-dispatch analytical indicator
must reproduce the current canonical indicator within the already qualified
`1e-14*max(1,abs(reference))` comparison, including route, availability and
solve counters.

CTX-G2 — generated-provider availability

For all five bounded profiles, the generated raw-head provider must produce the
same finite/available characterization class already established by
TAB-HYD-005.

CTX-G3 — fail-closed mismatch

With the request timestep unchanged but provider bound timestep deliberately
changed:

- analytical MvG must return temporal-indicator FAILED with
  `constitutive-dt-mismatch`;
- generated raw-head provider must return the same failure class/route.

No type-specific branch is allowed in the capability indicator.

CTX-G4 — default fail closed

A constitutive provider that does not override the capability must report
incompatible context by default.

CTX-G5 — hot ABI preservation

The abstract `evaluate(...)` signature must be byte/text unchanged by the
candidate patch. Provider/solver hot call sites must not receive an added
timestep argument.

CTX-G6 — performance preservation

Because the capability is outside repeated constitutive hot evaluation, no
material analytical provider-evaluation penalty is expected. A repeated
provider benchmark must show no stable material regression attributable to the
contract extension.

## Decision rule

Prefer B over A if all B gates pass, because B then satisfies the required
invariant without broad hot-path ABI churn.

Reopen A only if B cannot express the required invariant or introduces a
scientific/ownership ambiguity.

No production implementation is authorized by this experiment.
