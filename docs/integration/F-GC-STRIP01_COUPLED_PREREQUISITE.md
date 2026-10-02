# STRIP01 coupled-domain prerequisite

Status: **proposed shared application-domain contract; not accepted or qualified**.
Pinned canonical 53059a5225fa45cd6121d4bc4c7310dcc4e0660c.

## Concrete incompatibility, not a numerical failure

The controlling fixed-interface contract assigns physical storage to SWAP,
native STO to HEAD_STATE_CAPACITANCE, and active drainage owner NONE.
The actual production bootstrap rejects all other storage/drainage labels in
production_application_materialize_groundwater_context. Exact source blob:
4f826df4f0580bcde7941a1511acc4a67646ec72.
Research topology labels are representable, but do not imply a production
context or an independently qualified coupled physical water balance.

Adding standalone Sy=0.2 storage over the full -10..0 m aquifer and adding
SWAP storage over an overlapping soil profile would count overlapping physical
water. Subtracting an arbitrary residual, switching off a guard or relabelling
STO does not resolve this. A converged interface residual is insufficient.

## Recommended research route for shared review

Retain the current production profile unchanged. Register a distinct research
application topology with one drain route, owned by MODFLOW, SWAP drainage off.
Before C, decide the physical domain partition and vertical interface elevation:

1. SWAP owns its full soil profile above a fixed plane; MODFLOW owns the
   non-overlapping saturated aquifer below that plane. Supply physical Ss only
   for that separate aquifer. Do not add MODFLOW Sy for water-table storage
   already represented inside SWAP. Place the plane below the lowest selected
   head so the lower domain remains saturated over the tested trajectory.
2. Specify the lateral transmissivity for this partition. Using only the lower
   aquifer thickness is a different conceptual model from standalone A's
   full-thickness Dupuit strip. An explicit effective transmissivity closure
   would require its own justification and test; it is not inherited from A.
3. Choose interface geometry and duration before inspecting C results. Report
   MODFLOW head, SWAP lower-face hydraulic head, and SWAP phreatic elevation
   separately. Identity at the fixed plane does not imply GWL identity.
4. After the shared research contract is accepted, implement a dedicated
   qualification harness using existing accepted-origin trial and publication
   primitives, not a weakened production bootstrap or new production ABI.

This is a central prerequisite under quality-governance-a-aa section 5 because
application/mass ownership semantics are shared. STRIP01's research mandate
does not silently amend them. Canonical admission remains out of scope.

For positive outward SWAP exchange E_i, the research window balances must be:

```text
SWAP: P_i - ET_i - runoff_i - E_i = delta S_SWAP_i
MF: sum(area_i E_i) - D = delta S_MF_disjoint
Combined: sum(area_i(P_i-ET_i-runoff_i)) - D
          = sum(area_i delta S_SWAP_i) + delta S_MF_disjoint
```

Here E_i is an integrated depth; D is a volume; the ledger owns neither storage
nor an additional physical flux. If a reference finite-window capacitance is
retained instead, report its native numerical balance separately, without
calling it independently physical groundwater storage.

## Source readiness and limits

B01 is a repository-backed fast/high-K hydraulic candidate, not a claimed
complete BOFEK profile: theta_r=0.02, theta_s=0.427494, alpha=0.021659 1/cm,
n=1.734737, Ksat=31.225016 cm/d, lambda=0.98087. Authority:
docs/performance/F-PE-BOFEK01_TESTBANK.json. Final soil/node geometry is not
selected until the physical partition is accepted. Do not substitute F-GC44's
short synthetic column and call it a qualified Dutch sand application.

The historic Hupsel prerequisite is not still blocked on M1-C3: the later
M1_C3_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER_QUALIFICATION.json records its scientific
gate PASS. It does not itself qualify this changed soil, drainage or groundwater
composition. tests/f-app06/fixtures/hupsel_swinter0_b111_exact.part00.csv is a
process trace, not a complete dated meteorological input file. The actual
283.met identity is 1de5ba86caded630f8c5b828648e8bda091115acd243891fe7d8b3551bc5add6.
No re-upload is requested. Recover the existing authoritative bytes through
repository/project sources after the domain contract, then bind selected dates,
ET inputs and event windows. Do not manufacture Hupsel weather from the trace.

## Held fixed and next gate

No production sources, accepted storage/drainage guards, solver ABI, ledger,
restart schema, tolerances or canonical records change in this unit.
Touched invariants: explicit ownership, transactional rejection, interface
action/reaction, mass conservation, physical/numerical separation and qualified
scope. C/D/E are not qualified. Next gate is an explicit shared research-domain
decision, followed by the 50-column far-cell-to-drain experiment and true
accepted-window/reject/restart tests. Standalone A/B PASS is not a substitute.
