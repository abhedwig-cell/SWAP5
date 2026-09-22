# GC-RZM06D01 response-blind ROM origin selection

Date: 2026-09-22  
Machine-readable authority: `2af534f0455ceb121f9a7965d1fe9f92895b3e4d`  
Production changes: none

## Purpose

D01 asks whether the already-qualified ROM1AR2 B01 discovery library contains two accepted committed states that satisfy the original H2 state requirement before any coupling response is inspected.

The primary carrier is the C01-qualified 16 x 10 cm Reference profile. The synthetic C02 carrier is closed no-go and is not used.

## Firewall

Only strict `DISCOVERY` states with `FALLBACK=F` are eligible. The held-out ROM population remains excluded.

The selector may read only:

- state provenance, committed time and fallback flag;
- node number, pressure head and water content.

It may not use stored total storage, band storage, exchange, terminal flux, mass, solver work, forcing symbol or bottom-mode fields.

## Reconstructed state observables

For the 16 equal 10 cm cells:

`W = sum(theta_i * 10 cm)`

`M1 = sum(theta_i * 10 cm * z_i) / W`

with node centres `z = -5, -15, ..., -155 cm`.

Upper-30-cm storage is reconstructed from nodes 1 through 3 for description only.

## Frozen H2 gates

RZM06A6 established that the old A-series observables were metre-scale despite historical `_cm` names. Preserving the same physical thresholds on native centimetres therefore requires:

- `|delta W| <= 1e-4 cm`;
- `|delta M1| >= 1e-2 cm`.

Candidate states must also have text-identical and binary64-identical committed time and originate from different histories.

## Selection

All eligible unordered same-time pairs are enumerated. A qualifying pair must pass both H2 state gates.

If multiple pairs qualify, rank by:

1. largest `|delta M1|`;
2. smallest `|delta W|`;
3. lexicographically smallest provenance tuple.

If no pair qualifies, D01 closes `NO_MATCH`. Thresholds are not relaxed, fallback states are not admitted, held-out states are not opened, and no `E_c` probe occurs.

If a pair qualifies, its full 16-node origins are persisted immediately and become immutable input to D02.
