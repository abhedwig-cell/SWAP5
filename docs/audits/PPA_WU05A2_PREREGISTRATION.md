# PPA-WU05-A2 preregistration — typed macropore state and rollback harness

Date: 2026-09-30

Status: `PREREGISTERED / IMPLEMENTATION_ALLOWED_WITHOUT_EQUATION_MIGRATION`

Baseline: `PPA-WU05-A1@93d6c78c7ea5fac7060c61d51f992e75c02c65c4`

## Purpose

Introduce explicit typed ownership for the source-proven macropore continuation state before any macropore rate/state equations are migrated into the SWAP5 production route.

A2 is an architecture/state work unit. It must not change the physical macropore equations, activate macropores in production, or claim numerical equivalence of an active typed macropore solve.

## A1 authority inherited

The exact B1.11 source census qualified seven physical/history continuation fields:

- `ICpBtDm`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `VlMpDmCp`;
- `WaUnMpDmCp`;
- `VlMpDyCp`.

Legacy previous-step mirrors are transaction bookkeeping rather than independent state:

- `ICpBtDmM1`;
- `VlMpDmCpM1`;
- `WaUnMpDmCpM1`.

Derived geometry/runtime views must be recomputed and must not leak rejected-trial values.

A1 also proved the B1.11 `icgwl` undefined-index defect. A2 does not repair or migrate that equation path.

## Target ownership

A2 shall define a typed optional macropore state with:

1. accepted/committed continuation state;
2. candidate state created from the accepted checkpoint;
3. atomic accept/reject semantics;
4. restart serialization over physical/history fields only;
5. no worker/rate scratch in restart;
6. shape based on active `num_domains` and `num_nodes`, not legacy maxima.

The preferred representation is structurally equivalent to:

```text
MacroporeState
  icp_bottom_domain(:)
  sorptivity(:,:)
  theta_sorption_ref(:,:)
  absorption_time(:,:)
  volume_domain_cp(:,:)
  water_domain_cp(:,:)
  dynamic_volume_cp(:)
```

Field names may follow SWAP5 conventions but the seven-field semantic surface is fixed by A1 unless implementation evidence shows a strictly equivalent decomposition.

## Required gates

### A2-G1 type and shape
Active-sized allocation, zero/default initialization, copy and equality helpers.

### A2-G2 candidate isolation
Mutating a candidate may not change accepted state.

### A2-G3 reject
Reject/discard leaves the accepted checkpoint byte/observable-identical.

### A2-G4 accept
Accept atomically publishes all seven continuation fields.

### A2-G5 retry
A new candidate after rejection starts from the same accepted checkpoint and contains no rejected history.

### A2-G6 restart
Round-trip serialization reconstructs all seven fields exactly and excludes derived views and scratch.

### A2-G7 inactive option preservation
With macropores inactive, all existing qualified SWAP5 behavior remains unchanged.

## Hard holds

- no active macropore physics route;
- no equation migration;
- no mass-tolerance relaxation;
- no preservation of undefined `icgwl` behavior as science;
- no parallel/macropore claim;
- no hidden module-global continuation state added.

## Exit

A2 may close as a qualified architecture/state candidate when the typed state, candidate/rollback harness and restart round trip pass. Active physical execution remains A3.
