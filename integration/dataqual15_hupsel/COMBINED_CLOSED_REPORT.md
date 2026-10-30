# DATAQUAL15 combined historical execution

The original Hupsel project completes all **1096 days from day1** on the combined source (`ef9a107`), with unchanged original SWP, maize/potato/grass, weather and drainage inputs. Actual checked gfortran13.3.0 O2 execution returns0 in682.615s. All eight output/state/native files are byte-identical to the independently qualified Hupsel source. This is **one fully executed original project; zero projects claimed fully scientifically equivalent**. No production promotion or canonical admission is implied by this report.

| Actual combined execution | Result |
|---|---|
| Hupsel original1→1096 O2 | Complete; water8.302e-14cm, solute9.797e-12mg/cm², observed soil-heat accounting1.918e-12J/cm² maximum residuals |
| Grassgrowth original1→367 O2 | Complete in291.744s; all367 budget/crop rows and physical native payload exact against C2 |
| Grassgrowth365→367 fresh restart | Complete; both daily rows and entire native checkpoint exact;11 corrupt files rejected |
| Hupsel584→591 irrigation restart | Complete; water/solute budgets, physiology and native checkpoint exact |
| Hupsel730→731 calendar/crop restart | Complete; budget/crop/native bytes exact |
| Hupsel868→1096 post-mowing restart | Complete;228 budget/crop rows and final state, temperature, endpoint and native bytes exact |
| Hupsel1058→1096 O0;1077→1096 fresh restart | Complete; final native state equals uninterrupted O2;19 restart days exact |
| Typed Hupsel decoder controls |111 checks:3 valid reads and108 corruptions rejected before publication, across O0/O2 actual checkpoints |

The irrigation restart differs only in the unused post-emergence `pressure_average_cm` diagnostic: uninterrupted output retains its last germination value while a fresh process initializes it to zero. This variable is not used by emerged-crop physics. All physiological columns and the complete persisted state are identical. Hupsel WOFOST crop receipts cover days495–1096; prescribed maize in the first494 days is covered by the contiguous full water/root-demand ledger, rather than invented WOFOST biomass rows.

Six coherent missing functional chains were completed: maize lifecycle, potato WOFOST/roots/oxygen/salinity, seasonal rotation, transactional reactive water/heat coupling, irrigation clock and third-season grass mowing/root/native continuation. Five numerical corrections and four original-parameter bindings are counted separately in the authoritative migration matrix; these are not additional migrated projects.

Comparison against actual original4.3.1 output remains bounded scientific evidence. Maximum global water-stock difference is0.08243cm and solute-stock difference0.02498mg/cm²; grass harvest dates agree. Actual biomass and LAI differences remain measurable. The original donor's terminal canopy/BALDEV accounting caveat is retained. The capsule contains the original high-precision trajectory and comparison record. Complete scientific equivalence is not asserted.

The standalone C2 Grassgrowth source (`139330b`) reaches1786 days and stops before1787; its terminal context is included separately. The combined source was actually executed for367 Grassgrowth days. The subsequent C3 oxygen repair is excluded from this source and qualification.

`COMBINED_CLOSED_EVIDENCE.tar.xz` contains normalized complete compiler dependency closures, repository and generated source snapshots, original inputs, actual binaries and TTUTIL, raw execution/restart/control records, native frames, golden comparisons and a SHA256 manifest. `COMBINED_CLOSED_RESULT.json` binds the capsule. Its closed production inventory is relative to canonical3170aa1; unknown production paths or byte changes fail verification. No old absolute workspace path or local-only Git commit is needed by the verifier.

Run from any checkout containing the qualified source:

```sh
python -B tests/dataqual15_hupsel/verify_combined_closed.py
```

For actual reruns, extract the capsule and use the existing clean builder with an explicit compiler and `--ttutil-archive <extracted>/ttutil/libttutil.a`; omit `--reuse`. Then use the existing Hupsel runner with `--rotation --end 1096 --prepare-days 1096`. Grassgrowth uses its existing builder and original runner. Compiler flags, source hashes, inputs and commands are retained in the capsule; the verified numerical scope is the recorded compiler and platform.
