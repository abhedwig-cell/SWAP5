# F-MQ04b B1.10 event-local reference extraction

Status: `BLOCKED_REFERENCE_RUN_CHECKPOINT_MISSING / FAIL_CLOSED`

## Scope

F-MQ04b attempts the first real reference-derived event-local fixture for MultiSWAP qualification. The preferred first fixture is a quiet soil-water continuation interval because it can later support P01, P10, P11 and P16 without event-specific state.

No production source is changed.

## Evidence inspected

The qualified B1.10 source identity is available and admitted through VQ. The repository tree at inspected `main` commit `fafeebdece209abcc320b24a3c8c2757800b2e0e` contains the B1.10 reference pin, B1.10 reconstruction/admission tooling and historical/legacy reference evidence.

Within `tools/vq/cases`, the only B1.10-specific item found is `b1-10-reference-pin.json`. The complete inspected tree does not contain a B1.10 machine-readable event checkpoint record with the data required by the F-MQ03 fixture contract.

`tools/vq/qualify_hupselbrook.py` is not a substitute. It qualifies the B0 Hupselbrook README case at legacy report precision and explicitly reports `hard_mass_gate_eligible: false`.

Historical A23BU real-SWAP transactional evidence is also not a substitute because its physical oracle belongs to the B1.6-era transaction integration line, not the current B1.10 corrected legacy reference.

## Required evidence still missing

The machine-readable candidate `tests/multiswap/reference_candidates/b1_10_quiet_candidate.json` therefore remains blocked until all of the following exist for one exact qualified reference run:

1. reference run ID;
2. committed continuation state exactly at `t0`;
3. short-interval forcing;
4. numerical reference configuration;
5. expected endpoint state;
6. unrounded internal mass accounting;
7. extractor identity plus output hash.

The candidate also records forbidden substitutions: hand-built physical state, B1.6 endpoint constants, rounded BAL/BLC values as hard mass oracle, or branch names in place of exact commits.

## Fail-closed gate

`reference_candidate_gate.py` prevents the candidate from being marked ready while any required evidence remains missing. It also checks the exact commit/hash shape and consistency between repository evidence and the declared checkpoint status.

Local gate command:

`python3 tests/multiswap/run_fmq04b_gate.py`

Observed during construction:

- tests: 6;
- failures: 0;
- errors: 0.

This means the **blocker is qualified**, not that a physical fixture exists.

## Decision

F-MQ04b does not fabricate the first B1.10 physical fixture. Status remains `BLOCKED_REFERENCE_RUN_CHECKPOINT_MISSING` until VQ can produce a qualified run extraction with unrounded mass and committed continuation state.

The next substep F-MQ04c can still implement the admission/readiness bridge to the F-MQ03 fixture builder and prove that an incomplete physical candidate cannot be admitted. F-MQ04d remains dependent on the canonical SWAP5 continuation interface from F-CI/F-KT.

## Architecture invariants

This fail-closed decision protects invariants 4, 5, 7, 8, 9, 13, 25, 29 and 30 and avoids converting historical or rounded evidence into a false production oracle.
