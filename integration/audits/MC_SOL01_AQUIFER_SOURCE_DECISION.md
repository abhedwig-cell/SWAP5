# MC-SOL01 aquifer source decision

Status: **SOURCE_DEFECT_DECISION_REQUIRED**

Capability: `SW431-SALT-AQUIFER` (`SWBR=1`)

## Exact B1.11 defect

The exact B1.11 `solute.f90` authority enters the SWBR aquifer block after the
matrix-node loop. At that point the loop index is `numnod+1`, while
`bdenskfsatporos` is dimensioned over `1:numnod`. The literal expression
therefore reads `bdenskfsatporos(i)` out of bounds.

The existing O0/O2 bounds witness reproduces this for both positive and negative
signed drainage cases. This is a source defect, not an implementation choice.

## Fail-closed production rule

No production route may infer that the intended coefficient is simply
`bdenskfsatporos(numnod)`, average the profile coefficient, or silently drop
aquifer sorption. The transactional companion owner may persist
`aquifer_mass`, but its current production transfer configuration rejects any
non-zero aquifer delta.

## Decision that is still required

A corrected aquifer model must explicitly define all of the following together:

1. the aquifer water-volume/storage state represented by `Caquif`;
2. the sorption/storage coefficient used for that reservoir;
3. whether the source drainage quantities entering the aquifer block are rates
   or accepted interval amounts;
4. the sign convention for drainage into and out of the aquifer;
5. decay and breakthrough ordering within an accepted interval;
6. whole-reservoir constituent mass balance;
7. retry/reject rollback and restart reconstruction.

Admissible outcomes are:

- **reference correction** with an independently justified aquifer coefficient
  and exact mass contract;
- **qualified replacement model** with explicit provenance and a declared
  departure from literal B1.11;
- **unsupported/rejected capability** if no defensible physical interpretation
  can be established.

Until one of these is approved, `SW431-SALT-AQUIFER` remains open and all
aquifer mutation is fail-closed.
