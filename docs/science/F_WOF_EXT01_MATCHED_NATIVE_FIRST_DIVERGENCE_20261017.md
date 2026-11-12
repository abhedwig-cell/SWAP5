# F-WOF-EXT01: first matched NEW barley Python–Fortran result, 2026-10-17

Research finding; **NOT scientific equivalence admission**.

## Executed runs

- GitHub Actions run [39047163196](https://github.com/abhedwig-cell/SWAP5/actions/runs/39047163196), and subsequent [39047278106](https://github.com/abhedwig-cell/SWAP5/actions/runs/39047278106), both **SUCCESS**.
- 60 model-day transitions with real PCSE-pinned new-barley forcing into the existing SWAP5 WOFOST81 Fortran PP02 test driver, built with GNU Fortran O0/O2, compared against actual Python EXT01 12-field reference.
- O0/O2 native Fortran CSV outputs **byte identical**.
- Compiled and executed; the research report is a diagnostic, not a PASS on science.
- All 61 observed DVS states and all storage-organ dry mass/N states are identical in this bounded period.
- LAI first diverges on **2010-05-06** (state 21), Fortran minus PCSE = **-0.0004639948884571643**.
- TAGP, leaf/root biomass and N uptake first diverge on **2010-05-07** (state 22); TAGP delta = **-0.0064008650550277935**.
- Stems first diverge on 2010-05-13 (state 28).
- Last daily state: TAGP **360.35137145341423 Fortran vs 533.5071863311674 Python** (delta -173.1558148777532); LAI delta -0.2543675730867188; cumulative N delta -4.933043744568067.

## Causal triage priority

The earliest nonzero discrepancy is **LAI one day before the first biomass/N discrepancy**. Therefore investigate the *leaf structural update, expansion/aging and its rate/output timing* on days May 5–7 **before** changing assimilation or N algorithms.

Do not infer that source physiology is defective. Verify one-day forcing phase alignment, exact parameter table expansion, initial leaf cohort metadata, external synthetic RFTRA and CO2 correction timing, and actual leaf rate packet / structural update order. Existing PP01/PP02 original potential-production equivalence is not contradicted by these NEW distinct stress-mode results.

## Admitted claims and nonclaims

- Native external-input Fortran kernel execution: **TESTED**.
- O0/O2 native deterministic output: **TESTED**.
- Same 12-field daily Python vs native Fortran comparison: **EXECUTED, DIFFERENCES FOUND**.
- Scientific or numerical equivalence for new EXT01 stress mode: **NOT QUALIFIED**.
- Full Python internal checkpoint/restart: **NOT QUALIFIED**. Research-only process loss recovery by replay passed.
- SWAP5 canonical and PCSE release source: **UNCHANGED**.

Next coherent test batch: one directly instrumented native/Python May 5–7 leaf cohort/rate trace under identical previous committed state; no tolerance relaxation or production model physics edits before causal root verified.
