# PPA-WU05-MIGMAC01 root-extraction composition preregistration

Date: 2026-10-02
Status: PREREGISTERED_CROSS_PROCESS_ADMISSION_REPAIR
Owning head observed before preregistration: 14e1c76b59e310c094ac8ec106d7c92377f02325

The frozen corrected B1.11 source event contains non-zero root extraction
(maximum absolute qrot about 1.0251885e-5 cm/day).

The direct typed Richards request already composes the source/sink provider with
the root-sink provider and, after the provider short-step migration, converges
with positive covered matrix-to-macropore transfer.

The serialized backend already implements the same ownership split when
root_extraction_active is true: qrot is removed from the generic source/sink
provider, bound through b110_root_sink_provider_t, and exposed as
request%evaluation%root_sink. Its forcing validation also has an explicit
root-extraction-active branch.

However, fmr_serialized_execution_admitted still rejects every
macropore_active parameter set with root_extraction_active=true. This is now the
only demonstrated reason the source-backed transaction fixture cannot represent
the frozen event.

Bounded repair: remove only that stale mutual-exclusion clause for the Reference
macropore route. Do not change root uptake equations, macropore equations,
forcing, tolerances, timestep, source reduction, or ownership.

Falsification:
1. run the exact frozen corrected-source transaction with root_extraction_active;
2. require completed mass-closed candidate;
3. require committed state unchanged before commit;
4. require discard/replay identity;
5. require commit publication and persistence/restart identity;
6. retain the repair only if those gates pass.

This does not admit snow, temperature, evaporation, drainage-response or
RossFast combinations with macropores.
