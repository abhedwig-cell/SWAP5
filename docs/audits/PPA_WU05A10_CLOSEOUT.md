# PPA-WU05-A10 closeout — canonical FMR macropore rapid drainage

Date: 2026-10-01

Status: `CLOSED_CANONICAL_ADMITTED`

Decision: `CANONICALLY_ADMITTED_FMR_MACROPORE_RAPID_DRAIN`

## Canonical evidence

- qualified code/test postimage: `2714c755c50e1ea1ea3bb4e6fc466ce21c9f4e80`
- focused qualification run: `36829166995` — SUCCESS
- admission PR: #928
- canonical admission merge: `190dad36a821f3a43f78f00fccf827c58cacedb6`
- post-merge preservation run: `36829313469` — SUCCESS on that exact canonical merge

## Closed capability

The canonically admitted serialized single-column Reference-Richards macropore route now includes source-bound rapid drainage for the main macropore domain.

A10 reuses the existing A6 B1.11 RAPIDDRAIN equation implementation. It adds production composition only:

- immutable rapid-drain topology and resistance configuration;
- dynamic reconstruction of top-water node, saturated top fraction, water level, ponding, active main-domain bottom and main-domain volume;
- exact reconstruction of macropore volume below the drain level when that drain level lies on a compartment boundary;
- storage-limited multi-compartment drainage;
- one external accepted rapid-drain outflow owner in whole-column mass accounting.

A9 source-faithful top input may be active simultaneously.

## Qualification evidence

The A6 source oracle remained green. An unaligned drain level was explicitly falsified and rejected by production configuration validation.

The real serialized FMR trial produced:

- rapid drainage: `0.11121147871735207 cm`;
- whole-column mass residual: `-0.33306690738754696E-15 cm`.

The active reject/restart/replay case produced:

- zero mass rejections;
- zero solver rejections;
- whole-column mass residual: `-0.94368957093138306E-15 cm`;
- exact candidate replay and restart continuation within the qualified deterministic fixture.

The same O0/O2 gate preserved A7, A8 and A9.

## Preserved contracts

- inner Reference Richards remains `macropore_active=.false.`;
- rapid drainage is external, not internal matrix/macropore exchange;
- rejected trials publish no accepted rapid-drain receipt;
- rejected trials mutate no committed physical state;
- the seven-field macropore continuation state remains unchanged;
- rapid-drain configuration is immutable physical configuration;
- dynamic rapid-drain hydraulic quantities are recomputed views;
- A8/A9 zero-rapid behaviour is preserved.

## Explicit non-admitted scope

A10 does not admit:

- perched-zone macropore physics;
- drain levels cutting through a compartment;
- multiple rapid-drain levels;
- fixed-weir or Ribasim ownership of the same rapid-drain receipt;
- dynamic crack-geometry displacement feedback inside one corrector;
- RossFast macropore execution;
- parallel/concurrent MultiSWAP macropore execution.

These remain future bounded workunits.

## Lifecycle

`implemented -> persisted -> tested -> qualified -> canonically admitted -> closed`

PPA-WU05-A10 is closed. Further expansion must use a new workunit.

The frozen Status-A review denominator is unchanged; A10 is a post-Status-A canonical capability.
