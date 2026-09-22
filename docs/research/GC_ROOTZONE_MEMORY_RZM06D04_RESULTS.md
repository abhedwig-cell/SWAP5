# GC-RZM06D04 local strict continuation result

Date: 2026-09-22  
Preregistration: `8de97e12dc9cc50caab3d8808e88caf3db1599c3`  
Qualified workflow: `35740262904`, job `106787866351`  
Production changes: none

## Decision

D04 is qualified as:

`QUALIFIED_LOCAL_STRICT_CONTINUATION_NO_MATCH__H2_NOT_PROBED`.

## Frozen origins

The two immutable D03 origins were reconstructed at common canonical time under the D02R1 common-time reseed authority:

- A: DISCOVERY D02 step 64;
- B: DISCOVERY D08 step 44.

No response field was used to select or reconstruct them.

## Strict continuation census

For each origin, D04 tested the preregistered seven-control alphabet and five dyadic durations, plus the identity endpoint.

Results:

- 35 non-identity trials attempted per origin;
- 15 admitted endpoints per origin including identity;
- 21 rejected non-identity trials per origin;
- 225 cross-origin endpoint pairs;
- 39 pairs satisfied the unchanged profile-water gate;
- 0 pairs satisfied both H2 state gates.

The strongest water-matched pair was:

- A: `TOP_MINUS`, duration `0.000800000037997961 d`;
- B: identity;
- `|ΔW_profile| = 9.233749912596068e-05 cm`;
- `|ΔM1| = 0.007872748347196534 cm`;
- 78.73% of the unchanged `0.01 cm` M1 requirement.

## Rejected trials

The rejected local continuations are solver-level fail-closed trials. They do not justify extending the frozen grid, changing solver tolerances or relaxing the H2 thresholds.

## Consequence

D04 does not construct an H2 origin pair and therefore opens no E_c probe. The next justified step is a qualitatively different state-space construction rather than further local tuning around the same two origins.

E01 therefore tests zero-divergence redistribution from a common hydrostatic origin using strict Reference sample/commit semantics only.
