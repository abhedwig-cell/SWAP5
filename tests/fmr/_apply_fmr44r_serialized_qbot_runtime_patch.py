from pathlib import Path

changes = [
    (
        Path('src/adapter/mod_b110_serialized_context_binding.f90'),
        """    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2 .and. &
        request%boundary%bottom_mode /= 5) return
""",
        """    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2 .and. &
        request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2) return
""",
    ),
    (
        Path('src/runtime/mod_fmr_serialized_reference_backend.f90'),
        """      ok = ok .and. (parameters%bottom_mode == 7 .or. parameters%bottom_mode == -2 .or. parameters%bottom_mode == 5) .and. &
""",
        """      ok = ok .and. (parameters%bottom_mode == 7 .or. parameters%bottom_mode == -2 .or. parameters%bottom_mode == 5 .or. &
           parameters%bottom_mode == 2) .and. &
""",
    ),
    (
        Path('src/runtime/mod_fmr_serialized_reference_backend.f90'),
        """    if (self%bottom_mode /= 7 .and. self%bottom_mode /= -2 .and. self%bottom_mode /= 5) then
      value = huge(0.0_real64)
      return
    end if
""",
        """    if (self%bottom_mode /= 7 .and. self%bottom_mode /= -2 .and. self%bottom_mode /= 5 .and. &
        self%bottom_mode /= 2) then
      value = huge(0.0_real64)
      return
    end if
""",
    ),
]

changed = 0
for path, old, new in changes:
    text = path.read_text()
    if new in text:
        print(f'FMR44R_ALREADY_PATCHED {path}')
        continue
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FMR44R_PATCH_ANCHOR_MISMATCH {path} count={count}')
    path.write_text(text.replace(old, new, 1))
    changed += 1
    print(f'FMR44R_PATCHED {path}')

print(f'FMR44R_PRODUCTION_ADMISSION_PATCH_COUNT={changed}')
