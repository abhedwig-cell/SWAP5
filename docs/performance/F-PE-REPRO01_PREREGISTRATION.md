# F-PE-REPRO01 — FGC44 exact process repeatability

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC`

Parent:
`F-PE-PROFILE05`

## Trigger

PROFILE05 established process-to-process nondeterminism in the live FGC44 route using one fixed compile:

- exact: 12/20 PASS, 8/20 FAIL;
- A2C: 16/20 PASS, 4/20 FAIL.

Every failed process ended at the first SWAP corrector trial with participant status:

`6 (TRIAL_FAILED)`.

Because exact/default itself fails, this workunit is owned by the exact route. Practical-mode performance is out of scope until repeatability is restored.

## First localization

In `fmr_groundwater_swap_participant_t%trial_from_origin`, status 6 is emitted only when:

`accepted_whole_window(trial_result, candidate, window)`

returns false after `backend%run_trial`.

That predicate requires:

- `result%completed`;
- candidate ready;
- bottom-interface exchange available;
- finite bottom outward exchange;
- finite terminal bottom outward flux;
- requested t0/t1 equal the coupling window;
- completed time equal window t1;
- candidate origin interval available and equal to the coupling window.

## Phase R1 — predicate attribution

Instrument a test-local copy of the participant module only.

Do not modify production `src/**` in R1.

Immediately after `backend%run_trial`, emit all fields controlling `accepted_whole_window`, including candidate interval availability and values.

Run repeated fresh exact processes from one fixed compile until both:

- at least one PASS;
- at least one status-6 FAIL

are observed, or until 40 exact repetitions complete.

A2C is not required for R1.

## Phase R2 — narrow failing subsystem

Once the first divergent predicate is identified, instrument only the upstream producer responsible for that field.

Examples:

- `result%completed=false`: transaction/executor completion path;
- candidate not ready: candidate construction/ownership;
- exchange unavailable/nonfinite: mass/interface result publication;
- completed-time mismatch: temporal transaction progression;
- candidate interval unavailable/mismatch: candidate provenance.

Do not add speculative repairs before R1 evidence.

## Runtime-state hypotheses

Candidate hypotheses to test only after predicate attribution include:

- uninitialized local or derived-type state;
- stale reusable workspace state;
- incomplete initialization of transaction/result structures;
- process-layout-sensitive undefined memory;
- environment-sensitive OpenMP/runtime behavior;
- hidden state that is not reset during FGC44 initialization.

These are hypotheses, not conclusions.

## Repair rule

A production repair may be added only after:

1. the failing predicate is deterministic in the diagnostic evidence;
2. its upstream ownership is identified;
3. a minimal repair has a direct causal rationale;
4. exact fixed-build repeatability passes at least 40/40 fresh processes;
5. existing exact FGC44 gates remain green.

## Performance rule

No coupled performance timing claim is made in REPRO01.

The objective is deterministic correctness of the exact route.
