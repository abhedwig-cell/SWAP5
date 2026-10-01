# F-PE-MIQUAL06 execution correction record

Date: 2026-10-01

Status: `EXECUTION_INVALID_RUNS_PRESERVED`

The following MIQUAL06 executions are preserved as invalid qualification attempts and are not scientific or admission authority.

## Run 36823480403

Status: `EXECUTION_INVALID_BEFORE_RUNTIME_EXPOSURE`

Compilation failed because adapter-owned reduced constitutive/source providers were not pointer-owning objects while the solve request required pointer association.

Correction: make those two providers pointer-owned scratch and allocate/release them explicitly.

No runtime manager result was exposed.

## Run 36823591062

Status: `EXECUTION_INVALID_FIXTURE_TEMPORAL_REJECTION`

The full/default serialized solver compiled and converged, but the original non-equilibrium seam fixture was rejected by the transaction temporal full-half gate before a candidate could be published.

This was not a manager result.

## Run 36823759095

Status: `EXECUTION_INVALID_FIXTURE_TEMPORAL_REJECTION_CONFIRMED`

Diagnostics confirmed:

- solver executed;
- solver status converged;
- zero solver/mass/admission rejection;
- three temporal rejections;
- no candidate publication.

Correction: replace the seam-isolation fixture with an equilibrium zero-top-flux state. No numerical tolerance or production contract changed.

## Run 36823910176

Status: `EXECUTION_INVALID_ADAPTER_SCRATCH_LIFECYCLE`

The default full route completed. The manager route entered the new adapter, but an unassociated reduced source-array pointer was passed to `size()` through a non-short-circuit logical expression.

Correction: split pointer-association and shape tests into nested branches.

No qualified manager candidate was produced by this run.

## Run 36824074790

Status: `EXECUTION_INVALID_BYPASS_FIXTURE_TEMPORAL_REJECTION`

The default full case and the eligible manager case both completed with converged candidates. The deliberately ineligible bypass fixture was uniform unsaturated head and therefore not zero-flux hydrostatic; the transaction temporal gate rejected it.

Correction: make only the bypass fixture unsaturated zero-flux hydrostatic. This changes no production source, manager physics, numerical tolerance or eligibility rule.

## Qualification authority

The first protocol-valid complete MIQUAL06 qualification is run `36824274774`.

None of the invalid runs above may be used as positive or negative manager qualification evidence.
