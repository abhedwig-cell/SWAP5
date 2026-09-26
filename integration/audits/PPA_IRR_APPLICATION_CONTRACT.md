# Restricted irrigation application contract

Status: branch-local implemented and qualified in bounded fixtures; not canonical
admission or complete SWAP4 management coverage. Consolidated at `e2ebb40f2`.
Latest executable postimage: `52189a2af`. Detailed gates and earlier postimages:
[owner status](PPA_IRR_EVENT_OWNER_STATUS.json).

## Scope and authority

`src/adapter/mod_ppa_bootstrap_irrigation.f90` composes existing scheduled
TCS7/TCS8, direct DCS2 or supplied-profile DCS1, water-only single-node SSDI and
the explicitly opted-in mode-7 bootstrap. Profile geometry, crop requests and
management tables are supplied inputs, not internally generated crop state.
The committed irrigation carrier retains pending rate/start/end alongside
hydraulic state and temporal history. The kernel/runtime alone publishes state.
Preparation snapshots, returned forcing and diagnostics are not state owners.

## Execution entry points

| Entry | Contract |
| --- | --- |
| `execute_ppa_bootstrap_irrigation` | Exact common interval; preparation failure rejects the batch before execution. Hydraulic acceptance/publication remains per column. |
| `execute_next_ppa_bootstrap_irrigation` | Copy requests and follow strictly interior split hints, at most column-count-plus-one preparation attempts. Execute at most one prefix. Return its attempted endpoint, not a guarantee of commitment. Any hydraulic result, including mixed failure, ends this call. |
| `execute_window_ppa_bootstrap_irrigation` | Bounded sequence of independently published prefixes. Caller guarantees constant supplied configuration/profile and non-irrigation forcing throughout the window. Selection opportunity is consumed only on the first prefix. Actual effective forcing is carried forward to detect source stops. |

Window results contain each attempted prefix endpoint and its per-column results.
`prefix_count` counts attempted prefixes, not successful ones. Only entries up to
that count are meaningful. A failure can leave earlier prefixes and some columns
of the last prefix committed. This API is **not whole-window atomic**.

`FMR_APP_BOOT_OK` means the requested window completed. Adapter-local
`PPA_IRR_WINDOW_BUDGET_EXHAUSTED=-1` means successful prefixes remain durable but
the window is incomplete. Invalid input and runtime failures retain bootstrap
status values. Zero budget rejects without execution. Inspect column results
and committed times before resuming; do not replay an obsolete common interval
after mixed publication. Explicit resume supplies appropriate previous forcing
and must not repeat an already consumed selection opportunity.

Optional preparation reports distinguish process evaluation, source readiness
and process split diagnostics. Unvisited columns are explicitly unevaluated.
Source readiness is not hydraulic acceptance. Optional effective-forcing output
is a detached preparation result, not proof that any column committed it.

## Qualified evidence

The owner runner's IrrigationSource scope at `52189a2af` passes clean O0/O2
builds, static checks and exact transcript identity. Same binaries pass
HydraulicCopy and guards with transcript identity. Tests cover selected/pending
events, source stop, descending split hints, homogeneous and heterogeneous
profile/direct columns, per-column mixed rejection, internally progressed trial
rollback, decoded fresh-owner restart, bounded window resume and explicit/manual
window identity. Hard mass residual limit remains `1e-12`; tolerances were not
relaxed. Each claim remains limited to its recorded fixture/dependency surface.

## Open boundaries

- Generic calendar/parser ingestion, automatic changing crop/root geometry and
  persistent management-configuration identity are not qualified here.
- Surface delivery, solute transport, groundwater composition, mixed opted-in
  and ordinary batches, general layout admission and disk codecs remain separate.
- Initial zero-source and half-length numerical failures remain recorded and
  unresolved. These passing fixtures do not establish universal robustness.
- Whole-migration closure and canonical integration require their own evidence;
  the frozen Status-A denominator is unchanged.
