# F-MACRO-ALT42 — automatic paired-event selector

Date: 2026-10-01

Status: RESEARCH_DATA_ADAPTER_READY / MODEL_PHYSICS_UNCHANGED

Canonical authority: integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

Make ALT41 operational as soon as NEON, GFZ or another event-level payload becomes available.

The selector automatically searches event records for the three discriminating contrasts frozen in ALT41:

1. same-intensity short versus long events;
2. weak versus intermediate events with similar duration;
3. continuous versus fragmented events with the same source intensity and total input.

## Input contract

The selector accepts a JSON list or an object with an `events` list.

It directly understands the compact field names emitted by ALT16 where possible, including:

    storm_peak_mm_per_h
    storm_duration_h
    storm_sum_mm
    mean_antecedent_theta
    cv_antecedent_theta_across_sensors
    nsr_pf
    vt_pf_any_sensor

and converts:

    mm/h -> cm/day
    h -> day
    mm -> cm.

For GFZ or another dataset, a thin normalizer only needs to emit the generic normalized fields documented in the script.

## Matching rules

Pairs are always profile-local.

By default, candidate events must also be compatible in antecedent state:

    |Delta theta| <= 0.04

and, when available:

    relative antecedent-CV difference <= 50%.

Known ponding status must agree.

These tolerances are CLI options and therefore explicit/reproducible rather than hidden heuristics.

## Pair A: short versus long

Default conditions:

- source intensity within 20%;
- duration ratio at least 3;
- same profile;
- compatible antecedent state;
- compatible ponding status.

## Pair B: weak versus intermediate

Default conditions:

- one event <= 5 cm/day;
- one event >= 7 cm/day;
- duration within 25%;
- same profile and compatible antecedent state.

## Pair C: continuous versus fragmented

Requires an explicit shared `fragmented_group` label.

The selector never infers event fragmentation from timing gaps unless a dataset-specific normalizer has first established that semantic identity.

It additionally checks source intensity and, when available, total input.

## Evidential ranking

Ranking favors:

- stronger duration/intensity contrast appropriate to the pair type;
- observed antecedent-state comparability;
- observed ponding comparability;
- available PF outcome labels.

Missing values are never imputed.

## Synthetic contract fixture

A small synthetic payload and smoke test are persisted to prove that:

- expected short/long pairs are found;
- the continuous/fragmented pair is found only via explicit group identity;
- weak/intermediate pairs are found;
- events from different profiles are never paired.

## Files

    tools/research/macropore_alt42_paired_event_selector.py
    tools/research/fixtures/macropore_alt42_synthetic_events.json
    tools/research/macropore_alt42_selector_contract_test.py

## Decision

ALT41_EXPERIMENT_DESIGN = MACHINE_SELECTABLE
NEON_ALT16_OUTPUT = DIRECTLY_COMPATIBLE
GFZ = REQUIRES THIN EVENT NORMALIZER AFTER PAYLOAD MATERIALIZATION
MODEL_PARAMETERS = UNTOUCHED
EVENT_SELECTION = REPRODUCIBLE

## Next

When an event payload becomes accessible:

1. run the existing dataset parser/normalizer;
2. run ALT42;
3. freeze selected calibration and hold-out event IDs;
4. only then execute ALT35 fixed-sigma_B transferability.

Do not hand-pick events after seeing RFM residuals.
