# KALM-S431-01: recovered actual SWAP5 failure snapshot (2026-10-18)

Recovered two existing artifacts without launching CI: run 39118301423 artifact 12133043932 (accepted-state summary); run 39125001908 artifact 12135892353 (actual production Newton trace).

Accepted top state before failure at 2024-03-09T13:00 UTC: pressure head +1.0008476271206002 cm, volumetric water content 0.423, surface ponding 0.00084762712060012352 cm. Rain for failed hour zero; atmospheric potential ET0 1.979309 mm/day. Trace: 22 accepted substeps, 547 solver rejections, zero mass or temporal rejects. Unaccepted flux-branch Newton trials produce top pressure heads around -20000 cm with exceptionally small trial timesteps and huge residual norm.

Neither artifact contains a restartable full vector of pressure head, water content and all active node geometry or optional state. Exact cross-model one-hour matched-state initialization is therefore NOT achieved. Earlier SWAP4 near-ponding experiments are valid local SWAP4 smoke tests, not proof of equivalent dynamics. No model correction proposed on incomplete evidence.

Next exact diagnostic on the SWAP5 pilot research branch: export the last accepted state for each node (index, z, dz, h, theta), optional storages, top/bottom state, historical forcing row and solver parameters, with precise source commit. Then replay one hour in an isolated SWAP4 diagnostic build and compare flux/head branch selection and nonlinear residual/Jacobian. No RossFast or tolerance relaxations. Canonical untouched.
