# F-MACRO-ALT55 — conservative-tracer forward-ledger contract

Date: 2026-10-01

Status: QUALIFIED_COMPOSITION_CONTRACT / MATRIX_SOLUTE_OWNER_REQUIRED / MB_WALL_OWNER_REQUIRED

## Purpose

Create the full mass-accounting skeleton required by ALT54 without inventing missing physics.

The harness composes:

    applied tracer
      -> matrix source
      -> preferential source
          -> IC
          -> MB

and requires explicit publication of:

    matrix retained tracer profile
    IC endpoint tracer profile
    MB wall-retained tracer profile
    MB below-profile receipt.

## Frozen IC route

For p and normalized depth-bin edges:

    F_end(x)=x^p

so the IC tracer mass in bin [a,b] is:

    M_IC,bin
      = M_IC * (b^p-a^p).

This is exactly the endpoint-mass law held-out validated in ALT52.

## Explicit ownership

The harness does not compute matrix tracer transport.

Instead a matrix-solute owner must provide a profile whose sum exactly equals:

    M_matrix = M_applied * (1-F_pref).

Likewise the harness does not replace the frozen MB wall-exchange physics with an arbitrary retention fraction.

A wall/routing owner must provide:

    MB wall-retained tracer by depth
    + MB below-profile receipt

and these must close:

    M_MB = M_pref * f_MB.

## Hard tracer ledger

The contract requires:

    M_applied
      = M_matrix_retained
      + M_IC_retained
      + M_MB_wall_retained
      + M_MB_bottom

to floating-point tolerance.

Any missing contribution fails closed.

## Why this matters

ALT53 showed that 95-96% bromide recovery cannot be converted directly to f_MB because activation and MB wall retention are confounded.

ALT55 turns that conceptual statement into an executable ownership contract.

It prevents later code from silently assigning all unrecovered tracer to MB bottom flow or using f_MB as a residual mass balancer.

## Current real-data blocker

The RFM research line now has:

- surface activation diagnostics;
- endpoint routing;
- conservative IC tracer depth law;
- absolute applied/recovered tracer constraints.

What it still lacks for a full Spechtacker absolute forward fit is a qualified matrix-solute transport owner and a source-bound MB tracer wall-exchange publication in the same sampling bins.

Those are process-composition gaps, not reasons to add new RFM parameters.

## Decision

    TRACER_LEDGER = QUALIFIED
    IC_ENDPOINT_MASS_OWNER = DEFINED
    MATRIX_PROFILE_OWNER = REQUIRED
    MB_WALL_PROFILE_OWNER = REQUIRED
    MB_BOTTOM_RECEIPT = EXPLICIT
    RESIDUAL_FITTING_VIA_f_MB = FORBIDDEN
    NEW_PHYSICS = NONE

## Next

Before attempting an absolute f_MB fit, audit whether the current SWAP5/ANIMO or existing research code already exposes a conservative solute/tracer transport owner suitable for the matrix profile.

If no such owner exists in SWAP5, keep the absolute tracer fit as a research-composition blocker rather than introducing a toy advection-dispersion model into RFM.
