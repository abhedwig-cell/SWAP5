# SWAP 4.3.1 baseline

## Purpose of this page

This page records facts about the supplied SWAP 4.3.1 distribution so that target-architecture documentation is not confused with the current implementation.

For formal SWAP 5 verification, this supplied distribution is the immutable **B0 audit baseline**. The B0/B1/B2 policy and exact cryptographic identities are recorded under [Reference baselines](../verification/reference-baselines.md).

## B0 identity

The baseline distribution used by the technical audit is identified by:

```text
SWAP_4.3.1.zip
SHA-256 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

The nested Fortran source archive is identified by:

```text
tools/SWAP/source/SWAP.ZIP
SHA-256 1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
```

These hashes, rather than the version label alone, define the exact B0 audit source.

## Distribution layout

In the supplied SWAP 4.3.1 package, executable files and source archives are located under:

```text
tools/SWAP/
```

The Fortran source is distributed as:

```text
tools/SWAP/source/SWAP.ZIP
```

That archive contains the current Fortran modules and procedures. Representative files include:

```text
swap.f90
swap_main.f90
headcalc.f90
soilwater.f90
timecontrol.f90
variables.f90
readswap.f90
swapoutput.f90
oxygenstress.f90
macropore.f90
```

The package also contains example cases, data files, compiled executables and change documentation.

## Architectural interpretation

The existence of `readswap.f90`, `swapoutput.f90`, broad shared-variable modules and file-oriented distribution conventions is a property of the legacy baseline. It is not a requirement for the new kernel.

The modernization strategy is therefore incremental:

1. preserve verified SWAP physics;
2. make state, forcing, numerical configuration and results explicit;
3. isolate side effects and legacy control flow behind adapters;
4. establish clean module interfaces before changing storage layout aggressively;
5. keep the legacy file interface available outside the kernel for compatibility.

## Bug-compatible behaviour is not a target invariant

B0 remains available to reproduce historical SWAP 4.3.1 behaviour. When a legacy implementation defect is proven and qualified, the correction belongs to the B1 corrected-reference line. SWAP 5 reference mode is then verified against B1 rather than deliberately reintroducing the B0 defect.

## Documentation rule

When a page discusses implementation, it should identify whether it refers to:

- **B0 / SWAP 4.3.1 baseline**;
- **B1 / corrected SWAP 4.3.1 reference**;
- **transitional refactoring code**;
- **B2 / SWAP 5 reference implementation**;
- **target architecture**.

This prevents design intent, legacy defects and qualified corrections from being mistaken for one another.
