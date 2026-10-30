# Original Hupsel clean-build reproduction

The existing builder accepts an empty output directory with no `--reuse`. It
compiles the complete transitive production graph from source; no modules or
objects from a previous build are copied. `--ttutil-archive` supplies the
original external TTUTIL library explicitly. Supplying `--reuse` retains the
previous compiler/optimization/object-hash checks and verified incremental
behavior. The historical default TTUTIL path remains available for existing
commands.

The measured clean build uses commit `3625ce6` (physical source `ad51bc8`),
gfortran 13.3.0, O2, runtime checks and invalid/zero/overflow traps. All 235
provider source hashes, semantic compiler flags and TTUTIL library hash match
the independently built incremental r executable. All 235 provider objects
were compiled into the new output directory; the verified-reuse control
rebuilt 0 providers. Clean compilation/linking took 152.58 seconds.

```sh
python tests/dataqual15_hupsel/build_and_run.py \
  --output /absolute/path/clean-build \
  --compiler /absolute/path/gfortran-13 \
  --optimization O2 \
  --ttutil-archive /absolute/path/libttutil.a

python tests/dataqual15_hupsel/run.py \
  --rotation --bundle /absolute/path/clean-build \
  --output /absolute/path/original-tail \
  --prepare-days 1096 --end 1096 \
  --restart /absolute/path/actual-checkpoint-1058.bin
```

`CLEAN_BUILD_EVIDENCE.tar.xz` contains the original TTUTIL archive, both build
records, compiler events, the actual input checkpoint, unchanged original
inputs, both executables and both tail outputs. TTUTIL SHA256:
`915498e7bb27a2bb2767669d8d26b4f2b5f235a3e0f14b03ce4fe70628fd92ba`.
Its source authority is the repository's immutable original
`SWAP431_TTUTIL_AUTHORITY.zip.b64` (decoded zip SHA256
`ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`).

The actual 38-day 1058→1096 clean-build run returns 0. Budget, crop,
germination, final state, soil temperature, endpoint and both complete native
checkpoint/restart files are byte-identical to the incremental r tail.
The initial checkpoint was produced by the full original q run from day 1;
this proves clean-build equivalence on the identical actual state. It does
not independently certify an uninterrupted r run from day 1 or full
scientific equivalence. Those claims require the separate final original
project qualification.

The first tail launch failed before model execution because the environment
had removed executable permission. The ELF SHA256 still matched BUILD.json;
after restoring execute permission, a fresh output directory produced the
successful run. The failed preparation artifacts remain recorded separately.
