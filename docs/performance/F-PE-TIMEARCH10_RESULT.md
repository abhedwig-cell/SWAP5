# F-PE-TIMEARCH10 result — numerical-profile configuration seam

Date: 2026-09-28

Status: `QUALIFIED_NUMERICAL_PROFILE_CONFIGURATION_SEAM`

Canonical base:

`integration/f-ci-canonical@7e1d296055b56e561d17c5cd1aa7b4c533a26710`

Qualified branch head:

`ca5cd8c24e3053a2139ff1abb13025297e38c0c4`

Primary evidence:

- GitHub Actions run `36428848001`;
- conclusion: SUCCESS;
- O0/O2 contract identity: PASS;
- full TIMEARCH08 preservation: PASS;
- source-isolation guard: PASS.

## Production contract

TIMEARCH10 adds one standalone production configuration contract:

`src/runtime/mod_timestep_numerical_profile.f90`.

It is not yet consumed by legacy TimeControl, parser code, the canonical runtime or any adaptive controller.

## LEGACY_NUMERICS

The contract can carry the current legacy numerical policy explicitly:

- DTMIN;
- DTMAX;
- initial dt;
- NUMBIT_CRIT;
- MAXIT;
- accepted-step increase factor;
- accepted-step decrease factor;
- failure reduction factor.

Qualification verifies exact field round-trip for valid values.

Invalid bounds and invalid adaptation-factor semantics fail validation.

A valid LEGACY_NUMERICS profile is execution-ready because it describes already admitted current behavior. TIMEARCH10 does not itself bind that profile into TimeControl.

## AUTO_REFERENCE

The contract can represent an automatic Reference profile without ordinary-user DTMIN or DTMAX.

AUTO_REFERENCE carries:

- explicit controller identifier;
- internal solver retry floor;
- optional expert safety ceiling;
- controller-admitted flag.

No user DTMIN field exists in this profile.

No required user DTMAX field exists in this profile.

The expert ceiling is optional and does not enable the controller.

AUTO_REFERENCE validates structurally but is not execution-ready while `controller_admitted = false`.

Thus configuration representation and algorithm admission are cleanly separated.

## Fail-closed behavior

AUTO_REFERENCE cannot become executable merely because a configuration object exists.

Execution readiness requires separate controller admission.

TIMEARCH10 therefore introduces no implicit automatic timestep algorithm and no hidden numerical defaults.

## Preservation

The new profile contract is isolated from current execution.

Source guards verify it is not imported by current legacy TimeControl.

TIMEARCH08, including TIMEARCH07/06 preservation underneath it, remains green.

No current timestep sequence, retry sequence, event boundary or physical trajectory changes.

## Decision

`QUALIFIED_NUMERICAL_PROFILE_CONFIGURATION_SEAM`

The internal configuration architecture now supports the long-term user-interface decision from TIMEARCH09:

- legacy users can retain exact explicit numerical controls;
- future ordinary SWAP5 use can be represented without requiring DTMIN/DTMAX;
- AUTO remains default-off until a controller is separately qualified.
