# GC-RZM06C01 richer carrier result

Date: 2026-09-22  
Preregistration: `11ae66fb732e404cf9f51391c693a1db21e2470a`  
Qualified workflow: `35735461762`, job `106771442057`  
Production changes: none

## Decision

C01 is qualified as:

`QUALIFIED_EXISTING_16NODE_FIXED_HEAD_REFERENCE_CARRIER`.

This supersedes the earlier C01 reconciliation conclusion in commit `b9a74963...`, which had missed the existing F-ROM1A-I0 carrier and retained ROM1AR2 artifact.

## Qualified carrier

The selected carrier is the F-ROM1A-I0 B01 pure-hydraulics Reference profile:

- 16 nodes;
- 10 cm layers;
- 160 cm total depth;
- three separately resolved nodes in the upper 30 cm;
- real HeadCalc through the serialized Reference backend;
- explicit B110 MvG hydraulics;
- mode-5 prescribed lower head;
- strict sample interval `0.0008 d`;
- hard mass gate `1e-12 cm`.

The current-branch gate derives the B01 baseline pressure head

`h0 = -29.793709016906497 cm`

and, with the lower face at `-1.6 m`, the fixed coupling head

`H_c = -1.8979370901690651 m`.

The existing groundwater-head materializer maps that H_c back to the intended mode-5 bottom pressure head.

## Transaction qualification

The gate demonstrates on both O0 and O2:

- exactly one strict physical Reference advance;
- zero automatic transaction retries;
- complete mass accounting;
- the uncommitted sample leaves the committed origin unchanged;
- discard leaves the origin unchanged;
- explicit commit advances exactly one revision and one sample interval;
- a controlled nonconvergent prescribed-head sample leaves revision, time and physical state unchanged;
- byte-identical O0/O2 output.

## Existing accepted-state authority

The previously qualified ROM1AR2 artifact remains available:

- workflow `35379176697`;
- artifact `10561841507`;
- digest `sha256:2b04e188b7ce1593e073031fc43580550513e857dfb74b9993844a3230a1a67f`;
- 768 accepted B01 states;
- 16 node records per state;
- 711 strict no-fallback states;
- 57 research-fallback states;
- exact O0/O2 byte identity.

No H2 state-pair values have been inspected in making the C01 carrier decision.

## H2 unit correction

RZM06A6 established that the old A-series state observables used metre-scale geometry despite historical `_cm` field suffixes. Therefore preserving the physical H2 criteria on a centimetre-native carrier means:

- profile-water match: `1e-6 m = 1e-4 cm`;
- M1 separation: `1e-4 m = 1e-2 cm`.

Future C-series pair selection must use these converted numbers.

## Parallel C02

The separately preregistered 17-node native-cm F-GC-compatible bridge remains useful as a secondary cross-check. It is no longer needed to establish that a richer repository-native carrier exists.

C01 itself does not test H2 and makes no production-admission claim.
