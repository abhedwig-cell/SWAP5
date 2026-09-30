# PPA-WU05-A3 E9 local extreme-rainfall stress result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / BOUNDED_REDUCED_R1_BUDGET / NOT_CALIBRATION`

## Purpose

Stress the reduced R1 bookkeeping under increasingly large top input without interpreting any one forcing as a calibrated or recommended rainfall event.

Checks:

- no negative macropore storage;
- storage never exceeds capacity;
- internal matrix absorption is booked once;
- rapid drainage is booked once;
- excess/overflow is explicit;
- water balance closes.

## Setup

Initial macropore storage: `0.4 cm`.

Input-rate sweep:

`0, 1, 5, 10, 25, 50, 100, 250 cm d-1`.

The reduced experiment combines:

- E2 sorptivity-shaped absorption;
- E5 positive-head rapid drainage;
- explicit finite macropore capacity;
- explicit excess/overflow.

It does not claim to reproduce all B1.11 top-inflow redistribution logic.

## Results

At low/moderate inflow, no overflow occurs and storage rises smoothly.

At high inflow:

- storage saturates at the imposed `1.2 cm` capacity;
- absorption remains bounded by source-shaped sorptivity demand and available water;
- rapid drainage remains bounded by available water;
- all remaining excess becomes explicit overflow.

Example high-load cases:

- `25 cm d-1`: overflow `~6.80 cm d-1`;
- `50 cm d-1`: overflow `~31.80 cm d-1`;
- `100 cm d-1`: overflow `~81.80 cm d-1`;
- `250 cm d-1`: overflow `~231.80 cm d-1`.

Across the complete sweep, balance residuals remain at approximately machine precision.

## Interpretation

The reduced R1 ownership model is stable under forcing well beyond ordinary use:

- finite storage is authoritative;
- internal absorption cannot create/remove whole-column water;
- rapid drainage remains a single external sink;
- unresolved input is represented explicitly rather than hidden in storage or exchange terms.

This does not yet validate the detailed B1.11 excess-redistribution algorithm.

## E9 disposition

`PASS_REDUCED_EXTREME_LOAD_BOOKKEEPING`.

The next research phase should preserve this bounded ownership behaviour when the real coupled process implementation is introduced.
