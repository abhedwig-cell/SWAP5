# Paper 1 evidence register

## Purpose

This is a publication-facing inventory of existing SWAP5 evidence relevant to Paper 1. It does not replace authoritative qualification records. It classifies what already exists, what can plausibly be reused, and what still needs publication-grade consolidation or new testing.

Publication class: `PUB_P1_RESULT` unless marked otherwise.

## Current assessment

Paper 1 has a strong architectural and governance trace, but it does not yet have one consolidated publication dataset that demonstrates behaviour preservation across the migration with common metrics.

The main risk is not lack of engineering evidence. The main risk is that the evidence is distributed across many workunits with different local purposes, baselines and qualification scopes.

The manuscript should therefore reuse immutable evidence where valid, but assemble a new publication-level index and aggregate only claims that are actually comparable.

## Existing evidence classes

### 1. Qualified reference chain

Status: strong existing evidence.

The verification framework defines an explicit reference chain from immutable audit baseline through corrected legacy reference to SWAP5 reference mode. The VQ record also requires unexplained differences to fail and separates rounded legacy balance outputs from the hard unrounded mass-accounting contract.

Publication relevance:

- supports the claim that migration was not evaluated against an informal or moving visual reference;
- provides provenance for the scientific reference behaviour;
- supports a methods section on reference identity and admitted legacy corrections.

Limitations:

- historical runner/toolchain limitations must remain visible;
- the corrected-reference oracle is not equivalent to claiming exhaustive coverage of all legacy options;
- legacy BAL/BLC precision cannot be presented as machine-precision mass evidence.

Primary sources:

- `docs/verification/vq-1-integration.md`
- `docs/verification/reference-baselines.md`
- `docs/verification/legacy-differences.md`
- `docs/verification/mass-accounting-contract.md`

### 2. Explicit transaction and generic-time contract

Status: strong contract evidence, publication execution evidence must be selected carefully.

The canonical VQ qualification vocabulary includes:

- `TX-ROLLBACK-01`
- `TX-COMMIT-01`
- `TX-ACCOUNT-01`
- `TX-RERUN-01`
- `TX-BC-REPLAY-01`
- `TX-WARM-01`
- `TIME-00`
- `TIME-06`
- `TIME-18`
- `TIME-36`
- `TIME-SPLIT`

This is directly aligned with the Paper 1 hypothesis on authoritative physical state and trial semantics.

Publication relevance:

- supplies predeclared semantic properties rather than post-hoc descriptions;
- enables directed failure/retry experiments;
- distinguishes generic interval execution from legacy day-control assumptions.

Limitations:

- older VQ workunits contain synthetic or verifier-harness qualification and must not be misrepresented as production-physics evidence;
- publication use must identify the exact later workunit and commit at which each property was exercised against admitted production execution.

Primary sources:

- `docs/verification/vq-1-integration.md`
- historical VQ PRs including #45, #47 and #55 for the evolution of the harness and fail-closed production admission boundary.

### 3. Explicit kernel and ownership seam

Status: strong architectural evidence.

The kernel seam and architecture documentation establish separate ownership for committed state, forcing, numerical configuration, worker scratch and trial results. Commit/rollback remains outside the trial computation.

Publication relevance:

- supports H2 and H3;
- provides a concrete example of how authoritative physical state is kept distinct from solver scratch and provisional output;
- helps explain why an alternative solver can later be inserted without owning the application lifecycle.

Limitations:

- early seam contracts were deliberately non-physical scaffolding;
- the paper must cite the eventual production implementation, not treat the first abstract seam as proof that migration succeeded.

Primary sources:

- `docs/architecture/data-ownership.md`
- `docs/architecture/invariants.md`
- `docs/architecture/migration-slices.md`
- PR #57 as historical evidence of the initial production-facing seam contract.

### 4. Migration gates and retained legacy path

Status: strong process evidence.

The migration-slice contract requires reference-path preservation, explicit state ownership, closed water balance for accepted paths, visibility of retry/fallback routes and retirement of legacy paths only after replacement qualification.

Publication relevance:

- candidate core of the transferable migration method;
- supports the distinction between a software milestone and a scientific admission gate.

Limitations:

- the manuscript must not simply reproduce M0-M8 as a project chronology;
- the publication needs a reduced generic method and quantitative evidence showing that the gates actually constrained migration decisions.

Primary source:

- `docs/architecture/migration-slices.md`

### 5. Successor capability using the same lifecycle

Status: strong existing architectural probe, `PUB_SHARED_INFRASTRUCTURE` for Paper 2.

F-ROSS12 demonstrates production selection of RossFast at the existing `soil_water_solver_t` request/result seam without changing the transaction ABI, legacy input grammar or Reference physics. It uses the same production transaction and can fail closed before commit.

Publication relevance for P1:

- direct evidence that the solver boundary is not merely diagrammatic;
- demonstrates that a materially different soil-water solver can be inserted without creating a second application runtime;
- supports H3 on separability of numerical implementation and surrounding lifecycle.

Hard firewall:

P1 may use only the fact of architectural substitution and preservation of the common lifecycle. RossFast accuracy, speed, regime dependence and admissibility remain P2 results.

Primary source:

- `integration/f-ross/F-ROSS12_STATUS.json`
- PR #165 and its post-admission governance reconciliation.

### 6. Fail-closed qualification discipline

Status: abundant existing evidence, needs selective publication use.

Many SWAP5 workunits deliberately end in blocked or qualified-limited states rather than weakening gates. Examples include VQ production-admission workunits and performance-host qualification.

Publication relevance:

- potentially useful evidence that the migration method constrains claims rather than simply documenting successful changes;
- possible source for one or two concrete examples in which an attractive claim was withheld because the evidence boundary was not met.

Limitations:

- do not turn the paper into a catalogue of repository governance events;
- select only scientifically relevant examples where fail-closed behavior protected model semantics or prevented an unsupported conclusion.

## Evidence still missing or not yet consolidated

### A. Common publication qualification set

Need one declared set of representative cases that can be followed across selected major migration boundaries.

The set should cover contrasting conditions and major process families without pretending to be exhaustive.

Required metadata:

- input identity;
- reference version;
- migration state/commit;
- state variables compared;
- integrated fluxes compared;
- water-balance metric;
- tolerances;
- reason for case inclusion.

### B. Cross-migration quantitative preservation matrix

Need a table or dataset that answers a simple reviewer question:

> Across the major architectural changes, how much did scientifically relevant behaviour actually change?

Candidate columns:

```text
migration_boundary
case_id
max_state_deviation
integrated_top_flux_deviation
integrated_bottom_flux_deviation
storage_deviation
water_balance_residual
expected_difference_class
verdict
```

This should not be reconstructed from incompatible historical outputs without checking comparability.

### C. Production transaction fault-injection publication bundle

Need exact current production evidence for the six TX properties and generic-time cases selected for the paper.

Older synthetic harness evidence can document method development but is insufficient as the primary empirical result.

### D. Gate-value examples

Select a small number of migration incidents where a gate found or prevented a real semantic problem. Good examples would involve:

- hidden state mutation;
- double-counted accounting;
- incorrect sign/unit translation;
- stale authority after an intentional production successor;
- an unsupported process route correctly failing before commit.

The purpose is to show why the method matters, not to dramatize normal software bugs.

### E. Transferability statement

Need an explicit boundary analysis identifying which parts of the method are likely general to stateful time-stepped scientific models and which remain SWAP-specific.

Candidate transferable elements:

- executable reference shield;
- authoritative-state ownership;
- trial/commit distinction;
- explicit scientific invariants;
- qualification before retirement;
- immutable evidence identity.

Candidate SWAP-specific elements:

- exact hydrological process families;
- SWAP legacy I/O grammar;
- particular corrected-reference defects;
- specific RossFast envelope;
- exact MultiSWAP and MODFLOW composition.

## Publication-readiness verdict

Current verdict: `PROMISING_NOT_MANUSCRIPT_READY`.

Reason:

The architecture, reference discipline and multiple independent qualification traces are already substantial. The missing step is not another broad redesign. It is a bounded publication-evidence consolidation plus targeted production fault-injection where current evidence is synthetic, fragmented or not directly comparable.

## Next publication workunit

Suggested identifier: `PUB-P1E01`.

Scope:

1. freeze a representative publication qualification set;
2. identify exact existing canonical artifacts for each required metric;
3. classify evidence as reusable, incomparable or missing;
4. define only the minimum new executions required to close gaps;
5. produce a machine-readable preservation matrix without changing production physics.

Do not start manuscript prose before this matrix has a defensible evidence basis.
