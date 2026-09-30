# PPA-WU05-A8 preregistration — production hydraulic views and FMR integration

Date: 2026-09-30

Status: PREREGISTERED / PRODUCTION-INTEGRATION / NOT_ADMITTED

Baseline: PPA-WU05-A7@5669489d854603440702dba4d3e51ea99254572f

Canonical authority: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b.

## Purpose

Remove the remaining prepared-template dependency from the production-shaped macropore runtime and integrate the bounded single-column capability into FMR without changing the inner Reference Richards ABI.

## Phase A — hydraulic view adapter

Derive from accepted macropore state + immutable geometry:
- top water-storage compartment per domain;
- wet fraction per active compartment;
- macropore water level/reference level;
- refined saturated-interface index;
- top saturated fraction;
- drainable geometry views.

Derive from matrix state/column geometry:
- main saturated-zone top/bottom and fraction;
- bounded no-perched-zone route first;
- explicit not-admitted status when perched-zone information is required but unavailable.

## Phase B — immutable production configuration

Introduce one production configuration carrier for source parameters and geometry that contains no continuation state and no numerical coupling history.

## Phase C — FMR adapter

Allow FMR macropore_active only when:
- optional macropore state layout is selected;
- production configuration is present and valid;
- Reference Richards is selected;
- incompatible routes remain rejected;
- runtime uses outer coupling and keeps inner solver macropore_active=false.

## Phase D — qualification

- disabled-path canonical preservation;
- active single-column real Richards;
- reject/retry atomicity;
- restart/replay;
- FMR checkpoint/restore;
- no hidden state;
- Status-A impact review.

## Holds

- no parallel/MultiSWAP claim;
- no perched-zone production claim until explicitly represented;
- no dynamic crack geometry feedback inside one corrector until geometry displacement is coupled into matrix source receipt;
- no canonical admission before exact postimage gates pass.