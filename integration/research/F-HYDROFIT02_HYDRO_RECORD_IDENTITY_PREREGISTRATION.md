# F-HYDROFIT02 P-LIDENTITY01 — hydrophysical interval identity correction preregistration

P-LID02 proves that BRO id + begin/end depth is not a unique hydrophysical record identity. Three frozen keys each contain two genuine hydrophysical InvestigatedInterval records with distinct raw hydraulic hashes and source lambdas.

Before rebuilding any corpus, define record identity as:
- BRO id;
- begin depth;
- end depth;
- SHA-256 of the raw WaterContentAndConductivityAtSpecificSoilWaterPotential values string;
- hydrophysical InvestigatedInterval document ordinal retained as provenance, not as primary semantic identity.

Rebuild must preserve both records when hashes differ and collapse nothing solely by depth.

All downstream fetch/lookups must bind frozen corpus rows to XML by hydraulic hash, with source lambda used only as an audit cross-check, never as the matching key.

Before replacement, compare old versus identity-corrected corpus counts and lambda distribution. No estimator result may be silently carried over if case membership changes.
