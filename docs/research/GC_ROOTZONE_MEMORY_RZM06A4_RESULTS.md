# GC-RZM06A4 stronger top-forcing result

Date: 2026-09-22  
Preregistration: `67e6cf09aa870c77cbb5059a834c2c6e14632a93`  
Implementation: `136f8ee7317a4185c6d32e79c70cfd514018a174`  
Qualified workflow: `35729367528`, job `106750827132`  
Production changes: none

## Decision

RZM06A4 is qualified as:

`QUALIFIED_FORCING_SCALE_FALSIFICATION__H2_NOT_PROBED`.

The CI gate passed, but no preregistered Stage 1 point was admissible in both top-flux directions. Stage 2 and the H2 response probe therefore remained closed exactly as preregistered.

## Stage 1 result

The frozen grid covered amplitudes from `1e-3` to `1e-1 cm d^-1` and durations `0.01`, `0.005` and `0.002 d`.

All 21 amplitude-duration points failed the two-sided admissibility criterion. The failures are dominated by temporal retry exhaustion, with small solver-rejection counts. Failed trials preserved the committed origin and no accepted mass defect was observed.

This is not a technical CI failure. It is a qualified numerical-envelope result for the serialized-reference carrier.

## Reconciliation with earlier evidence

Earlier qualified RZM06A infrastructure had already established that:

- `±1e-4 cm d^-1` at `0.01 d` is individually admissible from the baseline origin;
- the `-1e-4 -> +1e-4` order is admissible, while the reverse order is not;
- `±1e-5 cm d^-1` at `0.01 d` is admissible in both orders.

RZM06A4 therefore started above the relevant transition zone. The frozen grid is not extended post hoc.

## Consequence for H2

H2 remains open. No state pair satisfying the unchanged water and distribution criteria was constructed, and no E_c response was inspected.

The next experiment should not require a sign reversal. A stronger and cleaner construction is to apply the same admitted into-profile pulse either early or late in an otherwise identical fixed-H_c history. Both trajectories then have:

- the same H_c;
- the same endpoint time;
- the same prescribed total top-water input;
- no direct state mutation;

but different redistribution age. That directly targets vertical-distribution memory.
