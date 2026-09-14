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
]

changed = 0
for path, old, new in changes:
    text = path.read_text()
    if new in text:
        print(f'FMR44_ALREADY_PATCHED {path}')
        continue
    if text.count(old) != 1:
        raise SystemExit(f'FMR44_PATCH_ANCHOR_MISMATCH {path} count={text.count(old)}')
    path.write_text(text.replace(old, new, 1))
    changed += 1
    print(f'FMR44_PATCHED {path}')

print(f'FMR44_PRODUCTION_ADMISSION_PATCH_COUNT={changed}')