# F-ROM-LARE BC2-C5C closeout

C5C tested the spatial mechanism left unresolved by C5B. It first refined the Richards Reference from 10-cm cells to 5-cm and 2.5-cm cells, then refined only the bottom 10 cm of CURRENT_LAYER_FACE LARE.

The authoritative run is 35499789756 at execution head 0999938d399ffdfd717f16231797484740b783e7. The exact result SHA-256 is 2fe5b04dc70f31a580da5e632a26b094cb0b274cc5a45722155a948a39f5d326.

The main result is that the old R16 Reference is not spatially stable for this B14 dynamic prescribed-head workload. Bottom-flux RMSE is about 0.0438 cm/d between R16 and R32 and about 0.0490 cm/d between R32 and R64. The second refinement step is not smaller than the first, so the Richards sequence has not yet entered an evident asymptotic regime.

This changes the interpretation of C5B. The roughly 2.97e-5 cm/d LARE-versus-R16 residual was real relative to that frozen 10-cm comparator, but it cannot be treated as a continuum closure floor because the Reference itself moves by orders of magnitude more under spatial refinement.

Bottom-cell refinement in LARE is nevertheless strongly consequential. Relative to R64, pooled bottom-flux RMSE drops from about 0.0866 cm/d for B10 to 0.0488 for B5 and 0.000663 for B2P5. The signed bias also shrinks strongly, but crosses zero at B2P5, so a Richardson extrapolation from these three values is not physically reliable.

The striking similarity between the Reference-grid shifts and the LARE bottom-cell shifts points toward boundary-adjacent spatial discretization as a major mechanism. But R64 is not yet a defensible continuum-like Reference. No new closure law is authorized.

The next step is C5D: extend the Richards spatial Reference beyond R64 under the exact same workload and numerical policy, before any additional LARE or closure experiment.
