# SWAP-006: meteo crop-calendar sentinel dependence

B1 status: **ADMISSION CANDIDATE**

Audit status: **FIX_TESTED**

## Defect

In B0 `MOD_meteo.f90`, the dynamic-crop meteo-loading loop is open-ended and terminates partly because unused `cropstart` entries are expected to be zero:

```fortran
i = 1
do while (tend - cropstart(i) > 0.d0)
   if (cropstart(i) < 1.d0) exit
   ...
   i = i + 1
end do
```

That is an implicit dependency on compiler/runtime initialization rather than the actual number of loaded crop records.

## Correction

Bound the iteration explicitly by `ifnd`, while preserving the existing early-exit semantics:

```fortran
do i = 1, ifnd
   if (tend - cropstart(i) <= 0.0d0) exit
   if (cropstart(i) < 1.0d0) exit
   ...
end do
```

## Exact identities

```text
B0 file: SWAP/MOD_meteo.f90
B0 SHA-256: 5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822
B0 bytes: 85550

minimal fix.patch SHA-256:
558eb084befac713aec0b923d45182a1efcbed44d71ed00e6faf024b6540718a

patched MOD_meteo.f90 SHA-256:
99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f
patched bytes: 85541
```

The patch is isolated from the audited `SWAP_4.3.1_proposed_fixes.patch` and checked against the byte-exact B0 preimage.

## Qualification

The central issue register classifies SWAP-006 as `FIX_TESTED`, certainty high, severity medium. A NaN-initialized test exposed the hidden initialization dependency; the patched build passes.

## Classification

- implementation/portability defect: yes
- physics/model change: no
- crop-calendar semantics: unchanged for valid loaded records
- expected B0-to-B1 difference: execution no longer depends on zero-initialized unused crop entries
- mass-balance concession: none
