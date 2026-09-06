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

## B1 identity gate

The current default pin is the provenance-repaired `B1.5p1` snapshot:

```bash
python tools/vq/b1_snapshot_identity.py --reference-root /path/to/SWAP5-checkout
```

The gate verifies the pinned snapshot blob, canonical B0 member-manifest blob, every stored patch SHA-256 and every declared B0 target preimage. `B1.5p1` passes this identity gate. Historical `B1.2` through `B1.5` remain failed-oracle audit records and are not rewritten.

See `docs/verification/vq-1c-b1.5p1-evidence.md`.

## B1.5p1 deterministic reconstruction

VQ reconstructs the corrected source tree independently from the exact B0 distribution:

```bash
python tools/vq/b1_reconstruct.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --output-dir /tmp/B1.5p1/SWAP
```

The reconstruction fails closed unless:

- the B0 distribution identity passes;
- the nested B0 `SWAP.ZIP` SHA-256 passes;
- each corrected target starts from the exact canonical B0 preimage;
- every byte target occurs exactly once;
- all five resulting target SHA-256 values equal the B1.5p1 snapshot declarations;
- the final 63-member reconstructed source manifest equals `c50da618aef92f99103531390e243144403060b0066e8dc3d827b79085bd9c30`.

The first B0 -> B1 control edges also pass with no numerical difference on official grass growth and the symmetric Hupselbrook balance-only GNU compatibility path. This does not yet qualify every defect-triggering B1 correction. See `docs/verification/vq-1c2-b1.5p1-reconstruction.md`.

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
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b1_reconstruct
```

Every future B1/B2 adapter must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
