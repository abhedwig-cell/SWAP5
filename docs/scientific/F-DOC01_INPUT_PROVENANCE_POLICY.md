# F-DOC01 input provenance policy

Input provenance is a typed chain from observation/source to kernel-facing data. It does not make legacy file formats part of the kernel.

## Required chain

`real-world/raw data → preprocessing/transformation → adapter → parameter/forcing object → kernel/process variable`.

Each edge records source/version, units, coordinate/reference system where relevant, temporal support/aggregation, interpolation, missing-data handling, transformations, precision, uncertainty, preparation script/tool version and responsible authority.

## Separation of concerns

Legacy `.swp` files and parsers belong to adapters and user/legacy documentation. Scientific theory documents the physical quantity and its interpretation. The kernel contract sees typed parameter/forcing/state objects, never path, file-unit or parser semantics.

## Reproducibility

Preparation scripts are versioned and tested when they are part of a qualified data path. Derived forcing or parameter data should identify the raw-data authority and transformation version. Unknown preprocessing is a provenance gap, not a generic `input data` source.

## Output provenance

Release-facing outputs should be able to identify model version/source authority, relevant input/parameter set identity and numerical policy/diagnostics needed for interpretation. AA-specific execution/input echo requirements remain subject to WR-QA-2024 reconciliation.
