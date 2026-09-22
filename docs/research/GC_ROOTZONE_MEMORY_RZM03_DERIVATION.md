# GC-RZM03 bidirectional signed-transfer derivation

Date: 2026-09-22  
Status: MATHEMATICS FROZEN BEFORE IMPLEMENTATION  
Prerequisite: GC-RZM01 and GC-RZM02 qualified

## Purpose

RZM03 qualifies Phase E without adding a new process law. The same two signed
linear transfers already used in RZM01 are exercised in both directions:

```text
q_v = C_v (h_r-h_l)
q_c = C_c (h_l-H_c)
```

Positive is downward. Negative is upward. No direction switch, separate
capillary formula or clipping operator is allowed.

## Sign and ledger contract

For every window:

```text
Delta W_r = F_r - E_v
Delta W_l = F_l + E_v - E_c
Delta W_SW = F_r + F_l - E_c.
```

Thus a negative `E_v` increases root storage and decreases lower storage.
A negative `E_c` is MODFLOW-to-SWAP supply and increases total SWAP water.

For a coupled MODFLOW storage cell:

```text
Delta W_M = F_M + E_c.
```

So negative `E_c` reduces MODFLOW storage. The complete ledger still cancels
the fixed-plane transfer exactly.

## Frozen experiments

All use the canonical parameters

```text
S_r=0.20, S_l=0.10, C_v=0.50/day, C_c=0.25/day
W_r,ref=0.100 m at h_r,ref=8.0 m
W_capacity=0.200 m.
```

### RZM03-A downward drainage

Start:

```text
W_r=0.120 m -> h_r=8.10 m
h_l=8.00 m
H_c=8.00 m
forcing=0
T=0.5 d.
```

Expected signs:

```text
E_v > 0
E_c > 0
Delta W_r < 0.
```

Frozen targets are computed from the exact matrix oracle before implementation.

### RZM03-B capillary supply from lower SWAP to root zone

Start:

```text
W_r=0.080 m -> h_r=7.90 m
h_l=8.05 m
H_c=8.05 m
forcing=0
T=0.5 d.
```

Initially `q_v<0` and `q_c=0`. Water must move upward into the root zone.
Because the lower state subsequently changes, the fixed-plane exchange may
become nonzero; its sign must follow the same law rather than be prescribed.

### RZM03-C upward supply from MODFLOW

Start at internal equilibrium:

```text
W_r=0.100 m -> h_r=8.00 m
h_l=8.00 m
H_c=8.10 m
forcing=0
T=0.5 d.
```

Initially `q_c<0`. The accepted integrated `E_c` must be negative and total
SWAP water must increase by `-E_c`.

### RZM03-D exact zero-flux equilibrium

```text
h_r=h_l=H_c=8.0 m
forcing=0.
```

Both signed transfers and both storage changes are exactly zero to numerical
precision for any tested duration.

### RZM03-E gradient reversal without a direction switch

Start with `h_r<h_l=H_c`. Capillary supply raises `h_r` and lowers `h_l`.
Use a sufficiently long window to show that the instantaneous root/lower
gradient approaches zero continuously without any branch in the constitutive
law.

A second case starts with `h_r>h_l=H_c` and approaches from the downward side.

The test is not required to cross through equilibrium in this autonomous
zero-forcing case because a stable linear diffusion system approaches the
equilibrium asymptotically. The falsification target is continuity and correct
sign on both sides, not an artificial finite-time sign flip.

### RZM03-F coupled groundwater capillary ledger

Use a groundwater storage cell with zero external input and an initial head
above the dry SWAP state. Solve the same finite-window coupled residual used in
RZM01.

The accepted result must simultaneously satisfy:

```text
E_c < 0
Delta W_SW > 0
Delta W_M < 0
Delta W_SW + Delta W_M = 0.
```

This is the direct negative-flux counterpart of the earlier downward exchange
ledger.

## Scientific decision gate

If all experiments pass, Phase E is qualified for the linear surrogate:
downward drainage and upward capillary supply are two signs of the same transfer
law, and no extra persistent state or direction-specific interface variable is
needed.

That conclusion is bounded to the linear model. It does not claim that real
unsaturated conductivity is symmetric or linear in head difference.
