# GC-RZM06D01 ROM accepted-origin selection result

Date: 2026-09-22  
Preregistration: `2af534f0455ceb121f9a7965d1fe9f92895b3e4d`  
Qualified workflow: `35736968701`, job `106776591287`  
Production changes: none

## Decision

D01 is qualified as:

`QUALIFIED_SAME_TIME_STRICT_DISCOVERY_NO_MATCH__H2_NOT_PROBED`.

The exact ROM1AR2 artifact authority was verified before selection. O0 and O2 logs are byte-identical with SHA-256

`f1ea53496cd08cbadf1ceaad46c78d83a0767957fd9de676c88c51162346a1e0`.

## Selection census

Only strict, discovery-side states were eligible:

- 475 `DISCOVERY`, `FALLBACK=F` states;
- 0 held-out node observables parsed;
- 0 response fields parsed.

Requiring equal committed library time and different histories produced 1549 candidate pairs.

At the unchanged physical H2 gates, converted to native centimetres:

- `|delta W_profile| <= 1e-4 cm`;
- `|delta M1| >= 1e-2 cm`;

the number of qualifying pairs is exactly zero.

No HeadCalc solve or E_c probe was performed.

## Interpretation

This is a no-match for the additional same-library-time control, not an H2 falsification.

Absolute library-generation time is not itself one of the H2 state variables. Before removing that extra control in a new experiment, the pure-hydraulics C01 carrier must demonstrate that an accepted physical profile can be reseeded at a common canonical time without changing the physical one-window response.

That time-neutrality/reseed property is therefore the next qualification target.

The H2 thresholds, discovery-only firewall and strict no-fallback requirement remain unchanged.
