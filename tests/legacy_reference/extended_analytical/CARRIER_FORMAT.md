# Carrier format

`asset_parts/` contains four exact, newline-free Base64 fragments of one deterministic `tar.gz` payload. Concatenate them in lexical filename order and decode Base64 to recover `F-TB13_RECOVERED_ANALYTICAL_ASSETS.tar.gz`.

Decoded identity:

- bytes: 17,122
- SHA-256: `57a75c64e1b057223fbd32ac3051a2c56938209f19b86912d7236f4f1d5fc069`

Encoded carrier size: 22,832 bytes.

Use `check_preservation.py` as the fail-closed decoder/verifier. Do not edit, rewrap or add newlines to individual carrier parts.
