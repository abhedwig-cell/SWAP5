# F-CI06 Qualification — Controlled B1.10 Physical Source Port

## Outcome

**PASS_CONTROLLED_B1_10_SOURCE_PORT_WATER_CHECKPOINT_SUBSET**

F-CI06 qualifies a controlled four-file source port from the exact corrected B1.10 oracle. It does **not** qualify the complete SWAP physical transaction adapter.

## Exact source basis

B1.10 remains the physical oracle:

- 63 source members;
- 1,863,575 source bytes;
- manifest SHA-256 `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`.

The source port modifies exactly:

1. `headcalc.f90`
2. `soilwater.f90`
3. `swap.f90`
4. `swap_main.f90`

The remaining 59 B1.10 source files remain byte-identical. The exact stored-Git post-port 63-file source manifest is:

`3c4751ebb657a2bb622c9cddd718db451fbae861530353ab83fc3c99e78d7187`

The fail-closed applicator accepts only the exact four B1.10 preimages and verifies the exact stored postimages.

## Qualified behavior

### HeadCalc ownership seam

The new optional worker route moves a first numerical subset out of legacy singleton storage into worker-owned context: `dkdh`, warning/retry history and solver diagnostics/control used by the ported HeadCalc route. The no-worker route remains an explicit legacy compatibility path.

### Trial reporting seam

When a worker is present, legacy dynamic output and HeadCalc trial warnings are suppressed at the controlled seam. The normal standalone path, which does not pass a worker, retains legacy output behavior.

### Water checkpoint subset

`b1_10_water_state_t` captures/restores/clones the qualified soil-water subset (`h`, `theta`, previous-step water state, ponding, groundwater level, `volact`, `ldwet`, `spev`, `saev`). Forcing, numerical scratch, reporting state and accounting totals are deliberately excluded.

## Source-bound numerical preservation

The full exact B1.10 tree and the exact stored-Git F-CI06 postimage were compiled and linked with GNU Fortran. The port was tested under both `-O0` and `-O2`.

For the Hupsel 2002–2004 standalone route, with `SWCSV=0` solely to disable the CSV observer, exact B1.10 `-O0`, F-CI06 `-O0` and F-CI06 `-O2` produced identical normalized:

- `result.bal`: `47a52bcd463d0ec576b8b0fae8f4c53319c0e47c98ce698293808de9d1f0ffb3`
- `result.blc`: `2f6058f41a9691b8d70344d3f14c20b58ef4f2eea5f75f794417349e722f6617`
- `swap.wrn`: `fe99c100d7a37a09c63656dba8bd0ce2b95289850da329eb4a3e00f0d2b9108e`

Only generated run timestamp metadata is excluded from the textual comparison. This is focused preservation evidence, not the complete scientific B1.10 regression suite.

## CI evidence

Canonical workflow run `34084732886` completed the chained qualification successfully:

- F-CI03 transaction substrate — PASS
- F-CI04 canonical runtime — PASS
- F-CI05 B1.10 physical preimage — PASS
- F-CI06 controlled source-port/checkpoint — PASS

The F-CI06 job runs the fail-closed source/provenance gate and compiles/runs the real checkpoint module against the canonical transaction/runtime types at `-O0` and `-O2`. The checkpoint test captures state, deliberately corrupts the backing legacy variables, restores the checkpoint, verifies every qualified field, and verifies polymorphic clone behavior.

## Corrected qualification history

The first F-CI06 CI attempt failed correctly because three locally recorded postimage hashes did not exactly match the source as stored in Git. The mismatch consisted only of final-newline bytes and two non-executable comment/blank lines in `swap.f90`; it was not accepted by assertion. The stored Git postimage was reconstructed again from exact B1.10, compiled and rerun at `-O0`/`-O2`, and only those observed identities were then pinned. The subsequent canonical run passed.

An earlier exploratory compile also used B1.10-identical seam files while the other files were still B0. That run is superseded and contributes no admission evidence.

## Invariant assessment

F-CI06 advances explicit data/state ownership and worker scratch separation (invariants 3–5), transaction isolation prerequisites (7), MultiSWAP scalability prerequisites (16), clean hydraulic dependency direction (22), diagnostics (26) and pay-for-use state/scratch principles (27). It changes no physical formula or numerical policy (23) and introduces no mass-balance concession (13).

The current seam still does not satisfy the full kernel/no-I/O, generic-time, coupling, complete mass-interface or parallel-backend requirements. Those remain explicit holds rather than implicit assumptions.

## Remaining blockers

Before a complete physical transaction adapter may be admitted, at minimum the following still need controlled treatment:

- process continuation state beyond the water subset, including irrigation/crop and active optional modules;
- legacy `integral` and other module-global mutations during rejected trials;
- forcing ownership below the seam;
- generic non-calendar physical intervals;
- complete accepted unrounded interval mass totals;
- removal or containment of remaining backend serialization/global-state constraints;
- full B1.10-to-canonical reference qualification.

F-CI06 therefore closes the **source-port and first water-checkpoint layer**, not the whole physical transaction integration.
