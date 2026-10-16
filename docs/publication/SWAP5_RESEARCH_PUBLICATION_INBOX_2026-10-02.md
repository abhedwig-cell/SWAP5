# SWAP5 research and publication INBOX

Date: 2026-10-02

Purpose: freeze research questions emerging during the SWAP5 migration and qualification work so they are not lost. An INBOX item is **not** a publication claim, work-unit admission, or assertion of novelty. Items become active research only after explicit literature due diligence, formulation of falsifiable hypotheses, and prioritisation after the current migration programme.

## INBOX-PUB-01 — Error-bounded adaptive numerics at application scale
Can hydrologically interpretable local error/defect indicators be used to spend numerical work selectively while retaining explicit bounds on scientifically relevant hydrological error and exact hard-mass accounting?

Origin: ELASTIC59–71, moving-interface work, MultiSWAP population tests and performance-objective closeout.

Links: performance; NUM-UNC; DIFFICULTY.

Need to establish: generality across soils/regimes; relation between local indicators and application-level observables; whether speed/error trade-offs remain predictable at population and coupled-model scale.

## INBOX-PUB-02 — Prospective prediction of nonlinear difficulty
Which physical states, forcing transitions and boundary-condition changes predict nonlinear solve difficulty before a Richards solve is attempted?

Origin: PZG23 causal falsification, timestep/controller work, dry/wet transitions, moving-interface and top-boundary failures.

Links: DIFFICULTY.

Need to establish: predictors that are physical rather than solver-specific; prospective out-of-sample skill; portability across soil types and boundary regimes.

## INBOX-PUB-03 — Numerical choices as scientific uncertainty
Under which hydrological regimes can admissible numerical approximations, tolerances, timestep policies or reduced/approximate constitutive treatments alter scientific conclusions rather than merely numerical detail?

Origin: ELASTIC error envelopes, approximate RFM work, TIMEINT/NLGLOB, top-boundary and nonlinear qualification.

Links: NUM-UNC.

Need to establish: scientific endpoints; uncertainty decomposition relative to forcing/parameter/structural uncertainty; transition regimes where conclusions become numerically contingent.

## INBOX-PUB-04 — Minimum information for accelerated process representation
What is the minimum state/response information needed to accelerate repeated vadose-zone calculations without losing the hydrological responses relevant to a specified coupling or application purpose?

Origin: ROM purpose work, response-surrogate work, lookup/interpolation work, approximate RFM and application-scale performance objective.

Links: ROM/PUB-RC/ACCELERATE.

Need to establish: purpose-specific state sufficiency; failure modes; whether no universal low-dimensional state is itself a generalisable result.

## INBOX-PUB-05 — Coupling semantics and ownership
Which state, flux, storage and acceptance semantics are required for conservative, non-duplicative coupling between vadose-zone, groundwater and surface-water models with different timesteps and ownership boundaries?

Origin: SWAP5–MODFLOW6 fixed-interface reconciliation, predictor/corrector work, Ribasim integration, TOP02/TOP03 transactional surface exchange and the finding that prescribed groundwater head is not the generic SWAP–MODFLOW coupling contract.

Links: PUB-GC/COUPLE.

Need to establish: general coupling contract; temporal exchange semantics; rollback/restart; conservation; comparison with established coupling frameworks. Hupsel evidence must not be overinterpreted before coupling semantics are corrected.

## INBOX-PUB-06 — Dynamic land-surface boundary transition
Can the rainfall–infiltration–ponding–runoff transition be formulated as a physically continuous/transactional surface-exchange problem that is more robust than abrupt boundary-condition switching while preserving mass and state ownership?

Origin: TOP03, repeated dry/wet and stopping-threshold failures, distributed contact-layer experiments and discussion of a gradual matrix-to-air/surface transition.

Links: coupling; numerical difficulty; possibly standalone surface-boundary paper.

Need to establish: physical formulation versus numerical regularisation; identifiability of added parameters; field-scale relevance; comparison with complementarity/atmospheric-boundary formulations.

## INBOX-PUB-07 — Preferential-flow representation across macropore geometries
Which preferential-flow state and transfer mechanisms are actually required to represent surface-connected, covered and perched macropore systems, and where can the representation be simplified for large-scale applications?

Origin: A8–A26 RFM/FMR reconstruction, PERCH20/21, MIGMAC01 covering-layer route and current Flevoland subsurface-macropore question.

Links: possible new preferential-flow paper.

Need to establish: distinction between migration/software reconstruction and hydrological novelty; observational constraints; whether subsurface-starting macropores require a materially different conceptual model.

## INBOX-PUB-08 — Approximate preferential-flow physics and performance
Can an explicit approximate RFM mode, including approximate sorptivity, achieve a reproducible application-level speed gain with bounded errors in infiltration partitioning, drainage, storage and groundwater response?

Origin: A27/A28 PERF07 approximate sorptivity programme.

Links: performance; NUM-UNC; preferential flow.

Need to establish: broad soil/event panel; long trajectories; coupled MultiSWAP–MODFLOW effects; conditions under which approximation fails. Do not equate constitutive benchmark speed with production speed.

## INBOX-PUB-09 — Physically safe computational skipping
Can expensive process calculations be skipped prospectively using sufficient physical eligibility conditions, without changing process response when the skipped mechanism is inactive?

Origin: Bartholomeus oxygen PERF01/PERF02 eligibility-gate work and broader zero-waste programme.

Links: performance; DIFFICULTY.

Need to establish: frequency in realistic applications; generality beyond oxygen stress; proof/falsification strategy for fail-closed gates; end-to-end performance benefit.

## INBOX-PUB-10 — Theory–documentation–code–evidence discrepancies
Which scientifically consequential discrepancies become visible when theory, documentation, legacy implementation and executable evidence are reconciled prospectively during migration of mature environmental models?

Origin: repeated SWAP4.3.1 reconstruction findings including constitutive derivatives, oxygen stress, macropore state/ownership, lower boundaries, top-boundary Jacobian/acceptance and coupling semantics.

Links: TRACE.

Need to establish: prospective discrepancy taxonomy; denominator and detection process; independent second-model evidence (e.g. ANIMO) before claiming generality.

## INBOX-PUB-11 — Lower-boundary semantics and identifiability
How should lower-boundary conditions be classified by physical ownership and observational support, and under what conditions are flux-, head-, resistance- and lysimeter-type formulations distinguishable or identifiable from system response?

Origin: LOW01/03/05/08 migration, explicit parking of legacy SWBOTB=1 and the recognition that some target groundwater heads are physically infeasible under the rest of the boundary system.

Links: coupling; NUM-UNC; potentially hydrological-methods work.

Need to establish: scientific novelty beyond software migration; synthetic identifiability; observational cases; relation to groundwater coupling.

## INBOX-PUB-12 — Hydrological memory and recovery
How do groundwater feedback, soil hydraulic properties, root-zone state and atmospheric demand control persistence and recovery after drought, and what state variables carry predictive memory?

Origin: existing HYDRO-MEMORY line, now to be revisited after coupling and numerical architecture stabilise.

Links: HYDRO-MEMORY.

Need to establish: physical novelty independent of SWAP5; observational or multi-model support; separation from generic groundwater buffering.

## INBOX-PUB-13 — Population-scale solver policy
For very large heterogeneous ensembles of soil columns, what combination of local numerical policy, workload prediction and worker scheduling minimises total compute while preserving predefined hydrological error and mass contracts?

Origin: MULTI06/07, SCHED01/02, falsification of size-only worker selection and performance-objective policy.

Links: ACCELERATE; DIFFICULTY; application-scale computing.

Need to establish: scientific/computational audience; transferability beyond SWAP; heterogeneity-aware workload prediction; coupled MODFLOW timing constraints.

## INBOX-PUB-14 — Reassess publication architecture after migration
After completion of the main SWAP4.3.1-to-SWAP5 migration, jointly reassess PUB-GC/COUPLE, ROM/ACCELERATE, DIFFICULTY, NUM-UNC, TRACE, HYDRO-MEMORY and the new INBOX items. Merge overlapping questions before opening new paper workstreams.

Decision rule: prefer a smaller number of papers with a clear scientific claim and independent falsification over papers that mainly report implementation progress.

