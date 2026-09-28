# F-HYDROFIT02 — BRO BHR-P acquisition preregistration

Status: PREREGISTERED  
Authority: `integration/f-ci-canonical@f670e012ab028cc1e74bb9b7aa1b8655b545619c`

## Goal

Build a reproducible, research-only acquisition path from the official public BRO BHR-P service to immutable raw source records and normalized HYDROFIT observations.

The first target is one real BHR-P record containing soil-water-potential, volumetric-water-content and hydraulic-conductivity observations. Scaling to the Staringreeks 2018 campaign follows only after one end-to-end record is proven.

## Source authority

Only official BRO public-service responses are raw-data authority for this workunit. Search-engine snippets, reports and derived tables may identify candidate records but may not substitute for the downloaded registration object.

Every downloaded response must record:

- request URL/operation;
- retrieval timestamp in UTC;
- HTTP status;
- content type;
- SHA-256 of raw bytes;
- BRO registration-object identifier when present.

Raw bytes are never silently rewritten.

## Acquisition stages

A0. Probe official public BHR-P service endpoints and document reachable operations.

A1. Identify at least one real BHR-P registration-object ID without inventing IDs.

A2. Fetch that object and preserve raw XML/JSON bytes as a CI artifact, not committed source data unless licensing/provenance review explicitly permits it.

A3. Parse only namespace/local-name structures established by the official response.

A4. Extract candidate hydraulic states with:
- soil water potential;
- volumetric water content;
- hydraulic conductivity;
- units and qualifiers where present;
- parent sample/analysis identifiers.

A5. Reject or explicitly mark incomplete states. Never fabricate K for retention-only observations or theta for K-only observations.

A6. Emit normalized CSV/JSON plus a provenance manifest.

## Parser rules

The parser must:

- tolerate XML namespace-prefix changes by using namespace URIs/local names rather than hard-coded prefixes;
- preserve original numeric strings alongside parsed values where useful;
- fail on ambiguous units;
- distinguish absent from explicit nil values;
- never infer pressure-head sign or unit conversion without source metadata or a separately documented BRO semantic rule.

## Network behaviour

The downloader must use bounded timeouts, a descriptive user agent and finite retry count. It must not crawl the BRO service aggressively.

Enumeration/discovery is a separate operation from object retrieval.

## Gates

B0. Service probe succeeds from GitHub Actions or records a concrete network/API blocker.

B1. At least one non-invented BHR-P ID is discovered from official output or an authoritative WUR/BRO source.

B2. Raw object retrieval succeeds and SHA-256 is recorded.

B3. Parser extracts at least one hydraulic observation from the real object, or records that the chosen object lacks such observations.

B4. A parser fixture test demonstrates namespace-prefix independence.

B5. No production SWAP code changes.

## Relation to F-HYDROFIT01

F-HYDROFIT01 synthetic fitting/solver results were produced against earlier canonical authority. Since BOFEK00 wet-regime corrections are now admitted in canonical, any future solver-side claims using real fitted soils require requalification against the current authority. F-HYDROFIT02 itself concerns data acquisition and is independent of that requalification.
