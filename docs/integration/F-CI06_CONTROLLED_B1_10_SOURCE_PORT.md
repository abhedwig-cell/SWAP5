# F-CI06 — Controlled B1.10 Physical Source Port

## Decision

F-CI06 admits a **controlled source-port seam** from the exact corrected B1.10 oracle. It does not admit a complete physical transaction adapter.

The port starts from B1.10 source manifest:

`2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

Only four legacy production source files are changed:

- `headcalc.f90`
- `soilwater.f90`
- `swap.f90`
- `swap_main.f90`

All other 59 B1.10 source members remain byte-identical to the corrected oracle.

## Source-port responsibilities

### 1. Worker-owned HeadCalc numerical history/scratch

The port introduces an optional worker execution context through `SWAP -> SoilWater -> HeadCalc`.

When a worker is present, HeadCalc uses worker-owned:

- `dkdh` constitutive/Jacobian scratch;
- nonlinear/Jacobian/linear-solve/backtracking counters;
- warning history (`flwarn`, `iwarn`);
- macropore retry history (`nstep`);
- timestep-reduction request diagnostics.

The no-worker route uses one explicit legacy compatibility context. This preserves standalone semantics while making the new ownership boundary explicit. The compatibility context is not a MultiSWAP scalability solution and remains a migration hold.

### 2. Trial output suppression

When the optional worker is present, the dynamic physical trial route does not emit legacy SWAP/soil-water/macropore output. Solver warnings caused by a trial are likewise suppressed at the HeadCalc seam.

The no-worker standalone route retains the legacy output path.

This is required so a rejected trial cannot produce externally visible reporting side effects.

### 3. First explicit water-state checkpoint subset

`src/adapter/mod_b1_10_water_checkpoint.f90` introduces a canonical-state-derived checkpoint type for the currently qualified soil-water subset:

- `h`, `theta`;
- `hm1`, `thetm1`;
- `pond`, `pondm1`;
- `gwl`, `gwlm1`;
- `volact`;
- `ldwet`, `spev`, `saev`.

It supports capture, restore and clone. It deliberately excludes forcing cursors, calendar/reporting state, accounting totals and numerical scratch.

This is **not** yet the complete physical continuation state for SWAP. Crop, irrigation, solute, heat, macropore and other active-process continuation state still require explicit qualification before the physical adapter can be admitted transactionally.

## Reproducible materialization

`tools/fci/fci06_apply_controlled_source_port.py` fails closed unless the four input files have their exact B1.10 preimage hashes. It then writes the materialized F-CI06 postimages with deterministic legacy CRLF bytes and checks their postimage hashes.

The repository stores complete postimages for `headcalc.f90`, `soilwater.f90` and `swap_main.f90`. `swap.f90` is stored as four ordered include chunks only to keep individual repository writes bounded; the applicator concatenates them to the exact full postimage before qualification/use.

The byte identity admitted by F-CI06 is the source **as actually stored in Git**. The first CI execution detected that three locally pinned postimages differed from the stored form only by final-newline bytes and two non-executable comment/blank lines in `swap.f90`. The gate correctly failed. The stored Git form was then reconstructed again from exact B1.10 and rerun before its hashes were admitted.

## Qualification

The exact local B1.10 reconstruction has:

- 63 source files;
- 1,863,575 source bytes;
- manifest SHA-256 `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`.

The controlled port changes exactly four files. The resulting exact stored-Git 63-file source tree has:

- 1,866,170 source bytes;
- manifest SHA-256 `3c4751ebb657a2bb622c9cddd718db451fbae861530353ab83fc3c99e78d7187`.

Full GNU compilation/link was performed for:

- exact B1.10 preimage at `-O0`;
- exact stored-Git F-CI06 postimage at `-O0`;
- exact stored-Git F-CI06 postimage at `-O2`.

All passed.

For the Hupsel 2002–2004 standalone route (`worker` absent), B1.10 `-O0`, stored-Git F-CI06 `-O0` and stored-Git F-CI06 `-O2` produced identical normalized `.bal`, `.blc` and warning outputs. Only generated run-time metadata is excluded from the textual comparison. This is a focused preservation result, not yet the full B1.10 scientific regression suite.

CI additionally executes the static source/provenance gate and an `-O0`/`-O2` capture/restore/clone test for the water checkpoint type.

## Explicit holds

F-CI06 does not claim any of the following:

- complete SWAP physical continuation state;
- rejected full physical trials are already rollback-safe across every legacy process module;
- forcing ownership is removed from legacy globals;
- generic sub-day physical execution is qualified;
- accepted unrounded interval mass totals are exposed canonically;
- the legacy backend is parallel/reentrant;
- B1.10-to-SWAP5 full reference qualification is complete.

In particular, `integral`, crop/irrigation/process continuation and other module-global mutations must be captured or removed from trial-global state before full physical transaction admission.

## Invariant review

F-CI06 advances invariants 3, 4, 5, 7, 16, 22, 26 and 27 by making the first physical-state and worker-scratch ownership seams explicit. It preserves invariant 23 because no physics option or solver policy is changed. It preserves invariant 13 by making no mass-conservation relaxation and by refusing to claim complete accounting before accepted unrounded totals exist.

The legacy compatibility path remains intentionally outside the final kernel architecture and therefore does not close invariants 1, 2, 9, 10, 11, 12, 14–17 or 28–29.

## Admission

F-CI06 admission is:

`CONTROLLED_SOURCE_PORT_SEAM + QUALIFIED_WATER_CHECKPOINT_SUBSET`

The next unit must expand transactional physical state/process ownership rather than wrapping the remaining module globals inside a larger persistent column object.
