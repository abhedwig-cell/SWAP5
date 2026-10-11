# Core architecture invariants

## Status

These invariants are normative for the new SWAP architecture. An architecture or solver change that conflicts with them requires an explicit design decision and review. Performance is not a valid reason to silently violate physical correctness or mass conservation.

## Invariants

1. **One computational kernel.** The same SWAP kernel supports standalone SWAP, MultiSWAP, Waterwijzer-like applications and coupling to systems such as MODFLOW. No separate SWAP implementation is maintained per use case.

2. **Kernel independent of I/O.** The kernel knows nothing about files, formats, parsing, file units or paths. Legacy input and output remain available through adapters or translation layers outside the kernel. I/O modernization is not the first architectural priority.

3. **Explicit data separation.** Parameters, dynamic state, forcing, numerical configuration and results are separate data categories and are not unnecessarily mixed.

4. **Compact persistent state.** Each column stores only what is required to continue the physical state. Inactive options have no state. Immutable soil, crop and other parameter data are shared through IDs or references where practical.

5. **Scratch per worker.** Newton vectors, Jacobians, constitutive intermediates and other temporary solver data belong to workers or compute jobs, not permanently to every column.

6. **Scalable memory layout.** The logical API may be object-oriented while internal storage may use structures of arrays, pools or batches. Columns may be grouped by similar physics and solver paths for cache efficiency, vectorization and parallelism.

7. **Transactional time steps.** Every calculation supports checkpoint, trial or retry, and commit or rollback. Rejected trials never modify committed state.

8. **Cheap reruns and warm start.** The same initial state can be recomputed efficiently with changed boundary conditions. Trial trajectories may be reused as numerical initial guesses, but a corrector always starts physically from the correct committed state.

9. **Generic time.** Day, month and year are not fundamental computational units. The kernel computes over `[t0, t1]`. Solver steps, forcing intervals, coupling windows, events and reporting have their own time scales. Calendar boundaries are respected only when a process requires them.

10. **Flexible coupling windows.** Predictor-corrector coupling with MODFLOW operates over a generic coupling window `DeltaT`, not a hard-coded midnight-to-midnight day. Adaptive larger or smaller windows must remain possible.

11. **Coupling is core functionality.** Predictor-corrector operation, rollback, shared states, interface residuals, flux conservation and response tangents are considered from the beginning in kernel, runtime and API design.

12. **Explicit groundwater interface contract.** For direct SWAP-MODFLOW coupling the target is `H_SWAP = H_MF` and `q_SWAP = -q_MF`. Small head residuals may exist within a qualified tolerance; water may not disappear.

13. **Mass conservation is absolute.** Standalone, coupled, fallback and performance-optimized paths must maintain a closed water balance. Mass conservation is never an adjustable concession.

14. **Interface sensitivities are first-class output.** The solver can efficiently provide sensitivities such as `dh_b/dq_b`, preferably from the same Jacobian or factorization. Positive and negative flux perturbation runs remain useful as a reference or fallback, not as a required production path.

15. **Limit coupling cost.** The normal production path must not structurally require six to nine full SWAP runs per coupling window. The design target is approximately predictor plus corrector, with extra work only where nonlinearity requires it.

16. **MultiSWAP is a primary use case.** Hundreds of thousands of logical columns can be managed, batched and executed in parallel without the same number of heavyweight solver instances. Standalone operation remains fully supported.

17. **No mandatory one-to-one MODFLOW mapping.** One MODFLOW cell may contain multiple surface fractions or tiles whose fractions sum to one, for example unpaved, semi-paved, paved and open water. Only tiles requiring full soil-plant-atmosphere physics use SWAP. Runtime or coupler aggregates fluxes by area fraction.

18. **Deep vadose is an optional separate component.** If groundwater is far below the SWAP column, `q_SWAP,bot` need not be interpreted directly as deep groundwater recharge. A light mass-conserving transfer zone may be used, preferably with minimal state and simple parameterization, for example `dS/dt = q_SWAP,bot - q_gw` and `q_gw = S/tau`. This component remains outside SWAP.

19. **Mass-conserving component transitions.** Switching between deep-vadose transfer and direct coupling must not lose stored water or count it twice.

20. **Keep alternative soil-water solvers open.** The architecture is not hard-coupled to one Richards implementation. Full Richards, coarse Richards and qualified reduced-order approaches can operate behind a common soil-water interface.

21. **Reuse SWAP physics as much as possible.** Alternative soil-water solvers share crop, ET, drainage, irrigation and surface processes where possible. Reuse functional physics, not legacy global variables, module boundaries or data structures.

22. **Other modules do not depend on HeadCalc internals.** Other SWAP modules request hydraulic information through a clean interface and do not know the internal arrays or numerical implementation of the soil-water solver.

23. **Separate physical options from solver policy.** Macropores, drainage, crop options and similar choices are physical configuration. Reference, balanced and throughput modes are numerical policies. A performance policy must not silently change the physics.

24. **Predictable computational cost.** Difficult columns such as heavy-clay or B12 cases must not delay a large MultiSWAP batch without bound. Bounded-cost solving and a qualified fallback ladder are allowed if mass conservation remains hard and deviations from reference mode are bounded and diagnosable.

25. **Reference mode remains available.** A full-accuracy reference mode always exists. New physics, solvers, reduced-order variants and performance optimizations are qualified against it first.

26. **Diagnostics are part of the runtime.** For each column and interval it must be possible to determine whether normal, relaxed or fallback execution was used, including retries, solver cost and water-balance diagnostics.

27. **Optional functionality scales with use.** Modules such as macropores, deep vadose, special drainage or heavier crop physics consume memory and computation only for columns where they are active.

28. **Runtime and coupler organize system composition.** SWAP does not know what fraction of a MODFLOW cell its tile occupies or whether its lower flux passes through a transfer zone. Those relationships belong outside the kernel.

29. **No silent dependencies.** New kernel code does not implicitly assume that a run starts at midnight, lasts one day, comes from a `.swp` file or is directly connected to MODFLOW.

30. **Review every architecture change.** Each important solver, API, state, runtime, MultiSWAP, coupling or module-design change is explicitly checked against these invariants.

## Review rule

Architecture work should state which invariants it touches. A useful review record contains:

```text
Affected invariants: 3, 5, 7, 13
Expected effect: compliant / strengthens / requires qualification
Evidence: tests, benchmark, balance closure, API review
Open risk: ...
```
