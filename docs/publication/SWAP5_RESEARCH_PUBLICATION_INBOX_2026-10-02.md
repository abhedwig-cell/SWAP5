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



# Strategy update — 2026-10-17

This update records evidence emerging after the initial INBOX freeze. It changes prioritisation, not novelty status.

## Portfolio layers

### Layer 1 — expected publications
- **SWAP5 GMD reference paper**: preferred broad model-description/reference publication. The increasingly integrated water–crop/root–solute–nutrient–irrigation–drainage state strengthens this route.
- **Stromingen**: Dutch community article on the SWAP–MODFLOW6–Ribasim instrument direction, behind the agreed publication firewall.

### Layer 2 — serious PhD candidates
- **TRACE / INBOX-PUB-10**: promoted to serious candidate. Source assessments, explicit legacy defects/corrections, exclusions and executable-evidence decisions are accumulating into a prospective dataset rather than isolated anecdotes. Do not analyse final frequencies/taxonomy until the migration denominator closes.
- **DIFFICULTY / INBOX-PUB-02**: remains serious. Future response variables must separate actual model/solver difficulty from compilation, CI, test-selection and infrastructure cost.
- **NUM-UNC / INBOX-PUB-03**: remains separate from DIFFICULTY; its target is scientific inference sensitivity to admissible numerical choices.
- **HYDRO-MEMORY / INBOX-PUB-12**: unchanged; wait for a stable research instrument.
- **COUPLE / INBOX-PUB-05**: increasingly promising, but hold activation until the SWAP5–MODFLOW6 interface and F-GC-STRIP01 are stable enough to test general ownership claims.

### Layer 3 — hypotheses requiring due diligence
- **TOP03 / INBOX-PUB-06**: elevated within the inbox as an interesting hydrological-methods hypothesis. Next step is literature due diligence on continuous/complementarity/atmospheric surface-boundary formulations.
- **ACCELERATE / INBOX-PUB-01, -08, -09, -13**: downgraded as an automatic standalone paper. Engineering speedup is insufficient. Reactivate only if computation can be reduced under an explicit hydrological error/applicability contract.
- **ROM / INBOX-PUB-04**: retain around purpose-specific minimum sufficient hydrological state; surrogate construction alone is insufficient.
- **Macropore / INBOX-PUB-07**: retain pending observational/generalisation evidence.

## TRACE evidence policy
The migration has produced further cases where legacy source is evidence to reconcile rather than an unquestioned oracle, including source-bound crop/N assessments, an identified/corrected leaf dry-matter/dead-leaf residue defect, superseded routes and intentionally excluded legacy capabilities.

Preserve for later TRACE analysis: final capability denominator; discovery trigger; theory/documentation/source/executable evidence; scientific consequence; preserve/correct/supersede/reject/not-applicable/qualification-only decision; and whether conventional regression alone would have exposed the issue. Freeze the taxonomy before final quantitative analysis rather than retrospectively fitting categories.

## DIFFICULTY versus infrastructure
Recent proportional testing, impact-based regression, shared-build and fail-closed preflight work shows that development/qualification wall time can be dominated by infrastructure rather than hydrological solver difficulty. Future DIFFICULTY experiments must control compilation, harness startup, CI scheduling, unrelated preservation tests and irrelevant I/O. Negative performance results remain evidence.

## GMD implication
Do not start the manuscript yet. Use `docs/publication/SWAP5_GMD_PROVISIONAL_EXPERIMENT_MATRIX_2026-10-17.md` to preserve candidate evidence, then select and regenerate the final small suite against the exact paper release.

## Portfolio decision
Do not open nutrient, irrigation, crop or drainage papers merely because those workstreams now have substantial migration evidence. Their present publication value is mainly that they strengthen SWAP5 as an integrated model and therefore the GMD reference paper. Reassess the whole portfolio after main migration/coverage closure.
