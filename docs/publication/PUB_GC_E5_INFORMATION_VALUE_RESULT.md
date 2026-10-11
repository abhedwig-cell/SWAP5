# PUB-GC E5 result — value of supplied response information

## Status

**SUPPORTED_RESTRICTED — independent ACCELERATE continuation gate NOT passed**

Date: 2026-09-18.

Primary numerical evidence:

- source head: `41e68a89a52f1f0fac00c8cfe920152ffd4e3fda`;
- workflow run: `35351467531`;
- job: `105620375280`;
- uploaded raw artifact: `10550095859`;
- artifact digest: `sha256:7d19287d89a74848928a566855205ffebd43081ddbb5d19846684f32b265fac4`.

All four preregistered baseline matrices completed. The workflow subsequently failed only in the summary writer because a generated Python newline string was malformed. The raw four-baseline evidence was uploaded before job cleanup and independently re-parsed. No scientific treatment was rerun or changed to obtain the result below. The summary-writer defect is repaired separately.

## Question

E4 established that the current supplied quantity `u_A` is a finite-window flux-driven predictor response and is not universally identical to the head-driven interface derivative `J_R`.

E5 asks the next question:

> How much computational value does supplied response information provide over a competent black-box coupling method?

The controlled groundwater map was chosen so that local coupling strength could be set directly:

```text
C = |gamma J_R|
```

while every SWAP response evaluation remained a real finite-window prescribed-head trial from the E4 qualification path.

Methods:

```text
FP
AITKEN
SECANT_COLD
U_A
ORACLE_JR
```

The primary work metric is the number of real full-window SWAP head-response evaluations after common predictor setup.

## Main result

The strongest result is negative for a standalone ACCELERATE claim.

Across the 18 cases in which both cold secant and the zero-cost `J_R` oracle converged:

- oracle saved **one** SWAP evaluation in 16 cases;
- oracle saved **two** evaluations in exactly one case: B2, `C=2.0`;
- oracle saved **zero** evaluations in one case: B4, `C=1.5`;
- there was **no** case in which the oracle converged while cold secant failed.

The supplied `u_A` method had the same evaluation-count pattern as the oracle in every comparable converged case.

This is very close to the analytical pre-result control: on a smooth scalar interface, a cold secant method needs only one extra black-box evaluation to identify the local slope that the derivative-informed method receives explicitly.

## Algorithm matrix

| baseline | C | FP | Aitken | cold secant | supplied u_A | zero-cost J_R oracle |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| B1 | 0.1 | 6 | 3 | 3 | 2 | 2 |
| B1 | 0.5 | 15 | 3 | 3 | 2 | 2 |
| B1 | 0.9 | >20 | 3 | 3 | 2 | 2 |
| B1 | 1.1 | domain fail (16) | 3 | 3 | 2 | 2 |
| B1 | 1.5 | domain fail (6) | 3 | 3 | 2 | 2 |
| B1 | 2.0 | domain fail (4) | 3 | 3 | 2 | 2 |
| B2 | 0.1 | 6 | 4 | 4 | 3 | 3 |
| B2 | 0.5 | 15 | 4 | 4 | 3 | 3 |
| B2 | 0.9 | >20 | 4 | 4 | 3 | 3 |
| B2 | 1.1 | domain fail (14) | 4 | 4 | 3 | 3 |
| B2 | 1.5 | domain fail (6) | 4 | 4 | 3 | 3 |
| B2 | 2.0 | domain fail (5) | 5 | 5 | 3 | 3 |
| B3 | all C | domain fail at first trial | same | same | same | same |
| B4 | 0.1 | 6 | 4 | 4 | 3 | 3 |
| B4 | 0.5 | 14 | 4 | 4 | 3 | 3 |
| B4 | 0.9 | >20 | 4 | 4 | 3 | 3 |
| B4 | 1.1 | domain fail (8) | 4 | 4 | 3 | 3 |
| B4 | 1.5 | domain fail (6) | 3 | 3 | 3 | 3 |
| B4 | 2.0 | domain fail (4) | 4 | 4 | 3 | 3 |

Numbers are real SWAP evaluations. “Domain fail (n)” means the nth attempted SWAP response evaluation left the admitted head-response transaction domain.

## Plain fixed point

Plain fixed point behaves as expected from the frozen linear control.

For `C=0.1` it converges in six SWAP evaluations.

For `C=0.5` it needs 14–15 evaluations.

At `C=0.9` it does not meet the coupling tolerance within the preregistered 20-evaluation budget.

For several `C>1` cases its oscillating/diverging iterates eventually leave the admitted SWAP response domain.

Thus E5 confirms that acceleration is genuinely useful relative to unaccelerated fixed-point coupling near and beyond the local fixed-point stability boundary.

That statement is distinct from the question of whether **component-supplied derivatives** add value over black-box acceleration.

## Aitken and cold secant

Aitken and the scalar cold-secanted IQN/Anderson analogue have nearly identical work and the same successful convergence domain in the primary matrix.

Typical work is:

```text
B1: 3 SWAP evaluations
B2: 4, increasing to 5 at C=2
B4: 3–4
```

Both remain convergent in cases where plain fixed point reaches its evaluation limit or leaves the SWAP response domain.

This reinforces the literature-derived requirement that response-informed coupling must be compared against a strong black-box accelerator rather than plain fixed point.

## Zero-cost oracle

The oracle is intentionally unrealistically favorable: E4 `J_R` is supplied at zero acquisition cost.

Even under that assumption, its dominant benefit over cold secant is only:

```text
1 full-window SWAP evaluation.
```

The only two-evaluation saving occurs for B2 at `C=2.0`.

There is no observed convergence-domain extension over cold secant.

The preregistered quantitative continuation rule required either:

1. oracle convergence where cold secant fails; or
2. a saving of at least two SWAP evaluations in reproducible difficult cases spanning at least two baselines.

Neither condition is satisfied.

Therefore the E5b warm-history study is **not required to decide the standalone ACCELERATE gate**. Warm history can only strengthen the black-box comparator relative to the cold baseline used here.

## Supplied u_A

Within B1, B2 and B4, `u_A` requires exactly the same number of SWAP evaluations as the zero-cost true-`J_R` oracle.

This is useful implementation evidence: where E4 showed that the two response magnitudes nearly coincide, the cheaper already-available predictor response captures essentially all observed derivative-information value.

It does **not** establish a general equivalence between `u_A` and `J_R`; E4 already falsified that broader identity.

### B3 limitation

B3 was intended as the mechanism case because E4 found:

```text
|J_R| / u_A ~= 1.081.
```

However, at the preregistered initial displacement:

```text
H_0 = H_ref + 1e-6 m
```

the very first real prescribed-head SWAP trial lies outside the admitted response domain.

Consequently all five algorithms fail at evaluation 1 for all B3 coupling strengths.

This is not an algorithm ranking and must not be used as evidence for or against `u_A` acceleration.

It is nevertheless scientifically relevant: component response-domain admissibility can dominate the outer coupling algorithm before derivative quality becomes the limiting issue.

A targeted B3 domain study could still be useful mechanistically, but it cannot rescue the predeclared standalone E5 continuation gate because that gate required reproducible advantage across at least two baselines.

## Information economics

E5a uses a zero-cost oracle.

A practical centred finite-difference `J_R` would require additional SWAP evaluations. In the dominant E5 result, where a perfect free derivative saves only one black-box evaluation, a two-extra-evaluation derivative acquisition would be computationally negative.

An analytic or otherwise near-free derivative can retain a one-evaluation advantage, but that is an implementation optimization rather than the general information-value result originally sought for ACCELERATE.

The current `u_A` is different in this respect: it is already available from the predictor response and therefore its observed one-evaluation saving can be practically useful without a separate derivative acquisition.

## Publication decision

The preregistered continuation gate is not passed.

Current disposition:

```text
PUB-GC / COUPLE:
    retain response-informed coupling and E4/E5 as substantive method/results sections.

PUB-RC / ACCELERATE:
    do not continue as a presumptive independent manuscript.
```

The reason is not that response information has zero value.

The evidence shows:

- large benefit relative to plain fixed point in difficult scalar coupling;
- modest benefit relative to competent black-box acceleration;
- no demonstrated convergence-domain advantage over cold secant;
- no general value for acquiring an additional true head-driven derivative when the already-available `u_A` performs equivalently in the tested admissible controls.

A future independent acceleration paper would require qualitatively new evidence, for example a higher-dimensional interface, regime transitions with stale black-box history, or another setting in which supplied response information gives a reproducible advantage larger than the scalar cold-learning cost.

## Consequence for the central paper

E5 strengthens rather than weakens PUB-GC.

The paper can now make a more nuanced methodological argument:

> Strong coupling and acceleration can be essential for numerical interface convergence, but exposing a more exact component derivative is not automatically worth its information cost. In the tested scalar finite-window coupling, Aitken/secant black-box learning recovers almost all of the value of a perfect free local interface derivative within one additional SWAP evaluation.

Combined with E4, the method lesson becomes:

```text
response information must be typed by its finite-window map
AND
its computational value must be measured against learned black-box response.
```

That is a stronger and more defensible result than claiming a new tangent acceleration method.
