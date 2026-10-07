# SW431-LOW3-EXPLICIT status

WORKSTREAM: SWAP 4.3.1/B1.11 coverage closeout
CAPABILITY: SW431-LOW3-EXPLICIT
BRANCH: work/swap431-low3-explicit-20261007
QUALIFIED POSTIMAGE: 14da112d47c62da078a6e2fd088d1237ca402856
QUALIFICATION RUN: 37603745401
STATUS: production implementation qualified; pending master-coverage admission

## Scope

Admit the explicit B1.11 mode-3 Cauchy lower-boundary route using:
- profile-derived groundwater level via the qualified CALCGWL-equivalent projection;
- SHAPE_3 transformed groundwater level;
- saturated profile resistance integrated from the groundwater table to the profile bottom using saturated conductivity;
- forcing-owned aquifer head, RIMLAY and optional Q4 from the existing Cauchy control owner;
- prescribed-qbot execution through the already admitted mode-2 solver surface.

The existing implicit LOW03-A Cauchy route remains a distinct owner and is preserved.

## Source semantics

The explicit flux follows the B1.11 source authority:
gwlmean = hdrain + shape_3 * (gwl - hdrain)
cvalprof = saturated fraction of the groundwater-table node / Ksat + sum(dz/Ksat) below
qbot = (deepgw - gwlmean) / (rimlay + cvalprof) + q4

Profile resistance is part of the explicit source law and is not controlled by the implicit-route half-cell switch.

## Ownership and invariants

- CALCGWL is derived from the trial-start physical pressure profile.
- Aquifer head, RIMLAY and Q4 remain owned by the existing typed Cauchy control/proposal.
- The explicit route converts the resolved law to a prescribed qbot for the Richards solve; it does not widen the implicit mode-3 solver law.
- Explicit controls are immutable parameter-owned configuration.
- Ordinary explicit Cauchy is a standalone application profile, not a groundwater-coupled profile.
- Existing implicit Cauchy, prescribed-qbot and nearby unsupported bottom modes remain fail-closed/preserved.

## Qualification evidence

GitHub Actions run 37603745401 on postimage 14da112d47c62da078a6e2fd088d1237ca402856 passed all qualification steps:
- explicit Cauchy component source oracle O0/O2;
- CALCGWL profile projection O0/O2;
- production bootstrap explicit application O0/O2;
- transactional runtime + implicit preservation O0/O2.

The production application oracle additionally proves:
- admitted bootstrap and committed transaction;
- zero hard-mass residual in equilibrium;
- typed head/Q4 proposal binding;
- groundwater-owner separation;
- unsupported-profile fail-closed matrix;
- retry rollback without publication;
- replay identity;
- missing-history fail-closed behavior;
- restart identity.

## Claim ceiling

This closes SW431-LOW3-EXPLICIT only. It does not admit unrelated lower-boundary selectors, broaden external groundwater ownership, or reclassify other active migration capabilities.

## Next safe step

Admit this qualified capability into the master-coverage ledger and continue reconciliation from the updated canonical/master state.
