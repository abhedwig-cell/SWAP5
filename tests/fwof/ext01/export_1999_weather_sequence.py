"""Export source meteorology on seven consecutive authentic SWAP physical days."""
import datetime as dt
import json
import math
import re
import sys
from pathlib import Path
FLOAT=r"([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)[Ee][+-]?[0-9]+)"
PAT=re.compile(r"^\s*F_WOF_EXT01_1999_SOURCE_SEQUENCE\s+(\d{8})\s+"+r"\s+".join([FLOAT]*5)+r"\s*$",re.M)

def extract(log):
    rows=PAT.findall(log)
    if len(rows)!=14:
        raise ValueError("seven weather records in each of two independent physical repetitions required")
    expected=[(dt.date(1999,1,20)+dt.timedelta(days=d)).strftime("%Y%m%d") for d in range(7)]
    for j in range(2):
        for d in range(7):
            record=rows[7*j+d]
            if record[0]!=expected[d] or record!=rows[d]:
                raise ValueError("physical source weather date/independent repetition mismatch")
    result=[]
    for record in rows[:7]:
        date,*raw=record
        vals=list(map(float,raw))
        if not all(map(math.isfinite,vals)) or vals[0]>vals[1] or vals[2]<0 or vals[4]<0:
            raise ValueError("invalid native meteorology")
        result.append(dict(date=dt.datetime.strptime(date,"%Y%m%d").date().isoformat(),
                           tmin_c=vals[0],tmax_c=vals[1],rain_native=vals[2],
                           etref_native=vals[3],radiation_j_m2_day=vals[4]))
    return dict(schema="F-WOF-EXT01/SWAP-1999-WEATHER-SEQUENCE/1",
                source="real accepted-hydrology production Fortran test",
                independent_repetitions=2,records=result,
                unit_conversion_to_pcse_qualified=False,
                crop_initial_state_matched=False,
                physical_crop_coupling_admitted=False)

if __name__=="__main__":
    result=extract(Path(sys.argv[1]).read_text())
    Path(sys.argv[2]).write_text(json.dumps(result,sort_keys=True,indent=2)+"\n")
    print("EXT01_NATIVE_1999_SEVEN_DAY_SEQUENCE_EXPORTED_NO_PCSE_SCIENCE_ADMISSION")
