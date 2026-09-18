# PUB-GC GMD cover-letter draft

## Status

**SCIENTIFIC CONTENT READY — FINAL TITLE / AUTHORS / ARCHIVE IDENTIFIER PENDING**

Dear Editors of *Geoscientific Model Development*,

We submit the manuscript

> **Hydrologically accountable finite-window coupling of SWAP5 (<<SWAP5_PUBLICATION_VERSION>>) and MODFLOW 6.8.0**

for consideration as a **Development and technical paper**.

The manuscript presents and evaluates a solver-autonomous coupling contract for vadose-zone and groundwater models. The contribution is not a new nonlinear solver. Instead, the design makes hydrological interface meaning, trial-versus-accepted model state, exactly-once interface-mass authority, finite-window response identity and component/application admissibility explicit and testable while SWAP5 and MODFLOW6 retain their own numerical solvers.

Controlled coupling experiments show that strict interface convergence can improve while groundwater-head correction remains very small. Independent response experiments identify the exposed SWAP response as a flux-driven finite-window predictor response rather than a universal head-to-exchange Jacobian. A derivative-information experiment then finds only modest incremental value over cold black-box secant learning.

The paper also reports negative evidence rather than tuning it away. Two controlled stress extensions reach component-admission boundaries. A realistic Hupselbrook application was then selected prospectively from standalone dynamics before coupled output. Both frozen days require authentic drainage, whereas the current prescribed-head production participant rejects active drainage before owner-state allocation. Under the preregistered rule E7 closes as a **realistic component-domain limit**, with zero loose or strong Hupsel coupling windows executed.

The submission package includes machine-readable E1–E7 evidence, workflow provenance, figure-generation material and reproducibility records. The exact final software release will be archived persistently at **<<SWAP5_ARCHIVE_DOI_OR_PID>>** under **<<SWAP5_LICENSE_AUTHORITY>>** after the remaining governance fields are resolved. The historical SWAP 4.3.1 reference distribution is not redistributed; its cryptographic identity and derived public evidence are documented separately.

We believe the manuscript fits GMD as a model-development and technical-method contribution focused on reproducibility, coupling semantics, numerical ownership and explicit applicability limits. It does not claim novelty for generic partitioned coupling, rollback, quasi-Newton acceleration, MODFLOW API control or model modularity.

Sincerely,

**<<CORRESPONDING_AUTHOR>>**  
on behalf of the authors
