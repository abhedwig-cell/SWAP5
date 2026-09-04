# SWAP 4.3.1 baseline

## Purpose of this page

This page records facts about the supplied SWAP 4.3.1 distribution so that target-architecture documentation is not confused with the current implementation.

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

## Documentation rule

When a page discusses implementation, it should identify whether it refers to:

- **SWAP 4.3.1 baseline**;
- **transitional refactoring code**;
- **target architecture**.

This prevents design intent from being mistaken for already delivered functionality.
