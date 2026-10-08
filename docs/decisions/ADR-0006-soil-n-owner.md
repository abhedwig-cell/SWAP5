# ADR-0006: One transactional Soil-N owner and separate crop fixation input

Status: **Accepted**

Date: 2026-10-07

## Context

The SWAP 4.3.1/B1.11 nutrient surface contains organic matter turnover,
mineral ammonium/nitrate inventory, amendment and residue additions,
nitrification, denitrification, mineral-N transport, soil-to-crop supply and
biological fixation. The current SWAP5 WOFOST81 route already owns crop
nitrogen state, but deliberately supplies its complete soil request and
therefore does not own a limited Soil-N inventory.

Porting the legacy routines one by one would otherwise create several
independent authorities for the same nitrogen mass. That would violate the
current transaction and mass-conservation architecture and would make
rollback/restart ambiguous.

## Decision

SWAP5 uses one persistent transactional **Soil-N owner** for the B1.11
soil-nutrient migration.

The owner follows the B1.11 SoilManagement aggregation rather than the general
nodal solute grid. Its authoritative accepted state contains:

- one SoilManagement depth `dz_WSN`;
- `FOM(1:nf)` fresh-organic-matter pools;
- the biomass organic-matter pool;
- the humus organic-matter pool;
- mineral ammonium N;
- mineral nitrate N.

Organic nitrogen is not duplicated as a second mutable state. It is derived
from the accepted organic-matter pools, their immutable N fractions, and the
owned SoilManagement depth. This keeps the organic-matter process equations
and the nitrogen mass ledger consistent.

All soil-N process modules are pure or candidate-producing operators. They do
not commit stores directly. They emit explicit FOM/Bio/Hum and mineral-N deltas
plus separately booked external N inputs and outputs. One owner applies the combined transfer
atomically, verifies non-negative stores and verifies whole-owner mass closure
before the candidate can be committed.

The following operations are transfers owned by this Soil-N state:

- organic turnover/mineralisation;
- ammonium-to-nitrate nitrification;
- nitrate denitrification loss;
- dissolved/mineral transport;
- fertilizer/manure additions;
- crop-residue additions;
- bounded soil-to-crop mineral-N supply.

Biological fixation is deliberately **not** a Soil-N debit. It is an external
crop-N input and is booked once on the crop-N side. The B1.11 fixation-demand
policy is separate from the already admitted WOFOST81 policy, because literal
source evidence distinguishes the DVS cutoff, storage-demand treatment and
new-growth demand.

## Transaction and restart consequences

A rejected hydraulic/crop/management attempt cannot mutate committed Soil-N.
Reaction, transport, crop exchange and management additions are candidate
transfers until the enclosing attempt is accepted.

Restart persists every inventory that can affect a later accepted result.
Derived concentrations, rate constants and temporary reaction/transport
workspace are recomputed unless a later source-bound contract proves that they
carry physical history.

## Solute separation

The existing mobile-salt owner remains a separate conserved constituent owner
on the nodal soil-water grid. It is not reused as the WOFOST Soil-N inventory
merely because both have transport. B1.11 `Wofost_SoilWaterN` advances the
aggregated SoilManagement NH4/NO3 concentrations using aggregated water-flux
receipts, while the general solute model advances nodal mobile constituent
mass. The two routes may consume water information from the same accepted
hydraulic trajectory, but they do not share a mutable solute store.

## Consequences

This decision establishes the state/owner foundation for MC-NUT01. It does not
by itself admit the B1.11 organic, mineral, amendment, residue, reaction,
transport or crop-exchange equations. Each equation family still requires a
source-bound oracle and bounded production qualification.

It also fixes the N-fixation integration rule: the legacy B1.11 demand policy
may be added as an explicit separate policy, but the admitted WOFOST81 demand
equations remain unchanged.

## Affected invariants

- committed/candidate state separation;
- rejected trials do not mutate persistent physical state;
- one owner per conserved store;
- explicit mass inputs/outputs and hard mass closure;
- restart reconstructs all persistent physical state;
- physical option semantics remain separate from numerical execution policy.
