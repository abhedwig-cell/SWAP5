# F-MACRO-ALT02 — sorption-event memory analytical result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_RESULT / SORPTION_MEMORY_IRREDUCIBLE_IN_CURRENT_FORMULATION`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Question

Can the current SWAP macropore absorption formulation be represented as a Markov process in current matrix state and current fast-domain storage alone, with no explicit sorption-event history?

## Source and theory evidence

Recovered exact historical state evidence identifies distinct sorption-event continuation variables:

- `SorpDmCp`: Philip sorptivity at start of sorption event;
- `ThtSrpRefDmCp`: sorption reference water content;
- `TimAbsCumDmCp`: cumulative duration of a sorption event;
- `FlEndSrpEvt`: end-of-sorptivity-event flag.

The official SWAP macropore theory defines lateral absorption using Philip sorptivity. The cumulative absorption depends explicitly on elapsed time since first contact `t - t0`. Sorptivity itself depends on the initial matrix water content `theta0` at the first-contact time `t0`.

Therefore the future absorption rate is not, in the current formulation, a function only of current matrix moisture and current macropore storage.

Schematically:

```text
I_abs = F(S_p(theta0), t - t0, geometry)
q_abs(t) = [I_abs(t + dt) - I_abs(t)] / dt
```

with `theta0` and `t0` event-history quantities.

## Analytical falsification of memoryless R1b

Consider two states at a common current time `t*` with identical:

- current matrix water content/profile;
- current pressure head/profile;
- current macropore water storage;
- current macropore geometry;
- current forcing and all future forcing.

Let their prior contact histories differ so that either:

```text
t0_A != t0_B
```

or:

```text
theta0_A != theta0_B
```

while the current physical state has subsequently been equalized.

Under the present Philip-sorptivity formulation:

```text
I_abs,A(t*) != I_abs,B(t*)
```

in general, because the cumulative absorption curve carries both elapsed-contact-time and initial-moisture information.

Consequently the next-step absorption increment

```text
I_abs(t* + dt) - I_abs(t*)
```

can differ between A and B even when their current matrix state and fast-domain storage are equal.

This falsifies the strict memoryless hypothesis for exact preservation of the present SWAP sorptivity formulation.

## Decision

```text
E02-H0_MEMORYLESS_SUFFICIENCY = FALSIFIED_FOR_EXACT_CURRENT_SWAPSORPTIVITY_SEMANTICS
E02-H1_SORPTION_MEMORY = SUPPORTED_ANALYTICALLY
```

This result is stronger than the earlier toy-harness discrimination because it follows from the official model equation and source-backed state semantics.

## What is not yet proven

This does not prove that all three legacy arrays plus the event flag are irreducible.

The necessary information may potentially be compressed.

Candidate sufficient statistics include, for example:

- effective event age plus event-start sorptivity;
- effective cumulative absorption plus one reference moisture quantity;
- another low-dimensional transformation preserving the next-step absorption operator.

The minimum dimension remains open.

## Consequence for reduced model

A reduced model that seeks exact or near-exact preservation of current SWAP sorptivity behaviour must contain some history information beyond:

```text
theta_current + S_p_current
```

The revised research state lower bound is therefore:

```text
fast-domain current storage
+ nonzero sorption-history state
```

for configurations using sorptivity-based absorption.

For alternative physics that deliberately abandons Philip-event semantics, a memoryless exchange law remains a valid new-model hypothesis, but it must be evaluated as changed physics rather than as an exact state reduction.

## E03 status

Accepted wet-wall memory remains independently open.

Recovered repository evidence proves it was treated as separate accepted history (`FrMpWalWetOld` / `MacroporeAcceptedHistory`), but the currently recovered source/theory evidence is not yet sufficient to prove that this information role cannot be reconstructed from other current state.

E03 therefore remains preregistered and unresolved.

## Production boundary

No production source, state schema, restart contract or canonical physics is changed by this result.

The exact B1.11 source-materialization requirement in PPA-WU05-A1 remains open for production migration and complete source-level census.
