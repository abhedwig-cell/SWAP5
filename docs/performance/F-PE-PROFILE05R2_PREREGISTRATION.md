# F-PE-PROFILE05R2 — post-repair practical-stack rebaseline

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-REPAIR01`

Predecessors:
- `F-PE-PROFILE05`
- parallel draft `F-PE-PROFILE05R1` (#636), not used as lineage authority because it is stacked on the alternate repair branch #635.

## Trigger

PROFILE05 could not publish a combined A1+A2C live coupled performance result because the exact FGC44 route was process-to-process nondeterministic.

REPRO01 localized the failure to inactive-root mode-5 qbot materialization reading non-authoritative `provider_root_sink` scratch.

REPAIR01 (#637) corrected that ownership defect and qualified on one repaired postimage:

- inactive-root poisoned ROOT_SINK scratch: 40/40 PASS;
- exact first corrector: 40/40 PASS;
- root-active semantics: 20/20 repaired and 20/20 old-equivalent with paired parity PASS;
- fixed-build live exact: 20/20 PASS;
- fixed-build live A2C: 20/20 PASS;
- A1 live control: PASS;
- A2C live control: 6/6 PASS;
- A2C application sequence: PASS.

The repaired coupled reference is therefore available again as measurement authority.

## Purpose

Measure the retained practical performance modes together on one repaired production postimage:

1. exact default;
2. A1 only;
3. A2C only;
4. A1 + A2C.

PROFILE05R2 is strictly observation-only.

No `src/**` modification is permitted.

## Primary authority

The primary result is direct same-postimage live SWAP + MODFLOW6 timing.

Do not infer combined speedup by adding or multiplying prior A1 and A2C percentages.

## Coupled protocol

Use:

`tests/fpe/run_fpe_profile05_four_arm_modflow_e2e.sh`

Run five independent replicas.

For every arm and replica require:

- successful coupled completion;
- final MODFLOW head available;
- final SWAP exchange available;
- interface ledger endpoint available;
- coupled iteration count available.

Record:

- coupled-loop wall time;
- exact-relative runtime ratio;
- speedup;
- A1 fresh/reuse counts;
- stack/A1 and stack/A2C ratios.

## Endpoint rule

The repaired exact arm is authority.

A1, A2C and A1+A2C must preserve, in this qualification representation:

- final MODFLOW head;
- final SWAP exchange;
- interface ledger;
- coupled iteration count.

Any candidate-only failure is a robustness failure, not timing noise.

## Supporting measurements

On the same postimage also run:

- A2C application-shaped sequence;
- repeated Reference/application decomposition.

These support attribution but do not replace the direct four-arm coupled result.

## Timing interpretation

The coupled loop is sub-millisecond and therefore timing-noise sensitive.

For the five stack replicas report:

- all raw exact and stack times;
- per-replica stack speedup;
- median and mean stack speedup;
- minimum and maximum stack speedup;
- stack/A1 ratio;
- stack/A2C ratio.

A practical-stack speedup claim requires directionally consistent replicated evidence.

## Closure

PROFILE05R2 closes with either:

1. a valid post-repair A1+A2C end-to-end rebaseline and a measured next hotspot; or
2. a specifically localized new blocker.

Any subsequent optimization requires a separate preregistered workunit.
