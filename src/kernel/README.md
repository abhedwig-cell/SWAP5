# SWAP5 kernel source boundary

This directory is the production-facing kernel boundary for SWAP5.

## Current status

`KRS-1` adds only the typed kernel seam contract in `swap5_kernel_seam.f90`.

```text
contract                         PRESENT / COMPILE-CHECKED
concrete SWAP physics            ABSENT
full-Richards implementation     ABSENT
runtime commit/rollback          ABSENT
B2 reference admission           BLOCKED
```

The source constant `SWAP5_KERNEL_IMPLEMENTATION_STATUS` intentionally remains:

```text
DEFERRED_NO_KERNEL_IMPLEMENTATION
```

That marker must not be changed merely because an adapter or test fixture exists. It changes only when an actual production kernel implementation is integrated and qualified for the stated scope.

## Ownership

The kernel trial receives separate parameter, committed-state, forcing and numerical-config domains. Worker scratch and result storage are caller/runtime-owned. Commit, rollback, retry policy, batching, coupling composition, file I/O and serialization stay outside this module.

The single `swap5_kernel_t` seam is shared by reference, balanced and throughput numerical policies. A policy must not create a second physical SWAP kernel.
