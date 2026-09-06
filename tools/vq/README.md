# VQ tools

This directory contains verification and qualification tooling only. It must not contain production SWAP physics or become a hidden execution path for the kernel.

## VQ-1a scope

The first executable tool verifies that a supplied SWAP 4.3.1 archive is the exact documented B0 distribution before any output from it is admitted as reference evidence.

From the repository root:

```bash
python tools/vq/reference_identity.py --archive /path/to/SWAP_4.3.1.zip
python -m unittest tools.vq.test_reference_identity
```

Exit status is `0` only when both the documented size and SHA-256 match. A missing archive or any identity mismatch fails closed.

The tool reads `docs/verification/reference-baseline.json`; it does not duplicate the B0 identity in code.

## Planned next adapters

Later VQ slices may add thin runners for B0, B1 and B2 plus canonical result extraction. Those adapters remain outside production physics and must record the exact executable/source identity used for each qualification result.
