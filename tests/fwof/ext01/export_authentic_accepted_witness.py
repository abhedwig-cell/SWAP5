"""Extract an authentic accepted-pair *witness* from SWAP5's real Fortran test log.

The witness is deliberately NOT a portable dated acceptance certificate.
Never manufacture PCSE calendar alignment or invent physical units.
"""
import json
import math
import re
import sys
from pathlib import Path

NUMBER=r"([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)[Ee][+-]?[0-9]+)"
PAIR=re.compile(r"^\s*F_WOF_EXT01_ACCEPTED_PAIR\s+"+NUMBER+r"\s+"+NUMBER+r"\s*$",re.M)
UPTAKE=re.compile(r"^\s*F_WOF_EXT01_REAL_ACCEPTED_UPTAKE\s+1\s+2\s+"+NUMBER+r"\s*$",re.M)
PASS="CROP_DAYEND_ADMITTED_HYDROLOGY_ROOT_UPTAKE_BITWISE=PASS"

def extract(text):
    pair=PAIR.findall(text)
    uptake=UPTAKE.findall(text)
    if text.count(PASS)!=1 or len(pair)!=1 or len(uptake)!=1:
        raise ValueError("missing, duplicated or unsuccessful authentic SWAP acceptance witness")
    actual,potential=map(float,pair[0])
    observed=float(uptake[0])
    if not all(map(math.isfinite,(actual,potential,observed))):
        raise ValueError("nonfinite witness")
    if actual<0 or potential<0 or actual>potential:
        raise ValueError("invalid accepted flux relationship")
    if observed!=actual:
        raise ValueError("real accepted uptake does not match receipt")
    return dict(schema="F-WOF-EXT01/SWAP-WITNESS/1",
        source="test_crop_file_weather_production.f90",
        witness_column=1, source_fortran_day=2,
        actual_root_uptake_native_integral=actual,
        potential_transpiration_native_integral=potential,
        matched_accepted_uptake_native_integral=observed,
        calendar_date=None, unit_conversion_to_cm=None,
        acceptance="observed-passing-native-test",
        pcse_daily_import_permitted=False,
        reason="Native units and calendar not independently reconciled with PCSE barley case")

if __name__=="__main__":
    log=Path(sys.argv[1]).read_text()
    target=Path(sys.argv[2])
    target.write_text(json.dumps(extract(log),sort_keys=True,indent=2)+"\n")
    print("EXT01_AUTHENTIC_ACCEPTED_FLUX_WITNESS_EXPORTED",target)
