# F-ROM-LARE BC2-C5K closeout

C5K evaluates local prescribed-head half-cell flux theory on byte-identical frozen C5I trajectories. Nothing feeds back into the Reference solve.

Authority is run 35505829870 at execution head ab2d0f1697d819ab85c49d08c1046bc6c59b9ea6, artifact 10604245410, digest sha256:22f1a4e197cf4068e99da533487efaff736b50adac934ee5359396be9da5eac7. Result SHA-256 is aeb315e72d2b4f60cd8e01cac316bbb89d703ed9f3166b0e0f34f064969a1ce9.

Instrumentation leaves every C5I state line byte-identical. The reconstructed current local-face term differs from published mass-balance bottom flux by at most a few 1e-9 cm/d.

The current local R512-R1024 gap is about 0.023397 cm/d. Post-step K raises it by about 1.8%. Arithmetic center-boundary means raise it by about 4.5-5.0%. The Kirchhoff/integrated mean and the exact steady nonlinear half-cell operator both raise it by about 6.0%.

The pre-step K-lag effect is real but smaller than the nonlinear spatial constitutive correction: the preregistered maximum-grid lag/spatial-correction ratio is about 0.358.

The integrated and exact-steady operators are nearly identical in inter-grid effect. Thus a more theory-rich local half-cell conductivity representation does not move the frozen-state spatial gap in the required direction.

No dynamic boundary counterfactual is authorized. With temporal error already subdominant and the local boundary mechanism now characterized, C5L is a single unchanged-Reference R2048 T16 spatial extension.
