# F-PE-ELASTIC57 — non-monotone mode-7 certificate controller robustness result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic57-nonmonotone-certificate-controller`

Qualified postimage:
`5110ecdae9bbb4d64680cff4d0c182f3f6844b54`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36678385142`

Job:
`109768267477`

Conclusion:
SUCCESS.

## Question

Can the existing model-certificate retry semantics remain safe and bounded when
the mode-7 defect indicator is locally non-monotone under dt refinement?

## Controller simulated

ELASTIC57 did not modify the transaction core.

It simulated the existing `TX_TEMPORAL_MODEL_CERTIFICATE` retry semantics:

- start from retry index 0;
- halve dt on solver failure;
- halve dt on unavailable indicator;
- halve dt on failed hard mass ledger;
- compute `H_bound = alpha_global * Binf`;
- accept when `H_bound <= H_budget`;
- otherwise halve dt;
- stop after at most 9 attempts.

No rule assumes that Binf decreases after one halving.

Frozen:
`alpha_global = 0.17320259355765216`.

## Test bank

Targets:
- the 15 ELASTIC56 violating eligible sequences.

Controls:
- 15 exactly matched opposite-sign forcing sequences.

Research head budgets:
- 0.05;
- 0.10;
- 0.25;
- 0.50;
- 1.0;
- 2.0;
- 5.0;
- 10.0 cm.

Total controller outcomes:
`30 sequences * 8 budgets = 240`.

## Primary safety result

Across all 240 outcomes:

- paired unsafe accepts: `0`;
- full-trial hard mass rejections among accepted candidates: `0`;
- maximum accepted retry index: `7`;
- bounded termination: PASS.

Every accepted point for which a converged full+half reference endpoint was
available satisfied:

`H_INF <= H_budget`.

This supports the core safety hypothesis for directly verifiable accepts.

## Acceptance / exhaustion

Aggregate:
- accepted: `62`;
- exhausted: `178`.

Thus the candidate is structurally bounded but strongly conservative over this
bank.

Per research budget:

| H_budget cm | target accepted | target exhausted | control accepted | control exhausted |
|---:|---:|---:|---:|---:|
| 0.05 | 2 | 13 | 3 | 12 |
| 0.10 | 3 | 12 | 3 | 12 |
| 0.25 | 3 | 12 | 3 | 12 |
| 0.50 | 3 | 12 | 3 | 12 |
| 1.0 | 3 | 12 | 3 | 12 |
| 2.0 | 4 | 11 | 3 | 12 |
| 5.0 | 10 | 5 | 3 | 12 |
| 10.0 | 10 | 5 | 3 | 12 |

The violating target sequences therefore remain controllable over part of the
budget range.

## Non-monotonicity robustness

No controller oscillation occurred.

The policy never attempts to increase dt and never rejects a later candidate
merely because Binf was higher than at the previous retry.

Therefore local Binf increases do not create control-loop instability in this
bounded retry design.

They can, however, cause additional temporal rejection and later acceptance or
exhaustion.

## Paired safety evidence

Accepted outcomes:
- paired and directly safety-verified: `18`;
- accepted without paired full-half reference at that same dt: `44`.

The 44 unpaired accepts are important.

They are not observed safety failures.

But they cannot be used as direct evidence that realized endpoint error is
within the requested head budget because the full-half oracle is unavailable at
those exact accepted points.

Thus ELASTIC57 qualifies controller mechanics more strongly than it qualifies
all accepted states physically.

## Conservative refinement cost

Where both:
- the controller accepted at a paired point;
- and an earlier paired point already satisfied realized `H_INF <= H_budget`;

the controller sometimes refined further than the paired oracle.

Maximum observed extra refinement:
`6` retry levels.

This confirms that the frozen global envelope can be substantially
over-conservative operationally.

The controller is therefore safe-looking but potentially expensive.

## Control asymmetry

The preregistered hypothesis that opposite-sign controls would require no more
pathological retry behavior than the violating targets is not supported.

Controls remain highly exhausted across the budget sweep:
- 12 / 15 controls exhaust at every tested budget.

Targets improve at larger budgets:
- only 5 / 15 targets exhaust at 5 and 10 cm.

This asymmetry is not caused by Binf nonmonotonicity alone.

It reflects the underlying solver/convergence behavior of the opposite-sign
negative-forcing routes.

Therefore target-versus-control exhaustion is not a clean controller-only
metric.

## Profile summaries

Profile 11060:
- 16 budget outcomes;
- accepted 3;
- exhausted 13;
- unverified accepts 0;
- maximum extra refinement 0.

Profile 10260:
- 80 outcomes;
- accepted 35;
- exhausted 45;
- unverified accepts 25;
- maximum extra refinement 6.

Profile 8016:
- 64 outcomes;
- accepted 4;
- exhausted 60;
- unverified accepts 4.

Profile 3030:
- 80 outcomes;
- accepted 20;
- exhausted 60;
- unverified accepts 15;
- maximum extra refinement 3.

## Hypothesis assessment

H1. Controller terminates in at most nine attempts and does not oscillate:
SUPPORTED.

H2. Zero paired unsafe accepts:
SUPPORTED.

H3. Nonmonotonicity can increase refinement/exhaustion but does not produce a
paired unsafe accept:
SUPPORTED.

H4. Violating target sequences remain controllable over at least part of the
budget sweep:
SUPPORTED.

H5. Opposite-sign controls require no more pathological retry behavior than
targets:
FALSIFIED.

## Interpretation

ELASTIC56 established that Binf can increase locally even when the global
conservative envelope remains valid.

ELASTIC57 shows that the existing model-certificate retry semantics are already
structurally robust to that nonmonotonicity:

- retry direction is one-way;
- attempt count is bounded;
- there is no monotonicity assumption;
- paired accepted states remain within the requested error budget;
- mass remains a separate hard gate.

The remaining limitation is not controller instability.

The remaining limitation is evidence and efficiency:

1. 44 accepted outcomes lack a paired realized-error oracle at the exact
   accepted dt;
2. the global envelope can force up to six extra halving steps relative to a
   paired realized-error oracle;
3. many sequences exhaust before the certificate becomes permissive.

## Decision

Classification:

`QUALIFIED_BOUNDED_NONMONOTONE_CERTIFICATE_CONTROLLER_WITH_UNVERIFIED_ACCEPTS`.

No production temporal-policy change is authorized.

The next bounded workunit should independently verify the 44 unpaired accepted
states with a deeper reference construction that does not require the same
full+two-half convergence window.

A suitable next reference should:
- preserve the accepted full candidate;
- construct a deeper smaller-step reference trajectory from the same origin;
- compare endpoint H error against each accepted research budget;
- retain hard mass closure;
- remain observation-only.

Only after those unpaired accepts are adjudicated should transaction-level
production integration be considered.
