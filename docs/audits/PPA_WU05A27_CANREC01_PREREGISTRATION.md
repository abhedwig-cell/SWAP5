# PPA-WU05-A27-CANREC01 preregistration — MIGMAC01 storage allocation guard

Date: 2026-10-02
Status: PREREGISTERED_BEFORE_REPAIR
Parent: `6f902b34b2c3c0a0737712ba1b177ed7dfffafc4`
Canonical source baseline: `9abdc23f759f4d7711881d535797d0ee56d67584`

## Trigger

After explicit A27/MIGMAC01 three-way reconciliation, A26 live, the A27 current-canonical backend compile gate, A8 standard macropore and PROFILE01 all pass. The full ABC screen segfaults before its first record.

Debug-symbol run `36999130548` locates the fault at `mod_fmr_serialized_reference_backend.f90:3326` in `fmr_serialized_storage()`.

## Defect

The new MIGMAC01 storage branch combines:
- `self%macropore_active`;
- `allocated(self%macropore_config)`;
- `allocated(self%macropore_config%matrix_area_fraction)`

in one `.and.` expression.

Fortran does not guarantee short-circuit evaluation. When `macropore_config` is unallocated, evaluating the third operand is an invalid component dereference. ABC arm A reaches this path immediately and segfaults.

## Authorized repair

Replace only the unsafe compound allocation test with nested guards:
1. test `macropore_active` and allocation of `macropore_config`;
2. only inside that allocated branch inspect `matrix_area_fraction`;
3. retain the exact MIGMAC01 area-weighted storage expression when the fraction exists;
4. retain ordinary full-area matrix storage otherwise.

No RFM, macropore physics, storage formula, parameter or benchmark threshold may change.

## Gates

- A26 live PASS;
- A27 current-canonical backend compile PASS;
- A8 standard macropore PASS;
- ABC no longer crashes;
- PERF02 non-timing identity remains required against qualified ABC01 baseline.
