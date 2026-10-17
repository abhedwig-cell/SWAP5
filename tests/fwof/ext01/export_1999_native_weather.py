"""Export an independently dated 1999 source-weather observation from native SWAP log.

Research-only: source meteorology is not a PCSE forcing conversion.
"""
import json
import math
import re
import sys
from pathlib import Path
PATTERN = re.compile(r"^\s*F_WOF_EXT01_PHYSICAL_SOURCE_WEATHER\s+(\d{8})\s+" +
                     r"\s+".join([r"([+-]?\d+(?:\.\d*)?[Ee][+-]?\d+)"]*5) + r"\s*$",re.M)
def extract(log):
    matches=PATTERN.findall(log)
    if len(matches)!=1: raise ValueError("expected one native 1999 weather witness")
    date,*numbers=matches[0]
    if date!="19990123": raise ValueError("wrong source calendar")
    values=[float(x) for x in numbers]
    if not all(map(math.isfinite,values)): raise ValueError("nonfinite meteorology")
    if values[0]>values[1] or values[2]<0 or values[4]<0:
        raise ValueError("physically invalid meteorology")
    return dict(schema="F-WOF-EXT01/SWAP-SOURCE-WEATHER/1",
                date="1999-01-23", source="native-file-weather-record",
                tmin_c=values[0],tmax_c=values[1],
                rain_source_units=values[2],reference_et_source_units=values[3],
                radiation_source_j_m2_day=values[4],
                pcse_weather_conversion_qualified=False,
                pcse_crop_day_admitted=False)
if __name__=="__main__":
    output=extract(Path(sys.argv[1]).read_text())
    Path(sys.argv[2]).write_text(json.dumps(output,indent=2,sort_keys=True)+"\n")
    print("EXT01_1999_AUTHENTIC_SOURCE_WEATHER_EXPORTED_NO_PCSE_ADMISSION")
