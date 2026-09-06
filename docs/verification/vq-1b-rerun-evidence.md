# VQ-1b B0 hardening rerun evidence

**Workstream:** VQ  
**Slice:** VQ-1b hardening rerun  
**B0 distribution SHA-256:** `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`  
**Production code changed:** no

The machine-readable record is `tools/vq/cases/b0-official-case-rerun-2026-09-06.json`.

## Runner boundary

The tested exact-source GNU executable has SHA-256:

```text
5eca528a3635f82713abaa360701010868834397dcdff65d57c4385bb62784d5
```

Compiler:

```text
GNU Fortran (Debian 14.2.0-19) 14.2.0
```

This runner is admitted only for case-specific regression evidence. It is not declared globally equivalent to the packaged Intel executable.

## Grass growth

The official `2.grassgrowth` case runs unchanged over 1980-01-01 through 1984-12-31.

Two fresh runs complete normally with legacy exit code `100`, `swap.ok` present and no `swap.err`. After removing only generated timestamp lines, both produce:

```text
result_output.csv
0a7025b72abbb524760107ca1f0309d8e241a7aa2830bb983afe9245730dec7e
```

A balance-output-only variant enabling `SWBAL` and `SWBLC` also repeats exactly. Its normalized hashes are:

```text
result.bal  7fae2e0c1652aa8db55c2a981bfd21c9917509a9e03345d252d01064da90d1cf
result.blc  58b43ddb970a4581a5501382dad58ef25992e8d094a873be7391f9c33974b422
```

All printed BLC deviations are zero, while one BAL period gives a rounded residual of `0.01 cm`. This is direct evidence that rounded BAL arithmetic is not a machine-precision mass oracle.

## Macropore flow

The full official `3.macroporeflow` case was retried under an explicit 240-second VQ budget. It reached the budget without `swap.ok`, with an empty `swap.err`, and had advanced output through 1999-01-18.

Classification:

```text
NOT_YET_QUALIFIED_BOUNDED_RUNTIME
```

No model failure is inferred.

A 31-day TEND-only process-path variant plus balance output completes twice in about 19 seconds and repeats exactly. Normalized hashes include:

```text
result_output.csv     b09e200702e1c90540816bbf2ce9e11fb1f66b2b946fb7b8e750cf98afb092e6
macrogeom.csv         fae37fe8453e7481e9b9db88b097e98fb57fc66a5d82a7612afb7af0d32ba9b9
soilshrinkchar.csv    3be3a4b72a586822dbea1bb4319bc04ed45f2ebd7d52b20200e87cecb1a4bd38
result.bal            93f0cbba5177ceb403a038d25c81ac0eb2506648d068dfbd3b1beea52bcf6629
result.blc            e4649b81246bf3493948ac5292ef2e8640433ea75cf39a4a146da602976fdd13
```

The partial-period legacy BAL/BLC metadata reports start date `1900-01-01` while physical `TSTART` is 1998-01-01. VQ records this as diagnostic-only legacy report metadata, not as a B0/B1 physics difference.

## Salinity stress

The bundled R runtime is unavailable. The three run definitions were reconstructed from the bundled workbook and their irrigation tables were checked row-for-row against `datamodel.xlsx`:

```text
04dS  581 rows
08dS  579 rows
16dS  583 rows
```

The reconstructed inputs are therefore stronger than an unchecked manual reconstruction, but remain provisional until byte-cross-checked with the official R-generated run directories.

With unchanged vector CSV output, all three scenarios are rejected by the provisional GNU runner on the known `S_CONC` vector-metadata portability limitation. This remains a runner/compiler capability boundary, not a confirmed B0 physical defect.

With explicit output-only changes `SWCSV=0`, `SWBAL=1`, `SWBLC=1`, all three scenarios run twice and reproduce their BAL/BLC hashes exactly. All printed BLC deviations are zero. Rounded BAL residuals include values of `-0.01`, `0.00` and `+0.01 cm`, again confirming the report-resolution limitation.

## Qualification boundary

```text
full official grass-growth GNU regression   PASS
full official macropore case                NOT YET QUALIFIED: bounded runtime
31-day macropore process path               PASS + repeatability
salinity reconstructed process path         PROVISIONAL PASS after output-only workaround
legacy BAL/BLC accounting                   regression evidence only
hard invariant-13 mass gate                 NOT SATISFIED by legacy report precision
```

No production physics, solver policy or SWAP5 runtime code was changed by this work.
