# VQ tools

This directory contains verification and qualification tooling only. It must not contain production SWAP physics or become a hidden execution path for the kernel.

## VQ-1a: B0 identity

Verify that a supplied SWAP 4.3.1 archive is the exact documented B0 distribution:

```bash
python tools/vq/reference_identity.py --archive /path/to/SWAP_4.3.1.zip
python -m unittest tools.vq.test_reference_identity
```

Exit status is `0` only when both documented size and SHA-256 match. The tool reads `docs/verification/reference-baseline.json`; it does not duplicate the B0 identity in code.

## VQ-1b: B0 execution bootstrap

The packaged Intel Linux executable remains the preferred B0 runner. In environments where its Intel runtime is unavailable, the provisional exact-source runner can compile the source archives contained in B0 with GNU Fortran:

```bash
python tools/vq/b0_source_runner.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/vq-b0 \
  --case 1.hupselbrook \
  --disable-csv
```

The GNU source build is capability-limited and is **not** a replacement oracle for the packaged Intel executable. In the tested GNU Fortran 14.2 environment, scalar CSV metadata initialize correctly but the legacy `SWAP_csv_output` vector metadata (`vars_v%name`) do not. Cases that request vector CSV output therefore remain unqualified on this provisional build.

`--disable-csv` is an explicit **runner-portability output workaround** (`SWCSV=1 -> 0`). It is not evidence of a B0 defect, is not a B1 correction and must never be applied silently. See `docs/verification/vq-1b-evidence.md` and `tools/vq/cases/b0-official-case-matrix.json`.

The runner accepts normal completion only when the legacy return code is `100`, `swap.ok` exists and `swap.err` is empty.

## Canonical legacy balance extraction

Convert `.BAL` and `.BLC` output to machine-readable values:

```bash
python tools/vq/balance.py \
  --bal /tmp/vq-b0/run/1.hupselbrook/result.bal \
  --blc /tmp/vq-b0/run/1.hupselbrook/result.blc
```

Check the package-published Hupselbrook 2002 smoke oracle:

```bash
python tools/vq/qualify_hupselbrook.py \
  --bal /tmp/vq-b0/run/1.hupselbrook/result.bal \
  --blc /tmp/vq-b0/run/1.hupselbrook/result.blc
```

The legacy reports expose water values at `0.01 cm` resolution. Passing this gate is regression and report-level accounting evidence, not the final hard SWAP5 mass-conservation gate.

## Official-case matrix

`tools/vq/cases/b0-official-case-matrix.json` records the current qualification scope for Hupselbrook, grass growth, macropore flow and salinity stress, including every explicit input/output-only variant and repeatability hash.

A `PASS` in that matrix applies only to the stated case/variant and runner capability. It must not be generalized to untested output paths or to full Intel/GNU equivalence.

## Unit tests

```bash
python -m unittest \
  tools.vq.test_reference_identity \
  tools.vq.test_balance \
  tools.vq.test_b0_source_runner
```

Future adapters for B1 and B2 must keep recording the exact executable/source identity, case identity and qualification scope used for each result.
