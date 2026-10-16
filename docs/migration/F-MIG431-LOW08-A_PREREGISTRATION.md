# F-MIG431-LOW08-A — ordinary lysimeter-plate application adapter

Status: CENTRALLY_PREREGISTERED_OFFICIAL_BRANCH_ISSUED

Baseline: `d6a9e5a9edfec92d463ad0e30b4b5b6a39e9511c`.

Consumes canonical-admitted LOW08-P0. Scope is the ordinary, non-groundwater-owned production application for SWBOTB=8, Reference SWKIMPL=0, homogeneous bare/non-macro profile.

The immutable application configuration supplies hplate through the existing forcing `bottom_head`; input `bottom_flux` must be zero. No time table, proposal provider, groundwater datum, ledger owner, public ABI or restart schema is added. The active set remains solve-local LOW08-P0 state and is reselected for every physical solve/retry from that solve's first-residual state.

Qualification must cover active/inactive application E2E, threshold crossing between accepted steps, retry/rollback/replay, fresh-backend Restart-v1 continuation, A/B/A forcing isolation, exact-once bottom-flux accounting and preservation of admitted lower-boundary applications.
