# PPA-WU05-D2 staged compensation contract

Status: RESEARCH_ONLY_HELD_ON_D1_EXACT_SOURCE

This directory contains a non-production typed transcription of the compensation algebra observed in the recovered later SWAP source family. It exists to make the prospective D2 seam concrete and testable without weakening the PPA-WU05-D fail-closed source rule.

It is deliberately outside `src/`. No production binding imports it.

The contract accepts an already stress-reduced candidate root sink plus current-trial reduction totals. It returns a transformed candidate sink and recomputed current-trial diagnostic totals. It owns no water receipt, persistent physical state, checkpoint state or restart payload.

The gate checks exact OFF preservation, candidate-sum identity, upper bound by potential transpiration, full-capacity recovery, the legacy-family 95-percent-stress guard, and deterministic replay from the same uncompensated candidate.

This is NOT D2 qualification. Promotion into production is forbidden until exact B1.11 `rootextraction.f90` bytes matching SHA-256 `8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5` are materialized and the transcription is reconciled line-for-line against that authority.
