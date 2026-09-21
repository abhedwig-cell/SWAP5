# NH06 preregistration — compensated through-flow

Date: 2026-09-21
Status: PREREGISTERED, NOT YET EXECUTED
Production changes: none

## Question

Can the fixed-interface coupling preserve a substantial physical SWAP-to-MODFLOW transfer when an approximately equal MODFLOW abstraction makes the net groundwater storage change small or zero?

The experiment is deliberately designed to falsify any hidden identification of interface transfer with groundwater storage change.

## Topology and signs

Use the fixed geometric coupling interface and the NH01 linear top-system response.

- E_c > 0: physical transfer from SWAP/top system into MODFLOW across the coupling interface.
- P > 0: external MODFLOW abstraction.
- W_M = -P in the groundwater balance.
- No physical inventory is shared between the two control volumes.

Balances:

    Delta V_S = W_S - E_c
    Delta V_M = E_c - P

and therefore:

    Delta V_S + Delta V_M = W_S - P

The internal interface transfer E_c must cancel exactly from the combined balance even when Delta V_M=0.

## NH06-A exact compensated control

Parameters:

    S_S = 0.10
    S_M = 0.10
    C = 0.20/day
    dt = 1 day
    H0 = z_p0 = 8.0 m
    W_S = 0.010 m
    P = 0.004 m

The NH01 eliminated interface law is:

    E_c(H) = beta * [W_S + S_S*(z_p0-H)]
    beta = C*dt/(S_S+C*dt) = 2/3

Groundwater equation:

    S_M*(H-H0) = E_c(H) - P

For P=0.004 m the exact solution is:

    H = 8.0 m
    E_c = 0.006666666666666667 m
    Delta V_M = 0.002666666666666667 m

This is not exactly compensated. Therefore the exact compensation P must be solved self-consistently rather than copied from the NH01 no-pumping transfer.

For exact zero groundwater storage change H=H0, hence:

    P_comp = E_c(H0) = beta*W_S = 0.006666666666666667 m

The preregistered compensated control is therefore:

    P = 0.006666666666666667 m
    H = 8.0 m
    E_c = 0.006666666666666667 m
    Delta V_M = 0
    Delta V_S = 0.003333333333333333 m
    combined storage change = 0.003333333333333333 m
    external net input W_S-P = 0.003333333333333333 m

This is the primary NH06 falsification state: nonzero interface transfer with exactly zero groundwater storage change.

## NH06-B under-abstraction

Set:

    P = 0.8 * P_comp

Expected: Delta V_M > 0 and H > H0.

## NH06-C over-abstraction

Set:

    P = 1.2 * P_comp

Expected: Delta V_M < 0 and H < H0.

## Analytical root

For arbitrary P:

    S_M*(H-H0) = beta*[W_S + S_S*(z_p0-H)] - P

with z_p0=H0:

    (S_M + beta*S_S)*(H-H0) = beta*W_S - P

therefore:

    H-H0 = (beta*W_S-P)/(S_M+beta*S_S)

and:

    E_c = beta*[W_S-S_S*(H-H0)]

## Gates

1. NH06-A must have |Delta V_M| <= 1e-12 m while E_c > 1e-3 m.
2. Component balances must close independently.
3. Combined balance must close after E_c cancels.
4. NH06-B and NH06-C must produce opposite-signed groundwater storage changes.
5. E_c must never be inferred from Delta V_M alone.
6. The later live MODFLOW fixture must represent P as a separate external groundwater sink, not by modifying the coupling intercept.
7. No production response/sign semantics may be changed to obtain a pass.

## Extension after the control

After NH06-A/B/C, make the SWAP-side transfer state dependent. This second stage asks whether a head-dependent process contribution is carried correctly in the condensed response while pumping remains an independent groundwater forcing. It is not admitted until the constant-process through-flow control is closed.
