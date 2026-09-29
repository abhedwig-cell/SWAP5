# F-WOF-PP01 — WOFOST 8.1 Independent Potential-Production Donor Qualification

## Verdict

**PASS for the WOFOST 8.1 crop-production / crop-N state owned by the verified SWAP 4.3.1 donor.**

All ten independent Allard/PCSE 6.0.13 Spring Barley trajectories were executed through the verified
`SWAP_4.3.1_WOFOST81_WORKING_FINAL_13B.zip` donor with qualification-only non-limiting external-state
binding. The 12 donor-owned crop outputs pass the original YAML precision contract in every case.
The residual differences are at floating-point roundoff scale.

This is **not** a 14-field YAML conformance PASS. `RD` and `TRA` are deliberately retained SWAP
rooting/hydrology interface quantities rather than WOFOST81-owned crop state in this donor and they
do not numerically match the corresponding PCSE outputs. They are reported as explicit interface
non-equivalence, not omitted and not counted as a pass.

## Immutable provenance

- PCSE oracle ZIP SHA-256: `99a67a0e5f6bd0881b97950a2ff3fe0f387c0a9e0553f2e36197077fbc15d145`
- SWAP 4.3.1 WOFOST81 donor ZIP SHA-256: `4e0bf97bca7f3f8716e5bcf46a5dc9bb6b08436304b032d60adc3757491d94dc`
- Historical donor source closeout: `839c34a657c2cee202b55d9ee85253d867a3d47a`
- Spring Barley source binding: `Spring_barley_301 / barley_wofost81.crp`
- Rebuilt unmodified donor executable SHA-256: `eefde8e7de08a5dea7fa4e2d53117ecb0e9cccf5a15df97eec27736f15f29042`
- Qualification adapter executable SHA-256: `0a62652839db367ea7011acc8cfcfdb34458504f502cbbde5c9cf741e332d23b`
- Original `wofost.f90` SHA-256: `84f0033b958132c44d650357e254cf97bc48f455ed9971c449e5582ca3258441`
- Qualification-copy `wofost.f90` SHA-256: `6493fbc84a478fc49d887d79d53680c1e4cfb7365e2bae09adcee37e4eacfe64`

The unmodified donor was independently rebuilt with GNU Fortran and its bundled WOFOST81 example
completed normally before the qualification-only adapter was built.

## Qualification-only external-state binding

The PCSE fixtures prescribe daily external `SM=0.3` and `NAVAIL=100`, i.e. a deliberately
non-limiting crop boundary. The SWAP donor normally obtains water and N supply from SWAP hydrology
and Soil-N. To compare the WOFOST implementation rather than those different external models, the
test-only source copy:

1. sets WOFOST81 actual-crop `RELTR=1.0`;
2. returns `NsupplySoil = NdemandSoil` immediately before the existing
   `apply_wofost81_n_runtime_supply()` call. The donor's request calculation, `RNUPTAKEMAX`,
   translocation, organ-N state and balance closure remain unchanged;
3. adds a qualification-only daily observation CSV.

No donor crop equation, oracle value, YAML tolerance or SWAP5 production source was changed.

PCSE state timing is aligned as follows: the crop-start PCSE state maps to SWAP `INIT`; subsequent
PCSE state on day *n* maps to the preceding SWAP `POST` commit. The one-day presentation offset was
established directly from the trajectories, including exact DVS/biomass/N-state matches.

## Ten-case result

| Variable | YAML precision | Worst absolute deviation | Worst case | Worst date | Verdict |
|---|---:|---:|---:|---|---|
| `DVS` | 0.0001 | 4.441e-16 | 002 | 2025-06-07 | PASS |
| `LAI` | 0.01 | 7.105e-15 | 009 | 2025-06-13 | PASS |
| `NamountLV` | 0.01 | 4.263e-14 | 007 | 2025-06-01 | PASS |
| `NamountRT` | 0.01 | 2.132e-14 | 008 | 2025-04-18 | PASS |
| `NamountSO` | 0.01 | 5.684e-14 | 005 | 2025-06-25 | PASS |
| `NamountST` | 0.01 | 2.842e-14 | 001 | 2025-04-05 | PASS |
| `NuptakeTotal` | 0.01 | 1.705e-13 | 006 | 2025-07-04 | PASS |
| `TAGP` | 0.1 | 7.276e-12 | 006 | 2025-07-03 | PASS |
| `TWLV` | 0.1 | 2.274e-12 | 010 | 2025-06-16 | PASS |
| `TWRT` | 0.1 | 1.364e-12 | 009 | 2025-07-09 | PASS |
| `TWSO` | 0.1 | 5.457e-12 | 010 | 2025-07-25 | PASS |
| `TWST` | 0.1 | 2.728e-12 | 002 | 2025-06-07 | PASS |

Every one of these 12 variables passed on every daily crop-state observation in all ten cases.
The largest production-state discrepancy was `TAGP = 7.276e-12 kg/ha`, versus an allowed
`0.1 kg/ha`.

The ten qualification traces were each run twice. All ten second-run CSV files were byte-for-byte
identical to the first run.

## `RD` is an explicit interface non-equivalence

The PCSE fixtures include WOFOST root depth, but the donor retains SWAP rooting as a SWAP-specific
extension. `MOD_cropdevelopment::update_rootextension` owns `rd`/`rdpot` and conditions extension on
SWAP transpiration/root-interface state and soil rooting limits. Therefore comparing PCSE `RD`
directly to SWAP `rd` compares different owners.

This is observable in all ten cases. Example case 001 first exceeds the `0.01 cm` oracle tolerance
on 2025-02-11; PCSE reaches 120 cm while the SWAP rooting interface ends the compared trajectory at
32 cm. Across the ten cases the maximum absolute `RD` discrepancy is 88 cm.

`RD` is therefore **not counted as a WOFOST81 crop-production equivalence PASS**.

## `TRA` is an explicit interface non-equivalence

The donor retains SWAP's hydrology/Penman-Monteith/root-extraction pathway and supplies relative
transpiration into WOFOST. PCSE `TRA` is therefore not represented by a donor-owned WOFOST81 crop
state. Comparing it to SWAP `iptra_day` (or actual root extraction) fails in all ten cases.

Case 001 first exceeds the `0.001 cm/d` tolerance on 2025-02-07. Across cases, the candidate
`iptra_day` mismatch reaches approximately `0.249 cm/d`.

`TRA` is therefore **not counted as a WOFOST81 crop-production equivalence PASS**.

## Canonical reconciliation after execution

The SWAP5 canonical head advanced from
`1f33328e2ddc0d28450d35647c1c97f293b1e622` to
`4a01641ffed8a2260260909825c3887db2dff1ac` during this campaign. The 43-commit delta contains
EB, ROSS/RossFast, F-KT22 and associated runtime/evidence changes; it contains no crop/F-WOF
production change. The immutable donor/oracle qualification evidence therefore remains valid.

## Scientific conclusion

The original question is resolved positively at the intended crop-model boundary:

> For the ten supplied Spring Barley potential-production trajectories, the translated WOFOST 8.1
> Fortran crop model in the verified SWAP 4.3.1 donor reproduces the PCSE 6.0.13 WOFOST 8.1
> phenology, canopy, dry-matter production, organ partitioning, organ-N state and cumulative N
> uptake to floating-point roundoff and far inside the supplied precision contract.

The result does **not** establish identity of SWAP rooting or SWAP hydrology with PCSE `RD`/`TRA`.
Those are separate coupling/interface questions.

## Next bounded action

Use this qualified donor/oracle surface as the immutable reference for SWAP5 migration preservation.
Do not require SWAP5 to reproduce PCSE `RD` or `TRA` through unrelated SWAP interfaces unless a
separate interface-equivalence contract is explicitly defined and qualified.
