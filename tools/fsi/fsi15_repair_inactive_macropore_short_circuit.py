#!/usr/bin/env python3
from pathlib import Path
import subprocess

PATH = "src/legacy/b1_10_port/headcalc.f90"
EXPECTED = "ac6f722021556b583a4c634d6799f05aece4e6ab"

def blob_sha(path: str) -> str:
    return subprocess.check_output(["git", "hash-object", path], text=True).strip()

def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"F-SI15 repair marker mismatch {label}: expected 1, found {n}")
    return text.replace(old, new, 1)

actual = blob_sha(PATH)
if actual != EXPECTED:
    raise SystemExit(f"F-SI15 repair preimage mismatch {PATH}: {actual} != {EXPECTED}")

p = Path(PATH)
s = p.read_text()

s = replace_once(
    s,
    "         if (.NOT.flnonconv .AND. (swmacro == 0 .OR. IcTopMp > 1)) then\n",
    "         if (.NOT.flnonconv .AND. pond_balance_option_allows()) then\n",
    "pond-balance option guard",
)

old = """   else if (swmacro == 1 .AND. IDecMpRat < 3) then
!     in case of macropores, retry with reduction of exchange fluxes with matrix
      IDecMpRat  = IDecMpRat + 1
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1
      FlDecMpRat = .TRUE.
      state%dtold      = dt
      fldtmin    = .FALSE.

      if (legacy_state_binding) call publish_legacy_state(state)

      return
   else
!     write warning to screen and log file
"""
new = """   else if (macropore_exchange_retry_available()) then
!     in case of macropores, retry with reduction of exchange fluxes with matrix
      IDecMpRat  = IDecMpRat + 1
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1
      FlDecMpRat = .TRUE.
      state%dtold      = dt
      fldtmin    = .FALSE.

      if (legacy_state_binding) call publish_legacy_state(state)

      return
   else
!     write warning to screen and log file
"""
s = replace_once(s, old, new, "exchange-retry guard")

helper_marker = "real(8) function matrix_fraction(node)\n"
helpers = """logical function pond_balance_option_allows()
   if (swmacro == 0) then
      pond_balance_option_allows = .true.
   else
      pond_balance_option_allows = IcTopMp > 1
   end if
end function pond_balance_option_allows

logical function macropore_exchange_retry_available()
   if (swmacro /= 1) then
      macropore_exchange_retry_available = .false.
   else
      macropore_exchange_retry_available = IDecMpRat < 3
   end if
end function macropore_exchange_retry_available

"""
s = replace_once(s, helper_marker, helpers + helper_marker, "safe macropore helpers")
p.write_text(s)

print("F-SI15_INACTIVE_MACROPORE_SHORT_CIRCUIT_REPAIR PASS")
print(PATH, blob_sha(PATH))
