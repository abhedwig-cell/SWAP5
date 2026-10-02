# PPA-WU05-MIGMAC01 typed physical/interface contract

Date: 2026-10-02
Status: PREREGISTERED_IMPLEMENTATION_CONTRACT
Owning branch before contract: cdafbc6b18951a1de33b5dbdd7d4e361af3f17bc
Current canonical reconciled before contract: e50a1bad6482b0aaeaf25a87e1fd1b1d5e19a846
Work unit: PPA-WU05-MIGMAC01, covering-layer standard macropore route, IcTopMp > 1

## Authority and bounded purpose

This contract records the missing typed physical carriers before changing shared
Richards/runtime interfaces. It does not qualify MIGMAC01, change the frozen
Status-A denominator, admit a corrected B1 reference, or reopen M2 dynamic
shrinkage/crack geometry.

The current canonical delta since 7a629a10cabb3553ff77474423e6ccac81b29aec
contains the admitted LOW03-P0 resistive lower-boundary prerequisite. It changes
the shared Richards solver contract, legacy binding and HeadCalc, but it does not
supply either MIGMAC01 carrier below. Implementations must preserve the LOW03
semantics when reconciled; this work unit must not overwrite them.

## C1. Source matrix-area ownership

The explicit Richards path shall carry the source matrix-area fraction as an
immutable node array. The source value is B1.11 FrArMtrx for the captured physical
state. It shall not be reconstructed from current macropore volume geometry.

Reason: the corrected source capture proves FrArMtrx is physically active in
matrix storage and flux reconstruction. In the critical nodes 15-26 it is about
0.963-0.965. Across the complete captured profile, however, FrArMtrx is not
identically 1 - VlMpStCp - VlMpDyCp. Deriving it from migrated geometry would
therefore change the source contract and could pull separate M2 geometry semantics
into MIGMAC01.

Typed rules:

1. soil_water_physical_config_t may carry matrix_area_fraction(:).
2. When supplied, its length shall equal active_nodes, every value shall be finite,
   positive and <= 1, and the explicit Richards path shall use it instead of any
   module-global FrArMtrx.
3. When absent, matrix area is exactly 1.0 and existing non-macropore behaviour is
   preserved.
4. Matrix-area scaling is independent of whether a macropore exchange provider is
   active in a particular predictor/corrector solve. An active macropore column
   therefore retains source matrix area during a predictor with zero macro exchange.
5. The carrier applies wherever B1.11 FrArMtrx owns matrix cross-section or storage:
   matrix storage terms, conductivity and dK/dh weighting used by HeadCalc,
   reconstructed vertical flux/storage, and integrated matrix storage accounting.
6. The carrier does not activate legacy macropore globals, legacy top-input ownership,
   or surface-area/rainfall shortcuts. The explicit provider path remains isolated
   from module-global SWMACRO/FrArMtrx ownership.

## C2. Immutable covering-layer physical parameters

fmr_macropore_physical_config_t shall own the source physical parameters needed by
the already implemented B1.11 covering operator:

- covering_minimum_polygon_diameter_cm, source DiPoMi / Ld;
- covering_ksat_cm_per_day, source KsatCovLay.

For geometry%top_node > 1 both values are required, finite, with diameter > 0 and
Ksat >= 0. For top_node == 1 the covering route is disabled and the new values may
remain absent/default without changing A9.

The serialized reference backend shall copy these values with the immutable
macropore configuration and pass them to macropore_single_column_runtime_t. The
runtime shall pass them unchanged to the inner macropore provider. No forcing,
head, timestep, tolerance or physical formula is changed by this propagation.

## C3. Covered-transfer ownership

For top_node > 1 the covering operator remains internal matrix-to-macropore
transfer. It is not precipitation or external top input. The accepted covered
amount shall have an equal-and-opposite matrix sink and macro receipt. Rejected
trials shall leave committed matrix and macropore state unchanged.

A9 remains the top_node == 1 surface-connected route. For top_node > 1 no A9
rainfall shortcut is introduced and external macropore top input remains
zero/unsupplied unless separately owned by an admitted surface contract.

## C4. Numerical separation

This interface repair shall not change:

- compartment or total balance tolerances;
- head tolerances;
- max nonlinear iterations/backtracking;
- forcing, source event, dt or event selection;
- the bounded B1 CALCGWL correction;
- the existing Reference native convergence criterion.

G6 native-rate precision and G7 remaining exact-last-rate discrepancy stay separate
diagnostic questions. A green result caused only by this carrier repair is evidence
only if the same frozen corrected source origin is replayed.

## Required verification sequence

1. Narrow typed-contract tests: absent carrier preserves ordinary Richards; supplied
   carrier is validated and scales matrix storage/conductivity consistently.
2. Backend/config propagation tests for top_node == 1 and top_node > 1.
3. Re-run the frozen corrected-source diagnostic without tolerance/input tuning.
4. If strict Reference still rejects, attribute G6/G7 before any further physics
   change.
5. Only after a converged source-backed active event: exact internal ownership,
   macro closure, reject/replay/restart, PERCH20/PERCH21, A9 and A10 preservation.
6. Qualification evidence must test the exact persisted postimage. Canonical
   admission/closeout remains a later governance action.

Historical negative fixtures and prior negative replay evidence remain immutable.
