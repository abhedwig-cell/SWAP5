# Four original no-macro process mixtures

Windows actual production qualification on canonical6136101463762b1dd18419fe0260965eccd482c7. No app/src/reference/tools final-tree changes. This adds verification and retained observations, not a release or whole-science claim.

| Derived case | Full O0/O2 | Exact native windows | SWAP5 O2 seconds | Original431 seconds | Max GWL difference cm |
| --- | --- | --- | ---: | ---: | ---: |
| water-plate-history | 1096/1096 | 8/8 | 6.829 | 2.779 | 0 |
| chemical-plate-history | 1096/1096 | 8/8 | 6.961 | 3.069 | 0 |
| water-surface-history | 1096/1096 | 6/8 | 5.446 | 3.176 | 2.70681039201 |
| chemical-surface-history | 1096/1096 | 6/8 | 5.663 | 2.859 | 2.70681039201 |

Every case first passed a5-day generated O0 trial and exact own2to4. Eight full SWAP5 trajectories (8768days), four original431 trajectories (4384days),32full-run native windows and four short windows were actually executed. Original provider remains O2; O0/O2 applies to touched generated donor and kernel. Compile time is separate from the model/controller times above. Original standalone times exclude compilation.

All full daily water and kernel residuals remain <=1e-10cm; solute <=1e-10mg/cm2. Observed maxima across all variants are water1.6611712005953905e-13cm and solute2.7711166694643907e-13mg/cm2. No tolerance or numerical-policy change. Inputs and original/compiler/build/executable identities are preserved in the reports and raw archives.

## Retained native failure

The plate/hysteresis2/snow combinations pass all eight full-run native windows each. Both surface/hysteresis2 combinations fail199to201 at both optimizations: physical daily rows, CSV and native result.end are EXACT, but macro.bin differs at six bytes in original MOD_top.h0max. Warm h0max=0.197938023450583cm; cold=0.2cm. The other six windows per case are exact. These are four real exact-restart FAILs, not numerical noise or a passed restart. The initial driver stopped on that assertion; finish.py consumed the existing complete O0 histories without rerunning them, executed only missing O2 histories/references/windows and kept the original failed verdict.

Source audit identifies a candidate missing carry: BoundTop sets h0max from variables.pondmx, while PondRunoff updates pondmx only when called. The current initialized top codec stores h0max and seven other module fields, but not variables.pondmx. This is a causal hypothesis, not an implemented repair. Next test must observe actual warm/cold pondmx around199 and201; do not reconstruct it from h0max, clip a value, ignore six bytes, or weaken native equality.

## Original431 comparison and scientific disposition

All four unmodified original executables complete1096days with the same hash-bound executed input decks. Both engines receive the already documented output-only vocabulary/precision preparation: existing original CSV groups, SWMONTH0, NUM_DECIMALS12. No physical input differs between the engines. The old distributed S_CONC literal-output failure is retained in the admitted M evidence; it is not silently relabelled here.

Complete daily dates and1097CSV rows align. Raw maxima and dates for every common numeric column are in SUMMARY.json. The plate cases have zero reported GWL difference but up to0.075786728604cm WTOT difference; chemical stored-solute difference is0.018579928391mg/cm2. Surface cases have GWL2.706810392011cm, WTOT0.122125309420cm and chemical stock0.053796394726mg/cm2 differences. These are reported observations, not evidence of scientific equivalence. Original BALDEV differences0.025930846624/0.031255684224cm remain separate raw cumulative-output diagnostics; they are not substituted for independently qualified reference accuracy or the strict SWAP5 daily ledger.

Whole scientific qualification remains NOT_QUALIFIED, including prior oxygen/reference failures. No new scientific acceptance threshold was created. Functional yield: two newly passing derived compositions, zero new independent historical projects, two precisely localized native-failing compositions.

## Reproduce

```powershell
python -B tests/nomacro_mixtures/run.py --reference-work C:\SWAP5-RC2\provider --output <fresh-directory> --model-cap 60 --reference-cap 20
python -B tests/nomacro_mixtures/finish.py <same-directory> C:\SWAP5-RC2\provider
```

The first command intentionally returns failure when the exact-native assertion fails. Use the second only on that existing directory: it preserves the failure and finishes independent checks, not a new source rebind. For this executed cohort the first driver is99f81eeac and completion462a02ba7; both have exact canonical physical source closure. Do not rerun completed histories to obtain a green label. RAW_MANIFEST.json owns both raw ZIP SHA256 values and source-tree identities. Every ZIP includes its member digest inventory.
