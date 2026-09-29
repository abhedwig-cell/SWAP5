# F-PE-ELASTIC10 — BRO BHR-GT mechanical target acquisition

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_BHR_GT_ACQUISITION

## Purpose

Acquire independent Dutch soil-mechanical target information for a physically based
ELAS prior or pedotransfer study.

This workunit exists because:
- Staringreeks/BHR-P hydraulic data contain useful soil descriptors but no direct
  elastic-storage target;
- BRO BHR-GT explicitly contains geotechnical borehole sample analyses including
  stepwise compression/settlement determinations.

The aim is to determine whether BHR-GT can supply source-bound mechanical
quantities that can be converted to or constrain SWAP ELAS.

## Authoritative external source

BRO product:
`Geotechnisch booronderzoek (BHR-GT)`.

Current BRO documentation states that the BHR-GT catalogue contains determination
of settlement/compression properties, including stepwise compression tests and
associated load/deformation observations.

Official public BRO REST/XML services are the acquisition authority.

## Target quantities

Acquire, where present and source-bound:

- specimen depth/interval;
- dry or wet bulk density;
- water content;
- soil classification/composition;
- vertical stress/load sequence;
- vertical strain/deformation sequence;
- preconsolidation/yield stress if supplied;
- recompression/swelling or unload-reload observations if supplied;
- compression/recompression index if directly reported;
- constrained/oedometer modulus if directly reported;
- test saturation/moisture state;
- determination method/procedure;
- specimen disturbance/quality metadata.

No quantity may be inferred from field names without schema/catalogue binding.

## Primary research questions

1. Does current BHR-GT expose sufficient unload/reload or low-strain information
   to estimate an elastic/recompression compressibility rather than only virgin
   compression?
2. Can a source-bound constrained modulus or recompression index be obtained
   directly?
3. If only load-deformation sequences are supplied, is the stress path adequate
   to distinguish:
   - elastic/recompression branch;
   - virgin compression;
   - unloading/recovery?
4. Are there enough shallow agricultural/mineral/organic samples to overlap the
   descriptor space already observed in BHR-P?
5. Can BHR-GT target records later be linked to BHR-P/Staringreeks-like descriptor
   classes without spatial or semantic leakage?

## Preregistered conversion boundary

A BHR-GT quantity may constrain SWAP ELAS only if its physical meaning is explicit.

For a source-bound one-dimensional elastic/recompression coefficient of volume
compressibility `mv`:

`Ss ~= gamma_w * mv + water_compressibility_term`.

For a source-bound constrained modulus `M`:

`mv = 1/M`.

For a source-bound recompression index `Cr`, conversion additionally requires:

- void ratio/porosity or a defensible source-bound equivalent;
- effective stress;
- confirmation of logarithm convention;
- confirmation that the sample is on the recompression branch.

No virgin compression index `Cc` may be used as ELAS by substitution.

## Acquisition phases

### Phase A — schema audit

Before downloading population data:
- bind the official BHR-GT schema/catalogue names for compression/settlement
  entities;
- identify exact XML/JSON fields and units;
- identify the public search/list endpoints;
- verify which fields represent measured series versus derived parameters.

### Phase B — bounded pilot

Fetch a small deterministic sample of BHR-GT objects containing compression
determinations.

Record:
- BRO ids;
- hashes/byte sizes;
- available mechanical fields;
- depth and soil metadata;
- whether unload/reload information exists.

No fitting.

### Phase C — corpus design

Only after the pilot:
- define inclusion criteria;
- define depth/agricultural/organic coverage goals;
- freeze calibration/holdout objects;
- acquire the bounded corpus.

## Prohibited shortcuts

Do not:
- infer ELAS from hydraulic fit quality;
- regress against solver performance;
- substitute Cc for elastic/recompression compressibility;
- use ambiguous depth joins;
- use modelled geotechnical values as if measured;
- silently merge BHR-GT and BHR-P intervals by nearby location;
- create a universal ELAS value from heterogeneous test methods.

## Success conditions

The workunit succeeds if either:

A. a reproducible, source-bound BHR-GT mechanical target path is established,
with at least one defensible elastic/recompression quantity or recoverable stress
path;

or

B. the current BHR-GT public product is shown to lack the information required
for elastic-storage identification, with that negative result recorded.

## Downstream use

If A succeeds, the next physical workunit will compare BHR-GT-derived mechanical
targets with the already audited BHR-P descriptor classes.

This is independent of ELASTIC05/08/09 software admission.
