# DATAQUAL15 default-route preservation and final combined contract

Production source for the default regressions is `cf2bd2f2f62a464457f1b14a72b97d1aea2774fa`. The existing test drivers are unchanged. The production `src/` and `app/` trees in this worktree have no delta from that commit. The changed combined numerical policy is separately executed at exact source `18475bc`.

Completed with GNU gfortran13.3, O0 and O2, bounds/runtime checking, backtraces and invalid/zero/overflow traps:

- Existing unflagged thermal driver: every 2/4/8/16/32/64/128/256-window full/split/fresh-resume execution, exact endpoint files, rollback/retry/heat-off controls and five invalid-restart controls per optimization. O0/O2 results are identical. This preserves the existing bounded thermal contract; its original refinement-assessment/non-admission claim ceiling remains.
- Existing dynamic pond chemistry driver: wet/dry/fill execution, exact fresh-process restart, 15 malformed-state controls per optimization, fixed wet/dry predecessor driver preservation, and original surface-chemistry endpoint SHA256 `7927b66f0ccf253d00795dd6c174a8323ac6e06d5bd6d384248e9bb0e7331d9e`. O0/O2 identity passes.
- Existing Rutter source-window shell gate: O0/O2 identity passes.
- Seven existing native contracts: Black process, Black runtime, production bootstrap (WU01), common forcing (WU03), Rutter output binding, microscopic runtime (MICRO03), and root-hydrology equivalence (ROOT_HYD01). Every O0/O2 output is identical. They use their original fsi04 grid/legacy context and real HeadCalc. The source dependency graph is completed topologically, preserving the existing drivers; obsolete single-PR source-delta allowlists are not represented as admission gates.

The old pond runners initially rejected intentional exact `REAL==0` predicates at compile time. Commit `d18a342` adds only `-Wno-error=compare-reals` to their process-provider compilation, retaining all other warnings-as-errors, FPE traps and runtime checks. The dynamic runner then passed its complete existing gate, including its fixed pond predecessor driver. No physics, numerical tolerance, fixture, driver assertion, source-oracle line or expected endpoint changed.

## Changed combined policy at18475bc

The sole production-module delta from cf2bd2f is guarded by Black+Rutter+accepted-trace; the default contracts above do not select that conjunction. Optional diagnostic output is also guarded by its explicit environment switch. Default preservation is inherited only for these unselected branches, rather than described as an actual full rebuild of18475bc defaults.

The affected combined route was actually rebuilt and executed at exact18475bc. All283 thermal dependency source blobs were checked against Git; only the changed backend required compilation. Every inherited object hash is recorded. Relinking the complete original O0/O2 object sets independently reproduced both original executable hashes exactly; the new backend public module ABI is byte-identical. Existing driver/oracle/fixture sources are unchanged.

The existing combined Black/Rutter/numeric-heat/reactive-chemistry driver passes O0/O2 identity, exact full/split/fresh-resume endpoint files and13 malformed-state controls per optimization, including CRC-recomputed canopy/clock/source-window/micro-carry cases. It executes104 accepted substeps, with maximum chemical residual6.31927e-16 mg/cm2. Compilation took23.2175s, linking0.2763s, native execution0.1623s across both optimizations. This is component proof, not original historical project days or positive microscopic-carry/project equivalence qualification.

## Reproduction and claim limits

The evidence archive contains exact source hashes, existing runner outputs, compiler/link/native commands, generated literal oracles, binary endpoints, executables, the source-complete native executor and the verified single-backend rebuild executor. Default thermal and dynamic pond runners can be invoked directly with the recorded `FC` and fresh output directories. Native executions deliberately preserve the unchanged historical test context; historical PR-specific branch allowlists are not bypassed and then claimed as passed.

These results establish preservation and the bounded combined contract. They do not promote experimental options, qualify a complete historical project, establish full scientific equivalence, or prove canonical integration. The parent historical execution and canonical integration retain their separate evidence requirements.

Publication packaging preserves every source, compile/run record and physical output. Reproducible old default/diagnostic executable build artifacts are represented by their exact original hashes in `BUILD_ARTIFACT_OMISSIONS.json`; the current closed-union and clean-build capsules retain the original-history replay executables and TTUTIL. This changes archive packaging only, not the executed qualification or scientific claims.
