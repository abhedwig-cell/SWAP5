# VQ tools

This directory contains verification and qualification tooling only. It must not contain production SWAP physics or become a hidden production execution path.

## B0 identity and provisional runner

```bash
python tools/vq/reference_identity.py --archive /path/to/SWAP_4.3.1.zip
python tools/vq/b0_source_runner.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/vq-b0 \
  --case 2.grassgrowth
```

The GNU runner is capability-limited verification infrastructure. It is not declared globally equivalent to the packaged Intel executable. Legacy BAL/BLC normalization is available through `balance.py`, but its `0.01 cm` output precision is not sufficient for the future hard invariant-13 mass gate.

## Qualified predecessor snapshots

`B1.5p1`, `B1.6` and `B1.7` remain immutable qualified historical predecessors. Their exact identities can be checked with the corresponding pins under `tools/vq/cases/` using `b1_snapshot_identity.py`.

## Current B1.8 corrected reference

`B1.8` is the current corrected-reference oracle:

```text
B1.8 = B1.7 + SWAP-013
```

SWAP-013 targets `readswap.f90`, which is unchanged by B1.1-B1.7, so its ordered B1.7 preimage is identical to canonical B0. The correction adds only the PDI model 8-11 `0 < HA < H0` validation guard after the existing magnitude conversion.

Repository admission bookkeeping is checked by:

```bash
python tools/vq/b1_8_admission_gate.py
```

The exact source-bound guard gate, including a strict GNU Fortran 9-case harness, is:

```bash
python reference/swap-4.3.1/patches/SWAP-013/tests/run_guard_gate.py
```

Exact source reconstruction from canonical B0 is available through:

```bash
python tools/vq/b1_8_reconstruct.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --output-dir /tmp/B1.8/SWAP
```

Expected final source identity:

```text
members          63
source bytes      1,860,493
manifest SHA-256  e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae
```

SWAP-013 changes only invalid-input acceptance/rejection. Valid PDI constitutive equations, non-PDI models, solver policy, time integration and water-balance equations are unchanged.

## Expected differences

`docs/verification/expected-differences.json` defines the admitted B0 -> B1.8 difference envelopes. Any unregistered difference remains a qualification failure. B1 is a corrected legacy reference, not a license for approximate equivalence.

## B2 reference-entrypoint admission

Before a numerical B1.8 -> B2 comparison can run, the candidate checkout must pass:

```bash
python tools/vq/b2_reference_gate.py \
  --repo-root /path/to/SWAP5-checkout \
  --candidate tools/vq/cases/b2-reference-candidate.json
```

The fail-closed gate requires an exact B2 commit, integrated callable reference-mode entrypoint, explicit reference numerical policy, canonical result contract, generic `[t0,t1]`, committed physical state and forcing inputs, separate numerical configuration, unrounded mass accounting and transaction diagnostics.

The current candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`. B1.8 admission changes legacy reference/input-validation state only; it does not create the missing production B2 seam.

## Unrounded mass accounting

The future B2 normalization contract is:

```text
docs/verification/mass-accounting-contract.md
tools/vq/contracts/mass-accounting-record.schema.json
```

It is a verification interchange contract, not a required production object layout. Hard mass conservation may not be weakened by execution policy.

## Unit tests

```bash
python -m unittest \
  tools.vq.test_reference_identity \
  tools.vq.test_balance \
  tools.vq.test_b0_source_runner \
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b1_reconstruct \
  tools.vq.test_b2_reference_gate
```

Every future B1/B2 adapter must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
