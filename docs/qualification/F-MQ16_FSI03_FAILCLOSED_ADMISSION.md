# F-MQ16 — F-SI03 fail-closed admission barrier

F-MQ16 records the exact admission boundary after F-MQ15.

Observed upstream source:

- F-SI03 branch: `work/f-si03-reference-binding`
- observed head: `5bb86d267b8f80ce40e33e78b4d29a35ea3d83d3`
- new adapter: `src/adapter/mod_reference_richards_legacy_binding.f90`
- adapter blob: `84366a4b312a86806cc3aa78a7257c3a7a95d2f1`
- source-bound workflow run: `34120806552`
- conclusion: `failure`

The failure occurs in the strict qualification-test compile gate: direct `REAL(8) == 0.0_real64` comparisons are rejected by `-Werror=compare-reals`. F-MQ therefore does not consume F-SI03 as qualified downstream evidence.

The adapter itself is promising but intentionally incomplete. It projects candidate state, retry status and diagnostics while restoring legacy globals after a trial. Physical unrounded mass remains unavailable in this binding (`NaN`), macropore and implicit-conductivity routes are deferred, and no parallel MultiSWAP backend is qualified.

Consequently F-MQ16 performs no coverage promotion. The matrix remains 27 synthetic executable, 0 real-physics executable and 0 production-runtime qualified rows. F-MQ15 common-layer P06/P19 evidence remains valid but is not upgraded to reference-Richards evidence.

Admission may resume only after F-SI03 has a green source-bound gate and a formal qualification postimage with exact provenance.
