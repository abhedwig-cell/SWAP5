# SWAP-011: implicit Richards conductivity derivative mismatch

Status of finding: **CONFIRMED BUG**

B1 admission status: **ADMITTED_B1 (B1.11)**

## Finding

When `SWKIMPL=1`, the Richards Newton Jacobian uses `dhconduc` for the hydraulic-conductivity derivative. In the B0 SWAP 4.3.1 implementation, `dhconduc` applies the standard Mualem-van Genuchten derivative even for hydraulic models whose implemented `K(h)` relation is different.

The mismatch affects hydraulic models 3 and 5-12. Model 4 is the standard Mualem-van Genuchten case and is consistent; it was explicitly excluded from the earlier broad statement after qualification.

The consequence is a wrong Newton Jacobian for affected models. This is an implementation/algorithm defect, not a proposal to change the physical model. The residual uses one conductivity relation while the Jacobian differentiates another.

## Intended rule

For implicit Richards solving, the Jacobian conductivity term must represent the derivative of the **actual conductivity function used in the residual for the active hydraulic model and state**.

Formally, if the residual contains `K(h)`, the corresponding Jacobian contribution must use the consistent `dK/dh` for that same `K(h)` implementation. A standard-MvG derivative may only be used when the active conductivity relation is in fact the standard MvG relation.

## B0 location

Primary defect location:

```text
MOD_MvG_functions.f90 : dhconduc
```

The final qualified implementation also touches model-specific constitutive support in:

```text
WC_K_models_04_11.f90
MOD_RIA.f90
```

The final E5/E7 solution did **not** modify `headcalc.f90`; that file remained byte-identical in the qualified patch line.

## Classification

- category: code/algorithm mismatch
- severity: high
- confidence: very high
- physics change: no
- B1 status: admitted in B1.11
- SWAP5 compatibility rule: SWAP5 reference follows the corrected B1 behaviour, not the known B0 Jacobian defect

## Historical audit progression

The central issue register snapshot recorded SWAP-011 as `BUG_CONFIRMED_SOLUTION_REVIEW`. Subsequent E5/E6/E7 work completed the optimized production implementation and qualification, reaching `FIX_TESTED` / `READY_PATCH_UPSTREAM`.

The exact E7 upstream package was later recovered and its patch identity was pinned. A byte-safe ordered B1.10 patch was derived without altering the qualified E7 semantics, and a full replay from the exact B0 distribution reproduced the frozen B1.11 source identity exactly. The former provenance gate is therefore closed and SWAP-011 is formally admitted in B1.11.
