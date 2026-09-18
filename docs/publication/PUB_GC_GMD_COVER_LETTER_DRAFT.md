# PUB-GC GMD cover-letter draft

## Status

**SCIENTIFIC CONTENT READY — FINAL TITLE / AUTHORS / ARCHIVE IDENTIFIER PENDING**

Date: 2026-09-18.

This draft is deliberately journal-facing and does not claim a successful regional Hupsel validation.

---

Dear Editors of *Geoscientific Model Development*,

We submit the manuscript

> **Hydrologically accountable finite-window coupling of SWAP5 (<<SWAP5_PUBLICATION_VERSION>>) and MODFLOW 6.8.0**

for consideration as a **Development and technical paper**.

The manuscript presents and evaluates a solver-autonomous coupling contract for vadose-zone and groundwater models. The central contribution is not a new nonlinear solver. Instead, the coupling design makes four scientific responsibilities explicit and testable while SWAP5 and MODFLOW6 retain their own numerical solvers: hydrological interface meaning, trial-versus-accepted model state, exactly-once interface-mass authority, and the application domain in which each component can return a valid finite-window candidate.

The evidence is intentionally falsifiable. Controlled SWAP5–MODFLOW6 experiments show that strict interface convergence can improve while the physical groundwater-head correction remains very small. Independent response experiments show that the exposed SWAP finite-window response belongs to a flux-driven predictor map and is not a universal head-to-exchange Jacobian. A derivative-information experiment then finds only modest incremental work reduction over a cold black-box secant method.

The manuscript also reports negative evidence rather than tuning it away. Two controlled stress extensions reach component-admission boundaries before a stronger valid feedback case is available. A realistic Hupselbrook experiment was therefore prospectively selected from standalone dynamics before coupled output. Both frozen days require authentic drainage, whereas the current production prescribed-head groundwater participant rejects active drainage before owner-state allocation. Under the preregistered stop rule, E7 closes as a **realistic component-domain limit**, with zero loose or strong Hupsel coupling windows executed. We consider this distinction between component-domain failure and outer-coupling failure an important part of reproducible model coupling.

The manuscript is accompanied by machine-readable E1–E7 evidence, reproducibility records, figure-generation material and source/test provenance. The exact software version described in the final submission will be archived persistently at **<<SWAP5_ARCHIVE_DOI_OR_PID>>** under the governed software licence **<<SWAP5_LICENSE_AUTHORITY>>** before submission. The historical SWAP 4.3.1 reference distribution is not redistributed in the publication archive; its exact cryptographic identity and derived public evidence are documented separately.

We believe the paper fits GMD because it is fundamentally a model-development and technical-method contribution with explicit source-code, reproducibility and applicability-domain evidence. The manuscript does not claim novelty for partitioned coupling, rollback, quasi-Newton acceleration, MODFLOW API control or generic model modularity.

This work has not been submitted for peer-reviewed publication elsewhere. Final author, contribution and competing-interest metadata will be supplied from the governed submission record.

Sincerely,

**<<CORRESPONDING_AUTHOR>>**  
on behalf of the authors
