# Draft F-KT boundary event contract

The generic event and incumbent FKT22 contracts have executed at O0/O2.
This remains a draft without crop harvest or rotation qualification.
The synthetic fixture transfers two units out of a stock and requires its
water/history and certificate to remain unchanged. The real production executor
owns provenance, balance refusal, staging and publication. The synthetic owner
does not establish WOFOST81, actual Richards or whole-N harvest correctness.

Use `python -B tests/fkt-boundary/check_source_projection.py` for source-only
comparison with the unchanged kernel body. Use
`python -B tests/fkt-boundary/run_boundary.py --plan-only` to inspect the real
module closure. Neither command is compiler or numerical evidence.

To repeat after persisting a candidate with a working gfortran toolchain, run `python -B tests/fkt-boundary/run_boundary.py --output <fresh-dir>`.
It selects O0/O2 boundary tests and the original FKT22 kernel trajectory test,
with fresh compilation, separate module directories, runtime/FP traps and all
original assertions. It never downloads a compiler or dispatches Actions.
Missing compiler returns status `BLOCKED_COMPILER_UNAVAILABLE`, exit 2, no PASS.
Failed compilation, linking or native assertions retain their raw outputs.

No current production model opts into this boundary API. Before any canonical
admission, complete the shared-owner decision and implement an actual owner with physical
event receipts, complete balances and persistent anti-replay state. Actual crop/soil-N/Richards composition, fresh-process native persistence and
affected owner preservation remain open. Generic event/interval candidate and
checkpoint invalidation, opaque copy continuation and trusted reconstruction of
the synthetic state have passed. The fixture uses monotonically increasing event
identities and a persisted high-water mark; this is not a generic event journal.

The boundary seam now requires an original valid parameter certificate even when
the legacy interval seam permits uncertified models. Missing event certificates
fail closed. Four independent balance channels and revision overflow are tested.
Run `python -B tests/fkt-boundary/verify_evidence.py` to verify retained execution
and current scientific source hashes without executing new numerics. It does
not establish physical owner qualification or canonical admission.
