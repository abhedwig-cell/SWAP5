# PPA-MICRO02 de Willigen standalone uptake contract

Status: proposed implementation and qualification boundary. Baseline canonical
`e5eab995ef04fc813dd644025fb0f32e4f5050a1`. This is separate from the
admitted PPA-MICRO01 table and from Jarvis/Walsum MACRO compensation.

The exact B1.11 `rootextraction.f90` dispatcher selects `sw_drought=3` for
de Willigen (`iMicro=1`). `RWU_micro.f90` uses its tabulated matric flux
potential, root-cylinder geometry, root-wall and soil-root conductances, the
Campbell or threshold leaf reduction, a nested pressure solution, and a final
per-node `Upw` sink. The source SHA256 is
`cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477`.
Its dry table defect has the explicitly corrected reference policy in
`PPA_MICRO01_TABLE_REPAIR_CONTRACT.md`.

Negative literal-source result on the first full nonlinear replay: at
`h=[-100,-200]` cm with constant K, equal root densities and
`swHydrLift=0`, the corrected-table B1.11 source returned layer `Upw`
`[0.3,-0.2]` cm/d, `Tact1=0.1` and `Tact2=0`, with `check=[T,T,F]`.
This is not a valid nonnegative sink or a closed soil-to-root flux even though
the first two checks pass. The source `myFun` endpoint-acceptance branches do
not perform their advertised final reevaluation at the chosen pressure; that
is a plausible mechanism, pending a controlled falsification. The anomaly is
preserved as negative evidence, not used as an equivalence target. Positive
source comparisons are restricted to cases where all three checks pass.

This work unit first owns a call-local, typed *standalone* evaluator. It accepts
the committed hydraulic pressure-head view, rooted node thickness, root length
density, bounded stress factors and immutable MICRO01 tables. The tables are
built by sampling the existing B1.10 MvG point-conductivity authority at each
node (all 430 source grid heads, -20000 cm and 0 cm). The source used one
soil-layer representative node per horizon, whereas this first binding is
per-node; source comparison therefore requires a horizon-homogeneous profile
or an explicit first-node mapping before making a heterogeneous claim.
Configuration and scratch do not use module SAVE or mutate committed state.

The first executable slice is normal uptake, `swHydrLift=0`, `swDoSatRel=0`,
`fl_optrtz=false`, de Willigen `swO2ECT=0/1/2`, `swTypeTred=1/2`, and caller
supplied `alptot`. It keeps the source ordering of no roots and negligible
transpiration, the unsaturated and positive-stress mask, the `Q`/`S` formulas,
the `FG` geometry function, reduction law, nonnegative node sinks and source
total cap. It rejects invalid geometry, hydraulic input, nonfinite arithmetic,
unbracketed or unconverged solutions rather than accepting a warning-state
flux. Rejection publishes no sink.

Source `sw_drought=2` (de Jong van Lier), optimal root activity, hydraulic
lift with signed sinks, oxygen/salt/frost stress construction, and the
production runtime's one accepted sink are outside this slice. The existing
backend rejects negative root extraction and cannot represent hydraulic lift
without a separately designed signed water-source contract. No Jarvis/Walsum
compensation is applied after MICRO. No new persistent state or restart schema
is justified by call-local scratch; runtime activation must still prove trial
rejection, accepted mass and restart equivalence.

Before any production admission, execute an independently generated corrected
literal B1.11 source oracle at O0/O2 on heterogeneous pressure and homogeneous
hydraulic horizons, normal and stressed roots, dry/wet and zero branches,
convergence and rejected-input cases. Record exact source/blob hashes and
immutable outputs. Qualify the real hydraulic binding and one final root sink
through the current transaction and restart paths, and rerun affected
preservation gates. A standalone smoke result alone cannot admit MICRO.

Affected invariants: 3, 5, 7, 13, 21, 22, 23, 25. The isolated component
strengthens ownership and rejection; the single sink, mass and restart
obligations remain open until integration evidence exists.
