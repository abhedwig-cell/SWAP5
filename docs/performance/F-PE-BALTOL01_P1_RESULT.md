# F-PE-BALTOL01 P1 result — integrated-depth numerical-floor scaling

Date: 2026-09-26

Status: `DEPTH_SCALED_FLOOR_DOMINATES_FIXED_RATE_CANDIDATES`

## Protocol

The exact P0 240-point dynamic physical matrix was rerun under:

- FIXED_1E12;
- DEPTH_2P8E16: `tol_rate=max(1e-12,2.8e-16/dt)`;
- DEPTH_5E16: `tol_rate=max(1e-12,5e-16/dt)`;
- DEPTH_1P1E15: `tol_rate=max(1e-12,1.1e-15/dt)`;
- FIXED_1E10.

## Result

| arm | completed | recovered strict failures | lost strict successes | rate-tolerance range (cm/day) |
| --- | ---: | ---: | ---: | ---: |
| FIXED_1E12 | 113/240 | 0 | 0 | 1e-12 |
| DEPTH_2P8E16 | 240/240 | 127 | 0 | 2.8e-12 to 4.48e-11 |
| DEPTH_5E16 | 240/240 | 127 | 0 | 5e-12 to 8e-11 |
| DEPTH_1P1E15 | 240/240 | 127 | 0 | 1.1e-11 to 1.76e-10 |
| FIXED_1E10 | 240/240 | 127 | 0 | 1e-10 |

All scaled candidates recover the full matrix.

## Physical overlap

For DEPTH_2P8E16 versus the strictest successful solution of the same physical point:

- max |dh| = 5.95e-13 cm;
- max |dtheta| = 1.67e-16;
- max terminal-flux difference = 8.88e-12 cm/day;
- no strict 1e-12 success is lost.

The looser scaled and fixed arms do not materially improve this physical envelope.

## Interpretation

The strongest candidate is therefore not the fixed 1e-10 rate tolerance.

The smallest historically anchored integrated-depth floor, 2.8e-16 cm, already removes all observed rate-floor failures while remaining maximally conservative in rate-space.

This directly aligns with the admitted PUB-P2E07 authority that the dominant numerical floor is controlled by representable theta-state resolution and approximately constant integrated depth rather than by a fixed residual rate.

## Decision

Advance only `DEPTH_2P8E16` to P2 oracle recovery.

P2 must rerun the TEMPORAL03 8/16/32 certificate-free fixed-substep oracle using:

`tol_rate=max(1e-12 cm/day, 2.8e-16 cm / dt)`

and demonstrate actual refinement behavior before any production-policy admission.

No production source change is authorized by P1.