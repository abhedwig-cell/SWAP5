# F-ROM-LARE BC2-C5D closeout

C5D extended the B14 dynamic prescribed-head Richards Reference from R64 to R128 and R256 without changing the workload or numerical policy. No LARE representation was run.

The authoritative run is 35500141508 at execution head 32ca500df7c00c4b9cadafff5dcb06a87dcf8319. Both R128 and R256 pass O0/O2 identity and the unchanged transaction-mass and D13 integrated-water-depth gates. The exact result SHA-256 is 34082ec971a2461a43dae87faa885579b60a37241fff337ccc2c948b21345a50.

Adjacent-grid bottom-flux RMSE is 0.04379 cm/d for R16-R32, 0.04898 for R32-R64, 0.04712 for R64-R128 and 0.04361 for R128-R256. Thus two consecutive reductions appear after R64.

That is refinement progress, but not yet convincing asymptotic convergence. The descriptive observed order is only about 0.056 over R32-R64-R128 and 0.112 over R64-R128-R256. R256 therefore cannot yet be treated as a continuum-like Reference authority.

The correct next step remains Reference-only. C5E extends to R512 and attempts R1024 under exactly the same numerical policy. No new LARE closure or representation is authorized before the Reference behavior is understood.
