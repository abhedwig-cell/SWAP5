# F-PE-ELASTIC67 — physical temporal-budget line closure

Date: 2026-09-30

Status: CLOSED_BOUNDED_RESEARCH_AUTHORITY

Owning branch:
`research/f-pe-elastic67-negative-n4-postmortem`

Canonical authority at closure:
`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

ELASTIC67 qualified result:
`docs/performance/F-PE-ELASTIC67_RESULT.md`

## Closure question

Can the mode-7 physical temporal-budget line now establish a complete
independent physical qualification for the frozen practical envelope, or does a
bounded independent-Reference blocker remain?

Frozen physical envelope:

- pressure-head error <= `0.01 cm`;
- water-content error <= `1e-5`;
- terminal bottom-flux relative error <= `1%`;
- integrated bottom-exchange relative error <= `0.5%`;
- hard physical mass acceptance remains a separate unchanged gate.

Frozen mode-7 head normalization:

`estimated_head_error = 0.17320259355765216 * Binf`.

For a `0.01 cm` head budget this corresponds to:

`Binf_limit = 0.05773585599727987 cm`.

No value above is promoted here to a universal SWAP default.

## Independent physical-oracle authority

The adaptive nested Reference chain established:

- C-SAFE accepted points: `96`;
- three-level independently qualified: `60`;
- physical-envelope failures among those 60: `0`;
- contraction failures: `0`.

The separately validated consecutive two-level fallback established:

- validation against all 60 three-level-qualified cases: PASS;
- residual pair available: `24`;
- physical-envelope failures among those 24: `0`;
- no consecutive pair: `12`.

Therefore the final independently qualified coverage remains:

`84 / 96 = 87.5%`.

All 84 independently qualified accepted cases satisfy the unchanged frozen
physical envelope and the independent mass requirements applicable to their
oracle construction.

No incomplete Reference case is counted as a physical pass.

## Remaining 12 cases

ELASTIC66 localized all twelve no-pair cases exactly to:

- profile 8016;
- h0 = -20 cm;
- accepted C-SAFE dt = `0.0009765625 day`;
- OFF, FIXED_1E6 and GENERATED identically;
- forcing deltas `-0.05`, `-0.035`, `+0.035`, `+0.05 cm/day`.

The gap is regime-independent and occurs on unsaturated trajectories. It is not
an active elastic-storage effect.

### Positive forcing: six cases

For `+0.035` and `+0.05 cm/day`, all nested Reference levels fail.

Existing qualified sensitivity evidence attributes the first N=2 failures to
the solver-local total-balance convergence criterion. Recovery occurs only
after changing that solver-local tolerance.

That evidence is causal for the numerical failure mechanism, but it does not
convert the affected cases into unchanged-Reference independent oracle passes.

These six therefore remain outside the 84-case independent physical
qualification denominator used for closure.

### Negative forcing: six cases

ELASTIC67 preserved N=2 as a successful mass-valid control and reproduced the
N=4 first-substep failure in all six cases.

For delta `-0.05 cm/day`:

- max compartment residual =
  `1.7748025271657752e-12 cm/day`;
- absolute total residual =
  `1.5289991495137656e-12 cm/day`.

Both exceed the frozen solver threshold.

For delta `-0.035 cm/day`:

- max compartment residual =
  `1.8718360195180139e-12 cm/day`;
- absolute total residual =
  `6.0573768223548541e-13 cm/day`.

Here the total criterion already passes while the local compartment criterion
does not.

Therefore the preregistered hypothesis that the six negative failures share
the positive-forcing total-balance-only mechanism is falsified.

Classification of the negative subset:

`QUALIFIED_NEGATIVE_FORCING_LOCAL_COMPARTMENT_RESIDUAL_BLOCKER`.

## ELASTIC68 decision

The handoff authorized at most one ELASTIC68 verification-only causal
total-balance sensitivity, and only if ELASTIC67 identified the same
total-balance residual-floor mechanism for the negative six.

That prerequisite is not met.

Starting the proposed ELASTIC68 total-balance sensitivity would therefore be
post-hoc and cannot close the negative subset, because delta `-0.035` is
already inside the frozen total-balance criterion.

No ELASTIC68 total-balance sensitivity is opened.

A future study of the negative local-compartment representation floor would be
a new research question outside this closed line. It would require its own
preregistration and independent authority and must not weaken the hard physical
mass gate.

## Physical-budget decision

Final classification:

`QUALIFIED_MODE7_PHYSICAL_ENVELOPE_WITH_LOCALIZED_REFERENCE_ORACLE_SOLVABILITY_BLOCKER`.

Qualified claim:

- within the frozen four-profile bank and tested mode-7/swKimpl=0 scope,
  84/96 C-SAFE accepted cases have independent Reference-oracle evidence;
- every one of those 84 cases remains inside the frozen head, theta, terminal
  bottom-flux and integrated bottom-exchange envelope;
- no physical-envelope violation has been demonstrated in the remaining 12;
- the remaining 12 cannot be counted as physical passes because unchanged
  independent Reference solvability is insufficient;
- the residual gap is sharply localized to profile 8016, h0=-20 cm and the
  four frozen forcing perturbations;
- positive and negative forcing fail for different qualified solver-local
  reasons.

The `0.01 cm` route is therefore **not falsified** in the tested scope, but it
is also **not completely independently qualified 96/96**.

## Production-admission decision

No new production default or application-policy admission is authorized by this
line.

In particular:

- `0.01 cm` is not admitted as a universal SWAP temporal head budget;
- no solver tolerance is relaxed;
- no hard mass gate is relaxed;
- no compartment tolerance is relaxed;
- frozen alpha is unchanged;
- C-SAFE semantics are unchanged;
- Richards physics and ELAS parameters are unchanged.

The already canonically admitted ELASTIC65 mechanism remains the production
boundary:

`mode7 + swkimpl=0 + admitted temporal history + explicit caller-owned positive head budget`
-> conservative normalized certificate
-> existing mass-first refine/recheck transaction route.

A future application may still supply an explicit positive head budget through
that admitted interface, but this closure does not designate `0.01 cm` as the
production default.

A complete F-CI14 numeric profile remains outside this authority. This line
does not qualify all eight F-CI14 endpoint metrics
(`h, theta, ponding, GWL, volact, ldwet, spev, saev`).

## Closure boundary

This research line is closed.

Do not reopen ELASTIC56/57 nonmonotonicity, refit alpha, widen the physical
budget, weaken hard mass, use non-consecutive Reference pairs, or count
incomplete oracle cases as passes on the basis of this closure.

If future work is commissioned, the narrow unresolved question is no longer
"does the 0.01 cm physical envelope fail?" It is:

how to obtain independently justified Reference evidence for the localized
profile-8016 small-dt local-compartment solvability floor without weakening the
physical mass contract.

That is a separate research line, not a continuation required for this closure.
