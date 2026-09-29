# F-PE-ELASTIC10E-R1 — BHR-GT settlement-determination identity reconciliation

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TARGET_AUTHORITY_REBIND

Parent authorities:
- F-PE-ELASTIC10D fixed national-grid object sample;
- F-PE-ELASTIC10E target-extraction preregistration;
- F-PE-ELASTIC11A SWE target-schema binding.

## Trigger

The frozen F-PE-ELASTIC10D readiness classifier used:

`"settlementcharacteristicsdetermination" in norm(local(tag))`.

In current BHR-GT XML this matches both:
- the lower-case wrapper `settlementCharacteristicsDetermination`;
- the physical inner `SettlementCharacteristicsDetermination`.

The historical readiness summary therefore contains two classifier records for
each physical settlement determination.

This is an identity/provenance issue. It is not evidence that the underlying BRO
object contains duplicate physical tests.

## Frozen reconciliation rule

No mechanical target value may be changed or selected during this workunit.

For every one of the 16 already frozen ELASTIC10D objects:

1. take the historical determination records in source order;
2. require an even record count;
3. pair records `(1,2), (3,4), ...`;
4. after removing only the classifier-local `index` field, require both records
   in each pair to be exactly equal;
5. map pair `i` to one physical determination index `i`;
6. retain the common frozen readiness class for that physical determination;
7. fail closed if any pair differs or any record remains unmatched.

The object population, object hashes, owning cells and R2/R3 readiness criteria
remain unchanged.

## Prospective expected counts from bounded pre-audit

The reconciliation pre-audit found:

- historical classifier records: 100;
- physical settlement determinations: 50;
- exact duplicate-pair mismatches: 0;
- physical R2 determinations: 29;
- physical R3 determinations: 21.

These counts are frozen before changing the extractor.

## Extractor binding rule

After reconciliation, F-PE-ELASTIC10E must receive an explicit
determination-level authority file.

For every physical inner `SettlementCharacteristicsDetermination`:

- the XML source-order physical index must exist in the authority;
- its target route must equal the frozen authority readiness R2 or R3;
- the extractor must not silently reclassify a determination;
- structural observations may be checked against the frozen route and must fail
  closed on conflict.

Target records must preserve:
- `object_readiness`;
- `authority_readiness` at physical-determination level;
- physical determination index.

## Numerical preservation gate

The identity correction is provenance-only.

Relative to successful pre-reconciliation extraction run `36531232195`, the
corrected extraction must preserve the complete numerical target tuple set:

- BRO-ID;
- physical determination index;
- route;
- step index;
- stress endpoints;
- strain endpoints;
- signed deltas;
- mv;
- Ssk in m^-1 and cm^-1.

Expected:
- valid targets: 47;
- R2 valid targets: 29;
- R3 valid targets: 18;
- rejected R3 zero/nonpositive secants: 3.

Metadata fields may become more precise; numerical target values may not drift.

## Scientific boundary

This workunit does not:
- add/remove BRO objects;
- change extraction formulas;
- relax T1-T5;
- discard extreme targets;
- fit a predictor;
- choose an ELAS default.

## Success condition

Identity reconciliation is qualified only when:
- all 100 historical classifier records reduce to 50 exact physical identities;
- route counts are 29 R2 and 21 R3;
- corrected extractor consumes that frozen authority;
- corrected target numerical postimage matches the prior green target corpus.
