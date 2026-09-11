# F-TB08 External Accuracy Runtime Adapter Testbank Adoption

F-TB08 permanently adopts the restricted external application-accuracy runtime adapter boundary qualified by F-GC14 and admitted by F-CI46/F-CI46P. The moving canonical preservation authority was reconciled by F-CI47 before this workunit started.

## Scope

The bank preserves eight properties: typed groundwater-head mapping, typed groundwater-drawdown mapping, mandatory upstream packet-validation attestation, mandatory application and temporal source-verification attestations, provenance separation/reuse rejection, canonical application/temporal validation with fail-closed default output, repeat/O0/O2 determinism, and the explicit adapter nonclaims.

The executable oracle is the immutable F-GC14 Fortran test blob. F-TB08 extracts that test from the exact F-GC14 authority and compiles it against the current canonical adapter and application-accuracy contract. F-TB08 does not copy or reinterpret the scientific/governance oracle.

## Hard boundaries

F-TB08 does not choose a numerical `H_app` or `A_temporal`, does not verify external source bytes or compute source digests, does not parse JSON or files, does not select project policy, does not admit production SWAP-MODFLOW coupling, and does not relax mass conservation.

The adapter is a runtime/coupler transport boundary. External evidence verification and system composition remain outside the kernel.

## Testbank composition

The composition base keeps the current canonical `src`, `reference`, F-CI governance and tests. It adds only the byte-identical F-TB07 `testbank/`, `docs/testbank/`, `integration/f-tb/` support and F-TB01 through F-TB07 workflows. F-TB08 then adds only its own manifest, runners, evidence, documentation and workflow.

## Profiles

`FAST` validates provenance, immutable inherited support, exact canonical source/reference, adapter/contract blobs, case identity and static boundary constraints.

`CANONICAL` additionally compiles and runs the immutable F-GC14 adapter oracle against current canonical source at `-O0`.

`RELEASE` additionally repeats `-O0`, runs `-O2`, requires transcript bit identity, and verifies a support-only workunit delta.

`DEEP` uses the same qualified evidence set and makes no broader project-specific or production-coupling claim.
