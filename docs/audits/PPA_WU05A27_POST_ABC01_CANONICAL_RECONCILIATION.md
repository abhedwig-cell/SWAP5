# PPA-WU05-A27 post-ABC01 canonical reconciliation note

Date: 2026-10-02

ABC01 qualified on A27 postimage `586cb21a44ff24385718f160adf9d5a6e65e409e`; result/status persistence followed on `88101a49824f2c5304b4606f478b7c6c49f064f3`.

Canonical subsequently advanced through F-MIG431-LOW03-A and modifies the shared `src/runtime/mod_fmr_serialized_reference_backend.f90`.

A reconciliation PR was opened as #980. GitHub reports it non-mergeable automatically because both lines modify the shared backend file.

Targeted source inspection shows the canonical LOW03A postimage still contains the pre-A27 RFM layout and RFM exact temporal-identity branches. The LOW03A changes are therefore not a canonical replacement for DEP01/DEP02. A blind ours/theirs resolution is forbidden.

Current governance state:
- ABC01 scientific result: qualified and persisted.
- DEP01/DEP02/DEP03: qualified branch-local shared-backend repair candidates.
- canonical admission: not claimed.
- current-canonical reconciliation: BLOCKED_ON_EXPLICIT_THREE_WAY_BACKEND_RESOLUTION.
- pressure-aware A27 research seam remains excluded.
- next scientific work: profile RFM trial-preparation/constitutive overhead before further physical tuning.

PR #980 is reconciliation evidence only, not an admission request.
