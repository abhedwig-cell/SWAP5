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

`B1.5p1` is the provenance-repaired five-fix predecessor. `B1.6` adds SWAP-009. Both remain immutable qualified historical predecessors of the current reference.

Their exact identities can be checked with:

```bash
python tools/vq/b1_snapshot_identity.py \
  --reference-root /path/to/SWAP5-checkout \
  --pin tools/vq/cases/b1-5p1-reference-pin.json

python tools/vq/b1_snapshot_identity.py \
  --reference-root /path/to/SWAP5-checkout \
  --pin tools/vq/cases/b1-6-reference-pin.json
```

## Current B1.7 corrected reference

`B1.7` is the current corrected-reference oracle:

```text
B1.7 = B1.6 + SWAP-010
```

SWAP-010 shares `WC_K_models_04_11.f90` with SWAP-009. The B1.7 admission therefore pins canonical B0 provenance and the exact ordered B1.6 preimage.

Repository admission bookkeeping is checked by:

```bash
python tools/vq/b1_7_admission_gate.py
```

The gate verifies the current manifest/snapshot, ordered patch identities, canonical B0 preimages, the SWAP-010 ordered B1.6 preimage and the pinned B1.7 source identity. It is a provenance/bookkeeping gate and does not replace the compiled SWAP-010 qualification evidence.

Exact source reconstruction from canonical B0 is available through:

```bash
python tools/vq/b1_7_reconstruct.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --output-dir /tmp/B1.7/SWAP
```

Expected final source identity:

```text
members          63
source bytes      1,860,091
manifest SHA-256  62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba
```

SWAP-010 has passed the source-bound model-7 capacity-derivative consistency gate, a representative full model-7 SWAP production-path regression and a hard unrounded legacy mass gate for the corrected candidate. The strong nonlinear-route difference is qualification evidence only, not a performance benchmark.

## Expected differences

`docs/verification/expected-differences.json` defines the admitted B0 -> B1.7 difference envelopes. Any unregistered difference remains a qualification failure. B1 is a corrected legacy reference, not a license for approximate equivalence.

## B2 reference-entrypoint admission

Before a numerical B1.7 -> B2 comparison can run, the candidate checkout must pass:

```bash
python tools/vq/b2_reference_gate.py \
  --repo-root /path/to/SWAP5-checkout \
  --candidate tools/vq/cases/b2-reference-candidate.json
```

The fail-closed gate requires an exact B2 commit, integrated callable reference-mode entrypoint, explicit reference numerical policy, canonical result contract, generic `[t0,t1]`, committed physical state and forcing inputs, separate numerical configuration, unrounded mass accounting and transaction diagnostics.

The current candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`. B1.7 admission changes legacy reference/tooling state only; it does not create the missing production B2 seam.

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
