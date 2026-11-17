# Original no-macro subsurface solute input correction

**Development candidate: Windows paired original and SWAP5 O0/O2 PASS;
portable qualification and canonical admission pending.**
This is not a global B1 promotion. Active macropore branches are unchanged and
are not selected for execution.

The actual original concentration perturbation is recorded at
`integration/f-ci/nomacro-complete01/ORIGINAL_CHEMICAL_AUDIT.json`:2.4cm subsurface
water ignores concentration0/20, while the surface positive control adds48mg/cm2.
Original CDE includes neither the nodal irrigation mass source nor its ledger.
The original fixed-irrigation producer also leaves `cirr=0` for subsurface
events. The first CDE-only candidate completed every paired period but still
reported zero injected mass: the missing producer/consumer coupling is retained
in `CHEMICAL_CDE_ONLY_FAILURE.json`. The complete candidate publishes the actual
fixed-event concentration only for no-macro chemical subsurface delivery.

The correction consumes actual original `qssdi(i)` in cm/day, original `cirr` in
mg/cm3, actual solute interval in days, and original compartment thickness in cm.
The existing conservation equation receives the source in conserved bulk mass
`cmsy`, before the original concentration conversion. The matching amounts enter
both existing cumulative/intermediate irrigation ledgers. The allocation is
literal per supplied compartment, preserving original interval irrigation; it is
not normalized by node count or soil thickness.

The shared production evaluator has an independent one-provider O0/O2 driver
with exact units/mass, A/B/A, input nonmutation and refused-output preservation.
The original CDE scratch arrays contain only freshly derived source amounts;
they are initialized on task1 and overwritten each active solute substep. They
are not physical state and introduce no persistent format. The original CDE
equations, numerical controls, surface sources and inactive source arithmetic
remain unchanged. The experimental fixed chemical caller selects the explicitly
identified correction for SWSOLU1/SWIRFIX1/SWMACRO0. Scheduled chemical SSDI remains
refused. Registered release profiles do not select this new source correction.

`CHEMICAL_CORRECTED_REFERENCE.json` records 24 complete original/corrected periods:
the corrected point and interval input equals the actual water times concentration
(48 mg/cm2), while every source-absent and surface row is exact at matching
optimization. This is source/ledger qualification, not whole-model B1 promotion.
Actual SWAP5 Windows point/interval trajectories complete1096days at both O0/O2,
including exact physical/CSV/native own windows2to4,4to6(active),365to367,
active discard/replay/adopt/recovery, and unchanged committed state after a
deliberately inconsistent chemical candidate is refused by the existing guard.

Before integration, qualify the exact corrected original module on water-only
macropore-disabled input with active chemistry: surface/subsurface0/20 controls,
explicit per-node conservation, strict chemical balances and source-absent
preservation. Then qualify the actual SWAP5 caller, accepted/discarded state,
source/ledger correspondence, own native restart and relevant process coupling.
Pristine original water/chemistry defects remain separate; original output is
not automatically a scientific oracle.
