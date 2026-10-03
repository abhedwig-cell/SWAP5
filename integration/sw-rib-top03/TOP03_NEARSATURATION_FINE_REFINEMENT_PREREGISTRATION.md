# Near-saturation BASE fine-refinement diagnostic

Date: 2026-10-03  
Status: PREREGISTERED_DIAGNOSTIC_ONLY  
Scope: existing BASE imposed-head probe, widths 0.2 and 2 cm, 1/2/4/8/16/32 equal substeps per forcing window.

## Question

The prior four-level characterization found complete nonlinear trajectories at widths 0.2 and 2 cm, but integrated lower-boundary transfer discrepancies often increased from 1-vs-2 to 2-vs-4 substeps. This diagnostic asks whether those errors subsequently contract at finer levels, or whether the trajectories fail before a refinement sequence can be established.

## Controlled variables

Use the exact fixture in `test_sw_rib_top03_base_temporal_acceptance_probe.f90`: same MOD_grid, MvG profile, initial pressure head and groundwater level, external head and sill, free-drainage bottom mode 7, solver tolerances, exchange accounting, and four forcing-window lengths. Only refinement levels 16 and 32 are added; run widths 0.2 and 2 cm. The width-zero record remains the existing comparator and is not rerun by this extension.

## Reporting and interpretation

Report every path and every adjacent pair. A path counts only if it completes all substeps and passes the existing per-step soil and combined ledger checks. Inspect pressure head, water content, ponding, groundwater level, integrated top transfer, and integrated bottom transfer discrepancies separately. Do not combine quantities with unlike units into a new norm, select an acceptance budget, or infer production temporal accuracy from apparent contraction alone. O0 and O2 output must match exactly. Any failure or non-contraction is retained as diagnostic evidence, not retried under altered physics or tolerances.

No kernel acceptance, FMR transaction, external publication, or production semantics are changed by this probe. The shared TOP03 temporal-acceptance prerequisite remains in force.
