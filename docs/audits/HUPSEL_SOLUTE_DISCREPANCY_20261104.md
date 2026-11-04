# Retained Hupsel solute discrepancy attribution

Status: Windows and cold POSIX qualified; canonical integration pending.

The accepted corrected diagnostic trajectory retains a final solute-stock error of-0.007222933243499mg/cm2 against the immutable fine original reference. The unchanged stock limit is0.006477510502005319mg/cm2. The first daily crossing occurs at day1088; the largest error occurs at day1096. This work audits the existing actual data rather than rerunning either model or changing production physics.

Both complete1096-day ledgers pass the existing1e-10 daily and1e-8 cumulative conservation checks. Their exact difference identity retains initial stock, external inputs, external exports and both measured closure residuals. The native input sum48.00000000004769 is retained as measured; it is never rounded to an exact48. The fine reference has zero observed uptake export, so its external export is drainage. The native output remains aggregate external export: a separate native drainage component has not been measured.

At all16 original profile dates, all34 primitive nodes reconstruct the native and reference stocks independently. Exact geometry and native dissolved/solute consistency remain mandatory. A symmetric product identity decomposes each theta-times-concentration stock difference into water-content and concentration terms; their sum must reproduce the actual primitive difference. This is algebraic state attribution, not a causal transport sensitivity.

At day1096, the concentration contribution is-0.007223342524514mg/cm2 and the water-content contribution is+0.000000409281501160mg/cm2. At day636 these contributions have opposite signs and substantially cancel; omitting the water term is explicitly refused. Nine injected defects cover missing/shifted days, native/reference flux, external input, native/reference concentration donors, missing profiles and an omitted product term.

The result excludes a missing mass balance or a final water-content-only explanation at the measured states. It does not identify the native face-flux, drainage concentration or temporal integration mechanism. Production correction remains unqualified, the stock/export frozen failures remain failures, and whole scientific qualification remains0/3 with original execution2/3. Thermal/contact research remains separately owned.

Authority: `integration/dataqual15_hupsel/SOLUTE_ATTRIBUTION_PREREGISTRATION_20261104.json`, `SOLUTE_ATTRIBUTION_20261104.json` and `SOLUTE_ATTRIBUTION_RECOVERY_20261104.json`. The independent executable gate is `tests/dataqual15_hupsel/solute_discrepancy_attribution.py`.

Cold POSIX run41752348137/job126320224111 reproduces the full sealed report and all nine defect refusals. Maximum daily native/reference closure errors are9.62704e-12 and2.99965e-11mg/cm2. Across all1096 days, the maximum difference-identity residual is2.07029e-16mg/cm2. The final cumulative native/reference export difference is+0.007222933987118mg/cm2; the measured input and closure differences account for the small remainder.

All15 triggered workflows are terminal and successful, including actual canonical composed qualification run41752348097/job126320501101. Final metadata changes leave the cold-qualified executable dependencies exact. Documentation source checks and strict build pass.
