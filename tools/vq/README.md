# VQ tools

This directory contains verification and qualification tooling only. It must not contain production SWAP physics or become a hidden production execution path.

## B0 identity

```bash
python tools/vq/reference_identity.py --archive /path/to/SWAP_4.3.1.zip
```

The gate reads `docs/verification/reference-baseline.json` and fails closed on size or SHA-256 mismatch.

## B0 provisional exact-source runner

```bash
python tools/vq/b0_source_runner.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/vq-b0 \
  --case 2.grassgrowth
```

The GNU runner is capability-limited verification infrastructure. It is not declared globally equivalent to the packaged Intel executable. Case-specific evidence and limitations are recorded under `tools/vq/cases/` and `docs/verification/`.

For the Hupselbrook legacy balance-only smoke:

```bash
python tools/vq/b0_source_runner.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/vq-hupsel \
  --case 1.hupselbrook \
  --disable-csv
```

## Legacy balance normalization

```bash
python tools/vq/balance.py --bal result.bal --blc result.blc
python tools/vq/qualify_hupselbrook.py --bal result.bal --blc result.blc
```

BAL/BLC values are rounded to `0.01 cm`. Passing these gates is regression evidence only and does not satisfy the future hard invariant-13 mass gate.

## B1 provenance gate

The current default pin is B1.5:

```bash
python tools/vq/b1_snapshot_identity.py --reference-root /path/to/SWAP5-checkout
```

The gate fails closed when a stored patch artifact is missing or its SHA-256 differs from the immutable snapshot declaration. At latest main re-read commit `3fe22ac2ac5c16fac015c8bee3d46cec6e7ba443`, B1.5 fails this gate because it inherits unresolved SWAP-005/006/007 provenance mismatches. The newly added SWAP-008 patch and B0 preimage both pass. See `docs/verification/vq-1c-b1.5-evidence.md` and GitHub issue #19.

## Unrounded mass accounting

The VQ normalization contract is:

```text
docs/verification/mass-accounting-contract.md
tools/vq/contracts/mass-accounting-record.schema.json
```

It is a verification interchange contract, not a required production object layout.

## Unit tests

```bash
python -m unittest \
  tools.vq.test_reference_identity \
  tools.vq.test_balance \
  tools.vq.test_b0_source_runner \
  tools.vq.test_b1_snapshot_identity
```

Every future B1/B2 adapter must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
