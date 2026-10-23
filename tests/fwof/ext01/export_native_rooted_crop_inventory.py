"""Audit whether native rooted-weather crop can be called the PCSE barley case.

The rooted SWAP test uses many synthetic constant tables; a three-scalar
comparison cannot establish crop identity. This audit enumerates the complete
explicit synthetic native scalar/table set and refuses a false match.
"""
from pathlib import Path
import json
import re
import sys

def audit(source):
    start=source.index("  subroutine make_bundle(bundle)")
    stop=source.index("  end subroutine make_bundle",start)
    code=source[start:stop]
    scalars=dict(re.findall(r"scalar%(\w+)\s*=\s*([\d.]+)(?:_real64)?",code))
    tables=dict(re.findall(r"call constant_table\(([\d.]+)_real64,\s*tables%(\w+)\)",code))
    if len(scalars)<15 or len(tables)<10:
        raise ValueError("incomplete rooted test crop parameter inventory")
    if (scalars["vegetative_temperature_sum_required"]!="1000.0"
        or scalars["generative_temperature_sum_required"]!="800.0"
        or scalars["development_daylength_mode"]!="1"):
        raise ValueError("rooted weather authority changed; requalify")
    return dict(schema="F-WOF-EXT01/ROOTED-NATIVE-CROP-INVENTORY/1",
        source="tests/fmig431/test_crop_file_weather_production.f90",
        scalars={k:float(v) for k,v in sorted(scalars.items())},
        constant_tables={k:float(v) for v,k in sorted(tables)},
        same_as_pcse_spring_barley_301=False,
        positive_coupled_day_admitted=False)

if __name__=="__main__":
    data=audit(Path(sys.argv[1]).read_text())
    Path(sys.argv[2]).write_text(json.dumps(data,sort_keys=True,indent=2)+"\n")
    print("EXT01_FULL_NATIVE_ROOTED_CROP_PARAMETER_INVENTORY_EXPORTED_NO_SCIENCE_ADMISSION")
