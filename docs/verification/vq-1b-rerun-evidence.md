# VQ-1b hardening rerun evidence

## Integration record

```text
WORKSTREAM: VQ
SLICE: VQ-1b-hardening-rerun
B0 IDENTITY: 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
MAIN RE-READ: ce280e110c637a087d2a1aabd70fca5f1d494e48
CURRENT CORRECTED REFERENCE OBSERVED ON MAIN: B1.4
PRODUCTION CODE CHANGED: no
INTERFACES CHANGED: no
INVARIANTS EXERCISED: 13, 25, 29, 30
```

This addendum records an independent repeat of the additional official B0 case hardening after the earlier VQ-1b pass. It deliberately does not overwrite the concurrently advancing VQ-1c/B1 work on the same branch.

The runner remains the provisional exact-B0-source GNU build:

```text
GNU Fortran (Debian 14.2.0-19) 14.2.0
executable sha256: 5eca528a3635f82713abaa360701010868834397dcdff65d57c4385bb62784d5
```

This is case-specific regression evidence only. It is not a declaration of full equivalence to the packaged Intel executable.

## Grass growth

The official `2.grassgrowth` input was rerun twice without any input change over the full interval 1980-01-01 through 1984-12-31.

```text
official swap.swp sha256:
2f21cc9d269b435a9b20d1072bce6433b945946cd72ebebd5285c67acb2ab196

both runs: legacy exit code 100 + swap.ok
swap.err: absent
```

The raw CSV files differ only in the generated timestamp. After removing only lines beginning `* Generated at:` both runs are byte-identical:

```text
result_output.csv sha256:
0a7025b72abbb524760107ca1f0309d8e241a7aa2830bb983afe9245730dec7e
```

A second pair of runs enabled only `SWBAL=1` and `SWBLC=1`. They also repeated exactly:

```text
variant swap.swp sha256:
03346e0002e06ee69aadfca4a5c9ce7c0894cf02bdd6a95b5e34f8e3e2342131

result.bal sha256:
7fae2e0c1652aa8db55c2a981bfd21c9917509a9e03345d252d01064da90d1cf

result.blc sha256:
58b43ddb970a4581a5501382dad58ef25992e8d094a873be7391f9c33974b422
```

All five `.BLC` periods print zero balance deviation. The rounded `.BAL` arithmetic nevertheless gives `0.01 cm` in the first period. This is expected from independently rounded report fields and is further evidence that legacy BAL/BLC output cannot be the hard invariant-13 oracle.

## Macropore flow

The full official case was started again from the exact official input:

```text
official interval: 1998-01-01 through 1999-04-26
official swap.swp sha256:
c87ef0f8561f90277a2ae22f74fd12e050e4cafb26cb3b475768a737c76c059b
```

A hard VQ execution budget of 240 seconds was applied. The process reached the budget before normal completion:

```text
timeout exit code: 124
swap.ok: absent
swap.err: empty
last flushed result date: 1999-01-18
```

Classification remains:

```text
full official macropore case: NOT_YET_QUALIFIED_BOUNDED_RUNTIME
model failure:                NOT ESTABLISHED
```

No partial output from the timed-out run is admitted as reference evidence.

The 31-day process-path smoke was repeated twice with only:

```text
TEND  = 1999-04-26 -> 1998-01-31
SWBAL = 0 -> 1
SWBLC = 0 -> 1
```

Both runs completed normally in approximately 19 seconds and produced byte-identical normalized outputs:

```text
variant swap.swp sha256:
c91bf394536af432d8b9e6b5f16964c426f1b83cdcc979081e25bf4fc781b878

result_output.csv:
b09e200702e1c90540816bbf2ce9e11fb1f66b2b946fb7b8e750cf98afb092e6

macrogeom.csv:
fae37fe8453e7481e9b9db88b097e98fb57fc66a5d82a7612afb7af0d32ba9b9

soilshrinkchar.csv:
3be3a4b72a586822dbea1bb4319bc04ed45f2ebd7d52b20200e87cecb1a4bd38

result.bal:
93f0cbba5177ceb403a038d25c81ac0eb2506648d068dfbd3b1beea52bcf6629

result.blc:
e4649b81246bf3493948ac5292ef2e8640433ea75cf39a4a146da602976fdd13
```

The `.BLC` deviation prints zero. The short partial-period BAL/BLC files report a period start of `1900-01-01` even though physical `TSTART` is `1998-01-01`. VQ treats this as diagnostic-only legacy partial-period metadata. It is not admitted as a B0/B1 difference and the parser must not infer physical start state solely from that report header.

## Salinity stress

The bundled workbook defines:

```text
run 1 -> irrigation_id 2 -> 04dS
run 2 -> irrigation_id 3 -> 08dS
run 3 -> irrigation_id 5 -> 16dS
```

The reconstructed scenario inputs were checked row-by-row against `datamodel.xlsx`. Every generated `IRDATE`, `IRDEPTH`, `IRCONC` and `IRTYPE` row matches the corresponding workbook irrigation table.

```text
04dS: 581 rows, PASS
08dS: 579 rows, PASS
16dS: 583 rows, PASS
```

This strengthens preprocessing provenance but does not replace the still-missing byte comparison against an official R-generated run directory.

All three reconstructed inputs were rerun unchanged. They are rejected by the provisional GNU runner on the already-localized vector-CSV portability limitation:

```text
ERROR in csv_write: Item S_CONC in userlist not known in vars%name. Adjust inlist_csv!
```

For all three runs:

```text
process exit code: 0
swap.ok: absent
swap.err: 1024 bytes
```

This illustrates why VQ acceptance uses the full completion contract and never process exit code alone.

With only the explicit output changes `SWCSV=0`, `SWBAL=1`, `SWBLC=1`, all three scenarios were run twice and completed normally. Normalized BAL/BLC hashes match their earlier VQ-1b results exactly:

| Scenario | BAL SHA-256 | BLC SHA-256 |
| --- | --- | --- |
| 04dS | `372f38a23061d0726daeb94cefd123b83c93957780b740f65ac8947c14fce99d` | `7bb9cffc0214eb50df255db67d0c4b04592dfd8b4b4a4fa2e1743c941df07428` |
| 08dS | `17bc8687d287b6cfc3c5c9b8e9f1e7aad9dd266cfe9399a9c6e3e790f21a69aa` | `c0bf9c2a694d76d370198b8bda7fd5a624e7b54533120a7cce8728c2295e5e34` |
| 16dS | `a342beed8858447f442e5dbab00672cdee3bc4dd559edd590362917ae65f29e9` | `3fc00b97389db093c07708b46f3cf0db9208fe7fa31d91f002ead641310fd9c5` |

Every `.BLC` annual record prints zero deviation. Rounded `.BAL` residuals include values of `-0.01 cm` and `+0.01 cm` in some years, again confirming the report-precision boundary.

## Rerun conclusion

```text
Grass full official case                          PASS, repeatable
Grass balance-output variant                     PASS, repeatable
Macropore full official case                     NOT YET QUALIFIED, bounded runtime
Macropore 31-day process-path + balance smoke    PASS, repeatable
Salinity workbook-table reconstruction check     PASS
Salinity unchanged vector-CSV route              REJECTED by known GNU portability boundary
Salinity balance-only process-path smoke         PROVISIONAL PASS, repeatable
Legacy BAL/BLC hard invariant-13 gate             NOT ELIGIBLE
Production code changes                           NONE
```

The rerun strengthens VQ-1b without changing its fundamental qualification boundary. The full macropore case remains a benchmark-environment task. The salinity case still needs official R-preprocessor byte cross-checking for a stronger native B0 preprocessing oracle.

Current `main` has meanwhile advanced to corrected reference `B1.4` at commit `ce280e110c637a087d2a1aabd70fca5f1d494e48`. Any subsequent VQ-1c pin must use the accepted current B1 snapshot rather than an older B1.3 assumption.
