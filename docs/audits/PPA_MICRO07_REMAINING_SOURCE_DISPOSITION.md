# PPA-MICRO remaining B1.11 source decisions

Status: source census for the next bounded work units, not implementation or
admission. The current production candidate is MICRO02–06 on draft PR #1077.
Authority is the exact B1.11 `rootextraction.f90` and `RWU_micro.f90` under
`reference/swap-4.3.1/b1_11_frost_source/SWAP/`; the corrected MICRO01 dry
table policy still applies. This note does not change the frozen Status-A
denominator.

The source dispatcher selects `sw_drought=3` for de Willigen (`iMicro=1`)
and `sw_drought=2` for de Jong van Lier (`iMicro=2`). Both receive `ptra` and
`Lrv_node`. MICRO02–06 implements only normal de Willigen uptake with an
explicit forcing owner; it does not create crop transpiration or import the
MACRO Jarvis/Walsum compensation. A production crop-ET binding therefore
remains a separate input-ownership work unit.

Before `do_RWU_micro(2,...)`, the source builds `alptot` from oxygen,
salinity and frost factors. `swAlpTot=1` multiplies node factors;
`swAlpTot=2` takes their minimum. Mode 3 multiplies only strictly positive
node factors into one scalar and broadcasts it to every rooted node. The
zero-skipping behavior is literal source behavior, but its physical meaning
is not established here. It needs an explicit reference-policy decision and
zero-factor tests before production use. The current SWAP5 MICRO runtime
passes a vector of ones, and its existing post-sink oxygen/salinity/frost
processors must not be silently reused: in B1.11 the factors influence the
nonlinear uptake calculation itself.

For the next stress slice, the source supports a Feddes wet-head factor for
`sw_oxygen=1`, Bartholomeus physical or reproduction functions for
`sw_oxygen=2`, and a Maas–Hoffman concentration factor for `sw_salinity=1`.
Start with a pure, call-local factor construction and independently generated
literal source oracle for the bounded Feddes and salinity cases. Bind it to
the current trial pressure and salt view before the one MICRO sink only after
the pure source behavior and transaction semantics are qualified. The
Bartholomeus branch requires separate thermal/gas-filled-porosity ownership;
existing post-sink Bartholomeus admission is not that evidence.

The B1.11 `rootextraction.f90` calls `swap_error` immediately when
`swfrost==1` on the MICRO route. Its later frost-factor loop is unreachable
under that guard. Frost therefore has no executable B1.11 MICRO source
trajectory to claim as migrated. Any future MICRO frost support would be a
new, explicitly qualified SWAP5 extension, not a literal migration.

`RWU_micro.f90` likewise calls `swap_error` for `swDoSatRel=1` before its
later saturated-relative branches. Optimal-root rerun (`sw_mxdrought=1`),
de Jong van Lier, and signed hydraulic lift remain distinct work units.
Hydraulic lift cannot fit the present nonnegative sink contract without a
new signed source and mass/transaction/restart design. Do not activate it by
merely relaxing the MICRO input guard.

Next safe sequence after the current candidate's admission decision:
source-oracle the two bounded stress factors and combination modes; prove
current-state and changed-forcing runtime recomputation with a single sink;
then qualify crop ET ownership and the remaining selectors independently.
Any source change will invalidate the exact B15 successor tree pin and needs
new moving preservation on that new postimage.
