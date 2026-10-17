# MC-NUT01 actual joint crop Soil-N owner project startup (2026-10-17)

Base canonical: e51efd1f14de328db22d2c32a6ca78bc228d01b0. PR #1289. Tested production head: 45ae8ce15c18f1cceeeba3bcde7a2d988fc510c2.

## Admitted bounded function

initialize_historical_crop_soil_owner combines previously admitted source-file typed reactive N and crop policy initialization with the existing initialize_crop_soil owner, and publishes plan/coupled state/senescence only after successful complete initialization. No second owner, clock, N ledger or restart codec. Fail closed on rejected crop owner.

The existing B1.12 actual joint driver builds the owner using a complete source export at startup and verifies ownership readiness and original apparent-age policy. The same driver subsequently runs the **incumbent** B1.12 multi-day Richards, senescence, pending/harvest and opaque native restart scenarios using its preexisting fixture initialization. Do not claim that a full source-initialized multi-day restart was executed.

## Evidence

GitHub Actions run 39047800394: https://github.com/abhedwig-cell/SWAP5/actions/runs/39047800394; terminal success, first independent historical B1.11 reproductive literal O0/O2 and then actual B1.12 Full Richards crop/Soil-N O0/O2 with native fresh-process restart and preserved old reference bytes. Real tested implementation SHA pinned above. Earlier run 39047549628 failed in harness setup before compiling; repaired workflow supplies original reproduction literal and cold build. No new chemistry/hydro/crop numeric formulas.

## Not admitted

Complete original TTUTIL/SNM parsing, source-initialized MULTI-DAY crop/Soil-N restart equivalence (as opposed to separately tested startup and incumbent continuation), historical crop rotation/lifecycle and whole MC-NUT01 capability envelope remain open. No complete mastercoverage row is promoted. The source project startup only supports the explicitly bounded unified export.
