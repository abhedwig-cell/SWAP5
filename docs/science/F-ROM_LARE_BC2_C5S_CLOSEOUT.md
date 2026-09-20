# F-ROM-LARE BC2-C5S closure-family derivation

C5R closes the remaining state-breadth ambiguity for the tested B14 dynamic-head representation: with identical 5/2.5/2.5-cm lower-boundary support, D8 and D12 produce effectively the same groundwater response. The remaining error is therefore much more strongly identified with inter-layer propagation.

C5S is read-only. It does not implement or tune a closure.

Existing evidence excludes several nearby routes as the next experiment. C4H found the internal-flux residual gradient-component dominated rather than conductivity-mean dominated. C4K did not establish a need for an extra dynamic memory state. C4L-C4O found cubic, central, geometry-only and existing-state scalar gradient corrections mixed or non-transferable. Those routes remain closed.

The first structurally distinct closure ready for a zero-fit mechanism test is a **Darcian steady-equivalent nonlinear two-point flux (DSE2P)**. For each adjacent retained layer pair, the dynamic state remains integrated water storage and the existing storage-to-representative-head mapping is retained. Instead of applying a chosen interface conductivity to a linearly reconstructed head gradient, DSE2P obtains the one conservative interface flux from the local one-dimensional steady Richards boundary-value problem connecting the two representative heads over their center-to-center distance.

This is not a scalar correction to CURRENT_LAYER_FACE. Its effective conductance depends jointly and nonlinearly on both endpoint states, spacing, gravity/capillary balance and the full K(h) relation. No fitted coefficient, direction switch or new dynamic state is introduced.

A second family, a storage-consistent algebraic subgrid face-profile closure, remains scientifically admissible but is not implementation-ready. It first needs a unique zero-fit profile ansatz that preserves layer storage and allows unequal top and bottom fluxes during transient storage change.

C5T will therefore be an exposed mechanism diagnostic, not blind validation and not free-running model development. On the frozen C5R R01-R04 R2048-T16 trajectories, exact D12_B2P5 layer storages and fine-Reference interface fluxes will be reconstructed. CURRENT_LAYER_FACE and DSE2P will then be evaluated offline on the exact same states. Neither candidate may feed back into the Reference solve.

Only if DSE2P is componentwise no worse on the preregistered lower-interface moving-phase vector, strictly improves the relevant flux-RMSE views, and creates no HOLD/sign defect may a later fresh blind free-running implementation test be authorized.
