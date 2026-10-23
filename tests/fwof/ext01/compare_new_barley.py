import csv,json,math,sys
from pathlib import Path
native=list(csv.DictReader(open(sys.argv[1],newline="")))
reference=list(csv.DictReader(open(sys.argv[2],newline="")))
fields=("DVS","LAI","NamountLV","NamountRT","NamountSO","NamountST","NuptakeTotal","TAGP","TWLV","TWRT","TWSO","TWST")
assert len(native)==len(reference)==61
result={"status":"RESEARCH_DIAGNOSTIC_NOT_QUALIFIED","rows":61,"variables":{}}
for field in fields:
    delta=[]
    for i,(x,y) in enumerate(zip(native,reference),1):
        a,b=float(x[field]),float(y[field])
        assert math.isfinite(a) and math.isfinite(b)
        delta.append((abs(a-b),i,a,b))
    m=max(delta)
    first=next(((i,a,b,a-b) for distance,i,a,b in delta if distance>1e-12),None)
    result["variables"][field]={"maximum_absolute_difference":m[0],"day_index":m[1],"fortran":m[2],"python":m[3],"first_difference_above_1e_minus_12":None if first is None else {"day_index":first[0],"fortran":first[1],"python":first[2],"signed_difference":first[3]}}
Path(sys.argv[3]).write_text(json.dumps(result,indent=2)+"\n")
print("EXT01_DIFFERENCE_REPORT",json.dumps(result["variables"],sort_keys=True))
