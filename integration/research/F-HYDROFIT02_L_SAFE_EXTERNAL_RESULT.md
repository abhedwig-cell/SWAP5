# F-HYDROFIT02 P-LSAFE02 external BRO validation result

Authority run: `36523469252`, head `81831918cc46fbe8752bf380e1027cc4d9f5d47c`.

Artifact: `11014232274`, digest `sha256:50aae449f188fb67fdcd296fbcaa7ebcd0fd73bbf255e64eece01a59c988de00`.

## Acquisition outcome

The preregistered national deterministic BRO search completed without acquisition incompleteness:

- 182 spatial search queries;
- 70 unique BRO ids discovered;
- 9 training BRO objects excluded by object identity;
- 61 independent BRO ids inspected;
- 0 unresolved capped cells;
- 0 search errors;
- 0 persistent object-fetch failures.

No spatial subdivision was required because no search cell hit the BRO result cap.

## Independent validation corpus

After applying the frozen preregistered eligibility criteria to all 61 independent BRO objects:

- eligible independent BRO objects: 0;
- eligible independent hydrophysical records: 0;
- unique eligible hydraulic hashes: 0.

Therefore no P-LSAFE01 estimator fit was executed on independent validation records.

## Disposition

The preregistered evidence-size rule classifies this result as:

**INSUFFICIENT_INDEPENDENT_BRO_EVIDENCE**

This is not an estimator failure and not an external replication success.

P-LSAFE01 remains qualified only on the identity-correct frozen 31-record research corpus. P-LSAFE02 does not provide an independent estimate of failure frequency, fallback frequency, objective-loss distribution or transferability because the official BRO population found by the frozen search contains no additional object-independent records satisfying the same hydrophysical Mualem-van Genuchten eligibility contract.

## Scientific consequence

The current BRO service cannot, under the frozen P-LSAFE02 selection rule, provide the preregistered independent external sample required for stronger validation.

Do not relax survey-purpose, modelling-method or hydraulic-record criteria after seeing this result merely to obtain a larger sample. Any broader population definition would constitute a new study population and requires a separate preregistration.

The appropriate next diagnostic is an availability audit of the 61 independent objects to establish why they are ineligible. That audit may classify exclusion reasons but must not retroactively alter P-LSAFE02 membership.

## Qualification state

- P-LSAFE01: `QUALIFIED_RESEARCH_ESTIMATOR_ON_FROZEN_31`.
- P-LSAFE02 external replication: `INSUFFICIENT_INDEPENDENT_BRO_EVIDENCE`.
- Production admission: not supported.
