# PPA-WU05-A6 R3 clarification — INT means saturated interflow, not inter-domain exchange

Date: 2026-09-30

Status: SOURCE_TERMINOLOGY_CORRECTION

Exact B1.11 MACRORATE calls SATFLOW twice for incoming saturated water:

1. perched/top saturated zone -> FlwInIntSatCpPot / QInIntSatDmCp;
2. main saturated matrix zone -> FlwInMtxSatCpPot / QInMtxSatDmCp.

The INT label refers to saturated interflow from the perched/top matrix zone.

It is not macropore-domain-to-domain transfer.

Therefore A6-R3 does not require a new rate law.

It reuses the qualified SATFLOW evaluator with a second matrix-zone request.

Both QInIntSat and QInMtxSat are matrix -> macropore internal transfers and enter QExc with negative sign.