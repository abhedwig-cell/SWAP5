# F-MIG431-INT12-E reconstructed contract

Status: RECONSTRUCTED / IMPLEMENTATION AUTHORIZED
Date: 2026-10-03
Canonical base: 89eedb63c65fcf496f2bc14153c31ec57f1d3de4

## Corrected state classification

The preregistered hypothesis that legacy `restint` might be persistent across detailed-meteorology days is falsified.

Legacy `PartitionPrecipitation(...,restint)` explicitly executes `restint = 0` whenever `SWMETDETAIL=1` daily forcing is loaded. Detailed meteorology also disables snow calculations in that branch.

Therefore:
- `restint` is not physical canopy storage;
- it is not continuation across source-day boundaries;
- it is sequential accepted state inside one detailed-meteorology source day;
- restart inside a partially consumed day must preserve either exact accepted `restint` plus record cursor, or enough immutable day forcing to replay the accepted prefix exactly;
- rejected trials must not advance `restint` or record position.

INT12-E chooses explicit accepted intra-day state rather than hidden replay.

## Exact record law for SWINTER=1/2

For a source day with daily interception aggregate `aintc`, daily gross rain `grai=sum(arain)`, record precipitation `arain(i)`, record duration `metperiod`, and incoming accepted `restint`:

- if `grai < 1e-12`: `interc=0; wfrac=0`;
- otherwise `interc = restint + aintc*arain(i)/grai`;
- if `ew0 < 0.0001`: `wfrac=0`;
- otherwise for the non-Rutter family `wfrac=clamp(interc*10/ew0/metperiod,0,1)`;
- candidate next `restint=max(interc-wfrac*metperiod*ew0*0.1,0)`.

Record gross/net rain rates:
- if `grai < 1e-12`: both zero;
- otherwise `grain(i)=arain(i)/metperiod` and `nrain(i)=grain(i)*nraida/grai`, where `nraida` is the daily net-rain amount after legacy DivIntercep.

This means the rain interception reported per record is derived from the daily rain-partition ratio, while `restint` controls wet-canopy availability and ET suppression. These are related but are not the same bookkeeping variable.

## Transaction target

Committed detailed-interception state is:
- source-day identity/bounds;
- next record index or equivalent accepted cursor;
- accepted `restint`.

Trial result is:
- `interc`;
- `wfrac`;
- candidate next `restint`;
- record gross/net rain rates;
- wet/dry potential-transpiration composition.

Commit advances cursor and restint atomically. Reject changes neither.

At the next source-day boundary, accepted restint is reset to zero by forcing-day initialization, matching legacy semantics.

## Scope correction

Snow interaction is excluded from detailed mode because legacy detailed meteorology explicitly disables snow. This is not the daily SWINTER snow gate from INT12-D.

SWINTER=3 remains excluded.
