# MC-NUT01 / MC-SOL01 state and owner decision

Status: WORKSTREAM_CONTRACT_PREREGISTRATION  
Baseline: `integration/f-ci-canonical@71fecec02aabe020e9950dc6d08f9dbb35fc2413`

This record narrows the remaining B1.11 nutrient and solute work. It does not
admit new production physics by itself.

## Ownership decomposition

The existing admitted matrix-solute route remains the only mobile dissolved
solute owner. Its committed node salt mass remains authoritative and
concentration remains a derived view from the matching committed/trial water
state. Sorption and decay must extend that owner rather than create a second
independently committed solute state.

The remaining stores are distinct physical authorities:

| Store | Persistent authority | Transfers owned here |
| --- | --- | --- |
| matrix dissolved solute | existing FMR optional salt component | top/bottom, drainage, root uptake and inter-node transport |
| matrix sorbed solute | MC-SOL01 reactive-storage extension | equilibrium dissolved/sorbed repartition only |
| pond solute | MC-SOL01 pond component | rain/irrigation/runoff/infiltration exchange with one surface donor |
| aquifer solute | MC-SOL01 aquifer component | drainage/bottom exchange and breakthrough |
| age tracer | dedicated tracer amount, not salt concentration | advective/dispersive carriers plus age production |
| mineral soil N | MC-NUT01 Soil-N owner | NH4/NO3 transport, plant uptake, nitrification and denitrification |
| organic soil C/N | MC-NUT01 Soil-N owner | mineralisation/immobilisation, amendments and crop residues |
| crop N | crop owner | demand, uptake receipt, fixation input and crop internal redistribution |

All persistent stores must live in the same accepted physical transaction as
their coupled water/crop state or in an explicitly atomic composite owned by
that transaction. Rejected trials may return candidate diagnostics but may not
mutate any committed nutrient or solute store.

## Sequencing

MC-SOL01 proceeds from the already admitted conservative matrix transport:
reactive storage, then decay, then pond/aquifer stores, then age tracer.

MC-NUT01 first introduces one Soil-N inventory owner for mineral and organic
pools. Reactions and crop exchange operate on candidate inventory receipts.
Amendments and residues are management transfers into that same owner. No
reaction routine owns persistence independently.

## B1.11 fixation policy

`SW431-NUT-NFIX` is not implemented by changing WOFOST81. The admitted
WOFOST81 request semantics remain unchanged.

A separate B1.11 fixation policy owns only the old selectable demand rule:
vegetative N deficits, strict `DVS < DVSNLT`, strict `RELTR > 0.01`, and
partition by `NFIXF`. Storage-organ demand and new-growth demand are not
silently imported from WOFOST81. Literal-source qualification is required
against `SWAP/wofostnut.f90` from the pinned B1.11 authority bundle.

This policy is a crop-N input calculation only. It does not establish Soil-N
supply, full-season crop-N limitation or nonzero production admission until the
crop/Soil-N exchange owner is bound and qualified.

## Aquifer defect decision boundary

The B1.11 SWBR aquifer block has a reproduced bounds defect: after the node
loop, source code indexes a node-sized carrier with the completed-loop index
`numnod+1`. No replacement node or coefficient is source-qualified.

Therefore `SW431-SALT-AQUIFER` is blocked at an explicit architecture/reference
decision. Before production implementation the project must approve a corrected
aquifer reservoir coefficient/storage contract with declared dimensions and
rate-versus-accumulated units. The correction must then be qualified as a B1
reference correction, not hidden as an implementation convenience.

Until that decision, sorption/decay work may proceed only in matrix storage and
must not guess aquifer semantics.

## Mass contract

For every candidate step, the owner exposes an independent constituent receipt:

`candidate storage = committed storage + external inputs - external outputs + internal transformations`.

Internal transfers between dissolved/sorbed or organic/mineral pools cancel in
the whole-system total. Fixation and amendments are external N inputs;
denitrification, volatilisation, exported drainage/bottom/runoff and crop
harvest/losses are external outputs according to the capability contract.

Whole-system qualification must check the sum across all active stores,
separately from local equation oracles. Restart must serialize every persistent
store required to reproduce the next accepted step.

## Claim ceiling

This record establishes owner and mass-contract sequencing and preregisters the
separate B1.11 fixation policy. It does not yet close organic pools, mineral
pools, reactions, crop exchange, management additions, sorption, decay, pond,
aquifer or age-tracer production admission.
