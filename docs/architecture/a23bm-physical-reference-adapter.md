# A23BM physical reference bridge contract

## Scope

A23BM connects the canonical A23BL transaction controller to the qualified SWAP 4.3.1 B1.6 physical reference through an external VQ adapter. It is a qualification bridge, not the target SWAP5 production physics adapter.

## Ownership boundary

The A23BL transaction core remains independent of files, paths, parsing, process execution and SWAP 4.3.1 global variables. The A23BM adapter owns all legacy restart files, case materialization, process execution and diagnostic parsing.

A transaction state contains an immutable reference to a complete binary legacy restart state plus cached physical diagnostics needed by the transaction interface. Trial clones receive their own logical state object. A rejected trial is never authoritative.

## Physical state identity

For this bridge, a binary SWAP `SWENDTYPE=2` restart file is treated as the complete legacy continuation-state oracle for the Hupselbrook fixture. The restart representation was qualified by split-run identity: continuation from a binary restart yields the same final restart bytes as an uninterrupted B1.6 run over the same physical trajectory.

Temporal equality in A23BM is deliberately conservative and VQ-specific: full and two-half candidates have zero temporal error only when their final binary restart SHA-256 values are identical. This is not the future production temporal-error estimator.

## Mass contract

B1.6 Hupsel daily CSV diagnostics provide initial storage, final storage, physical flux decomposition and `BALDEV`. The adapter maps the reported net balance exactly onto the generic A23BL `mass_in`/`mass_out` interface, while retaining the physical input/output flux decomposition separately for verification.

The A23BL hard mass gate uses the B1.6 qualification tolerance of `1e-6 cm`. A candidate outside the tolerance cannot be committed.

## Time limitation

A23BM intentionally supports integer-day Hupsel VQ windows only because it uses legacy case restart execution. This restriction belongs to the adapter and must not become a kernel-time invariant.

## Forcing slicing

The Hupsel fixture contains a fixed irrigation event on 2002-01-05. For a segmented legacy run whose interval does not include that event, the adapter disables the fixed-irrigation table to satisfy legacy input validation. When the interval includes 2002-01-05, the original event is retained. This is an external forcing-window projection, not a change to event magnitude or process physics.

## Output seam

The VQ execution requests binary restart output and a reduced CSV diagnostic list. Observer-on versus observer-off B1.6 execution was checked to produce the identical final binary restart state. Therefore these output changes are measurement-only for the qualified fixture.

## Explicit exclusions

A23BM does not prove:

- a native in-memory SWAP5 physical adapter;
- sub-day legacy execution through this bridge;
- natural HeadCalc/Newton retry capture;
- exposure of per-Newton iteration counts;
- B12 difficult-column behaviour;
- selective step-doubling production accuracy;
- MultiSWAP production throughput.
