# F-MIG431-LOW03-P0: shared resistive head boundary reconciliation

Status: central preregistration, not production implementation or admission.
Baseline: `6cc03d6e122bdcd2007c1a709476ce63a68d6e36` on integration/f-ci-canonical.
Sole official branch: `work/f-mig431-low03-p0-resistive-head-authority`.
Owner: central F-MIG431 lower-boundary authority. SWBOTB1 remains parked. Active review order remains3, then8.

## Scientific question and source authority

Determine whether implicit SWBOTB3 needs a new solver or only an explicit resistive-head bottom-row extension of existing Full Richards. Do not assume it is already admitted because dormant legacy code exists. Source is corrected SWAP4.3.1 B1.11, recovered losslessly in `integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json`; headcalc member SHA256 db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5. No re-upload required.

B1.11 Headcalc:580-584 gives implicit native upward-positive qbot=(Haq-(hN+zN))/(d/Kb+RIMLAY), or denominator RIMLAY alone when SwBotb3ResVert=1. An optional DATE4/QBOT4 flux is added at587. Jacobian:649-654 adds the reciprocal of that same resistance to the final residual diagonal, holding K fixed for this contribution. Thus the same Richards unknowns, tridiagonal solve, physical state and transaction owner apply. No moving NN interface as in parked mode1 is needed.

Mode5 gradient at548 corresponds to q5=Kb/d*(Hface-(hN+zN)), with Hface=HBOT5+zface and zface=zN-d. At identical Kb, RIMLAY=0, include-half-cell=true and no extra flux, implicit3 has the same flux law and frozen-K bottom-row Jacobian as5. This is an algebraic limit, not a full production equivalence claim.

For RIMLAY>0, conductance becomes1/(d/Kb+RIMLAY), not Kb/d. A fixed HBOT5 conversion changes the driving head but cannot change that conductance. Recasting it as an effective head would make head depend on current node pressure, conductivity and extra flux; resolving it only once before a solve loses implicit semantics. With SwBotb3ResVert=1, Kb and half-cell resistance are intentionally absent. A mode5 flag cannot express this today.

## Current typed surface and explicit prerequisite

`soil_water_boundary_conditions_t` exposes bottom_mode, bottom_flux and bottom_head, but no bottom resistance/include-half-cell field or lower-boundary provider. Evaluation context exposes top providers but no bottom provider. Public adapter/profile currently reject3. Dormant ported mode3 uses legacy globals deepgw/rimlay/swbotb3Impl/swbotb3ResVert/sw4/qbotab and no qualified mode3 mass publication. These are genuine shared typed-boundary/candidate-publication gaps, not justification for a new Richards solver.

Central decision: one bounded shared resistive-head prerequisite, reusing the existing Richards solve and residual assembly. This registration authorizes diagnostic/design work only. Before production edits, persist a concrete contract deciding minimal immutable typed request values: external total head in soil-profile cm coordinates, nonnegative external resistance in days, whether half-cell resistance is included, and independent extra native qbot. Do not overload mode5 ordinary/GW head ownership or use a flux/head field secretly as resistance. Choose new fields or an explicit provider only after dependent bindings are reconciled. No public C ABI expansion is authorized here.

Mode5 default semantics, geometry, constitutive provider and groundwater fixed-interface owner must remain unchanged. The Robin contribution is bottom-row physics, not an aquifer component or coupling ledger. Ordinary mode3 input heads do not acquire MODFLOW datum conversion or groundwater storage ownership.

## Legacy numerical distinction

B1.11 Headcalc:680-681 adds an extra conductivity-derivative term for modes1/5/active8 under SWKIMPL=1, but excludes3. Therefore zero-R algebraic flux equality is not proof of identical SWKIMPL=1 iteration behavior. Initial shared qualification must be bounded to SWKIMPL=0 or explicitly reconcile that difference through reference-governed numerical authority. Never silently add a mathematically complete derivative and call it B1.11 preservation. Use the same current provider Kb and frozen-K Jacobian grouping when comparing3 and5.

## Explicit application variant remains separate

Boundbottom:75-106 explicit3 uses gwlmean=HDRain+SHAPE_3*(gwl-HDrain), deep head sine/table, optional saturated profile resistance sum from geometry and saturated conductivity, then optional extra qbot. It can potentially bind the resulting frozen qbot to admitted mode2. It is not numerically identical to the implicit lower-node-head law. No application branch or full mode3 admission is issued by this P0. DATE3/HAQUIF, AQAVE/AQAMP/AQTMAX/AQPER, DATE4/QBOT4, initial origin/proposal timing and resistance-domain guards must be source-bound before LOW03-A is issued.

## Mandatory gates and fail-closed domains

Diagnostic harness extracts exact B1.11 implicit flux/Jacobian and mode5 gradient fragments into a temporary standalone Fortran wrapper. Sweep both resistance flags, positive K/d, zero/positive external resistance, capillary and drainage gradients and independent extra flux. Check zero-R head limit, nonzero-R nonalias and O0/O2 identity. This proves bottom-row composition only, not solver convergence, mass, retry or restart.

Production prerequisites: finite head/flux/resistance; physically valid geometry; R>=0 with half-cell, R>0 without it; positive finite K when half-cell resistance participates, positive finite denominator, and explicit handling of zero-conductivity/overflow cases. Legacy parser accepts AQPER=0/RIMLAY=0 in some combinations but this is not permission for division by zero. These singular domains must remain fail-closed, not silently regularized.

Before admission: frozen-source residual and Jacobian comparison, full Reference accepted solve, source-independent unrounded compartment/whole-profile mass identity, exact qbot candidate publication and accepted integrated amount, failed trial immutability, reject/replay/restart and proposal sampling, A/B/A column isolation, O0/O2. Preserve admitted2/internal-2,4,ordinary5,groundwater-owned5,6,7 and all transitively affected shared typed bindings. Do not widen controller tolerances, change restart format, or duplicate coupling accounting. Use Actions only for required persisted production qualification/admission evidence.

## Recovery

Read `integration/audits/F-MIG431-LOW03-P0_STATUS.json` first. Exact source/test/runner postimage must be persisted before the diagnostic build. Central evidence will identify the tested SHA and frozen-source/input hashes. No production source is modified by P0 registration. Full lower-boundary migration remains incomplete with1 parked and3/8 open.
