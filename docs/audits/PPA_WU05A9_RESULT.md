# PPA-WU05-A9 result — source-faithful FMR macropore top input

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline: `integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Qualified code/test postimage: `3e0b0a94512183efbbe0cc1aff997e60d38296ae`

Qualification workflow: `.github/workflows/ppa-wu05a9-top-input.yml`

Qualification run: `36827295266` — SUCCESS

Current branch head after removing a superseded duplicate gate script: `fbc2dde967fe25f03d0ab9c761bc0bbce5fb89b8`. The only delta after the qualified postimage removes `tests/fpm/run_ppa_wu05a9_fmr_top_input.sh`, which was not the active qualification gate and changes no production, test oracle, or active workflow dependency.

## Qualified scope

A9 extends the canonically admitted A8 route with an explicit source-faithful macropore top-input forcing carrier for:

- net rainfall;
- net irrigation;
- melt;
- separately owned lateral overland/infiltration-excess input equivalent to the B1.11 `QMpLatSs` role.

The route remains bounded to:

- standard `swmbf=1`;
- macropores connected to the soil surface;
- serialized single-column FMR;
- Reference Richards;
- A8 outer coupling and transactional state ownership.

## Source mapping

For direct vertical input, A9 implements the B1.11 relation

`ArMpTpDm(id) * (NRaiDt + NIrd + Melt) * dt`

using current top-compartment domain volume divided by compartment thickness as the macropore top-area fraction.

For lateral input, A9 distributes the explicit lateral-overland receipt over domains proportional to their current macropore top area, matching the source role of

`ArMpTpDm(id)/ArMpTp * QMpLatSs`.

A9 does not reconstruct either contribution from generic FMR `top_flux`.

## Mass and ownership

The qualified route preserves these rules:

- matrix top flux and macropore top input are separate external receipts;
- only accepted macropore top input is added to whole-column accepted external mass;
- unaccepted macropore top input is returned through the macropore top receipt and is not silently lost;
- direct and lateral requested amounts remain distinguishable through the limiter/partition path;
- inner Reference Richards remains `macropore_active=.false.`;
- rejected candidates do not mutate committed matrix/macropore state or publish accepted macropore receipts.

## Qualification coverage

The focused O0/O2 gate covers:

- A7 real-Richards preservation;
- A8 zero-top-input macropore preservation;
- source-equation top-input partition;
- multi-domain vertical and lateral distribution identity;
- unsupplied/nonzero and negative forcing fail-closed behaviour;
- covering-layer route fail-closed;
- real serialized FMR wetting trial;
- complete mass accounting and residual tolerance;
- candidate-only publication;
- commit;
- reject/checkpoint replay;
- persistence/restart continuation replay.

Run `36827295266` completed SUCCESS on exact qualified postimage `3e0b0a94512183efbbe0cc1aff997e60d38296ae`.

## Deliberate non-admitted scope

A9 does not admit:

- ponding as an independent direct macropore source;
- runon as an independent direct macropore source;
- derivation of rain/irrigation/melt or lateral overland input from generic `top_flux`;
- synthetic reconstruction of `QMpLatSs` from matrix infiltration or runoff;
- simultaneous A9 top-input ownership with Snow, Black evaporation, Boesten evaporation, or fixed-weir surface-water routes;
- covering-layer `IcTopMp > 1` physics;
- perched-zone macropore physics;
- rapid drainage;
- RossFast;
- parallel/concurrent MultiSWAP.

Those combinations remain fail-closed or outside this claim.

## Lifecycle

implemented -> persisted -> tested -> qualified

Canonical admission and closure are not claimed by this record.
