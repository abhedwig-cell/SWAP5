# EB-I18 Current Status and Blocker Evidence

Status: `BLOCKED_PREREQUISITE`

This document records why EB-I18 cannot yet be closed as a production-qualified candidate-bound external bottom-energy publication capability. It is an evidence record, not a production admission.

## Evidence boundary

EB-I18 authority starts from `EB-I17R@ab74f6ded24a7d74d5f3c6f5dcafe58e28f7248f`.

Current canonical checked for the prerequisite boundary:

- `integration/f-ci-canonical@e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557`

Relevant existing qualification lines:

- F-SI27 explicit prescribed-qbot solver capability: `work/f-si27-explicit-prescribed-qbot-boundary@777015b8daffbd859e737f894cb585bd9ce96612`
- F-SI27 production postimage commit: `3b942c6777412e0d28ed46941778e4482f6bffaa`
- historical upward prescribed-head diagnostic: `qualification/f-vq26-upward-trial-diagnostic@50c8a16d33a554b1cda0bd62728732d3fd4e1173`

## What the I18 oracle intended to prove

The external-provider cases require an accepted hydrologic candidate containing a real lower-boundary inflow into SWAP. That accepted water transfer is the only legitimate basis for requesting an external donor temperature and for calculating accepted sensible-energy attribution.

The staged I18 transaction fixture attempted to create this by combining:

- `parameters%bottom_mode = 7`;
- closed top boundary;
- a small positive `forcing%bottom_flux = q`.

The fixture comment interpreted positive bottom flux as inflow to SWAP.

## Why that fixture is invalid

In the production HeadCalc route, `swbotb == 7` is explicitly the free-drainage option. It evaluates the lower flux from hydraulic conductivity and sets:

`state%qbot = -1.0d0 * state%kmean(numnod+1)`

Therefore mode 7 does not impose the positive `forcing%bottom_flux = q` used by the I18 fixture. The transaction oracle was not exercising the claimed external-inflow hydrology.

This explains why changing the EB-I18 numerical tolerances to values copied from EB-I13 did not establish the intended path. EB-I13's admitted throughflow case is not evidence for a positive prescribed lower-boundary inflow.

## Why F-SI27 does not already remove the blocker

F-SI27 qualifies an explicit prescribed-qbot capability at the lower reference Richards / legacy binding level. That is necessary evidence, but it is not the same as production serialized-runtime admission.

On current canonical, `mod_b110_serialized_context_binding.f90` rejects every lower-boundary mode except `7`, `-2` and `5`. Explicit prescribed-qbot mode `2` is therefore not available through the serialized production path used by EB-I18.

EB-I18 must not widen this binding silently. Doing so inside the energy workunit would cross solver/runtime ownership and would create a new production hydrologic route without its own qualification.

## Why prescribed head is not an acceptable shortcut

Historical F-VQ26 diagnostic evidence for the upward prescribed-head trial recorded a reproducible solver rejection, including retry exhaustion with zero accepted substeps. That route cannot be substituted merely to obtain an external donor sample for EB-I18.

## What remains valid in EB-I18

The blocker does not invalidate the architectural direction of candidate-bound accepted-only energy publication. In particular, the work already separates:

- local thermal candidate capture from persistent column state;
- external donor metadata from water-transfer ownership;
- prepared energy from commit authority;
- provider COMPLETE, UNAVAILABLE, STALE and invalid dispositions;
- accepted publication from rejected/retried candidates.

Those structures are not final production qualification evidence until they execute against a genuinely accepted external-inflow candidate on the production path.

## Required prerequisite

A separate solver/runtime integration workunit must expose an explicit lower-boundary prescribed-flux contract through the production serialized reference route, using the already qualified lower-layer capability where appropriate.

Minimum prerequisite evidence:

1. serialized binding admits the explicit prescribed-qbot contract intentionally, not by fallback to free drainage;
2. a positive lower-boundary inflow is dynamically accepted by the reference serialized runtime for a bounded qualified fixture;
3. the accepted bottom water transfer has the documented sign and amount;
4. water mass closes within the governing transaction tolerance;
5. reject, retry and retry-exhaustion leave no committed water transfer;
6. O0 and O2 are semantically identical for the prerequisite oracle;
7. existing free-drainage, prescribed-head and non-energy routes are preserved;
8. the prerequisite is independently reviewed/admitted before EB-I18 treats it as production authority.

No new energy physics is required in that prerequisite.

## EB-I18 unblocking rule

After the prerequisite is admitted, EB-I18 must replace the mode-7 pseudo-inflow fixture with the admitted explicit-inflow contract and rerun its complete qualification protocol on production source.

The following are still mandatory after unblocking:

- external COMPLETE accepted publication;
- UNAVAILABLE and STALE accepted hydrology with unavailable energy total;
- invalid/mismatched response fail-closed for energy without changing hydrologic acceptance;
- kernel, mass and commit rejection with no publication;
- stale-scratch and sibling-candidate attacks;
- non-energy preservation;
- restart and mass-authority preservation;
- O0/O2 semantic identity;
- unchanged-head qualification before any closure claim.

## Nonclaims

At this status point:

- EB-I18 is not production-qualified;
- its staged runtime patch must not be auto-committed as production solely from the current oracle;
- there is no canonical admission;
- there is no claim that positive external bottom inflow is supported by the current serialized production runtime;
- the blocker is not evidence that candidate-bound energy publication is scientifically wrong.

The correct interpretation is narrower: the required accepted external-inflow hydrologic prerequisite is not yet available on the production serialized path.