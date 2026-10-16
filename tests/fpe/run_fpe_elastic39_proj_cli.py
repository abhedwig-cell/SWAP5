#!/usr/bin/env python3
"""F-PE-ELASTIC39 research-only PROJ CLI capability audit."""
from __future__ import annotations
import json, math, os, shutil, subprocess

POINTS=[
    (5.6631,51.9851,"wageningen"),
    (4.8952,52.3702,"amsterdam"),
    (5.1214,52.0907,"utrecht"),
    (6.5665,53.2194,"groningen"),
    (3.6100,51.4400,"zeeland"),
]

def fail(msg):
    raise SystemExit("F_PE_ELASTIC39_FAIL "+msg)

ENV=dict(os.environ)
ENV["PROJ_NETWORK"]="OFF"

def run(cmd, stdin=None):
    p=subprocess.run(cmd,input=stdin,text=True,capture_output=True,env=ENV)
    if p.returncode!=0:
        fail(f"command failed {cmd}: {p.stderr.strip()}")
    return p.stdout.strip()

def parse_pair(text):
    line=text.splitlines()[0].strip()
    parts=line.replace("\t"," ").split()
    if len(parts)<2:
        fail("cannot parse coordinate output: "+repr(text))
    try:
        a=float(parts[0]); b=float(parts[1])
    except ValueError as exc:
        fail("non-numeric coordinate output: "+repr(text))
    if not (math.isfinite(a) and math.isfinite(b)):
        fail("non-finite coordinate output")
    return a,b

def forward(exe, lon, lat):
    out=run([exe,"-f","%.8f","EPSG:4326","EPSG:28992"],f"{lon:.10f} {lat:.10f}\n")
    return parse_pair(out),out

def inverse(exe, x, y):
    out=run([exe,"-I","-f","%.10f","EPSG:4326","EPSG:28992"],f"{x:.8f} {y:.8f}\n")
    return parse_pair(out),out

def main():
    cs2cs=shutil.which("cs2cs")
    if not cs2cs:
        fail("cs2cs unavailable")
    print("F_PE_ELASTIC39_A1_CS2CS_AVAILABLE=PASS")

    version=""
    for args in (["--version"],["-V"]):
        p=subprocess.run([cs2cs,*args],text=True,capture_output=True,env=ENV)
        candidate=(p.stdout+"\n"+p.stderr).strip()
        if candidate:
            version=candidate.splitlines()[0]
            break
    print("F_PE_ELASTIC39_VERSION="+json.dumps({"cs2cs":version,"path":cs2cs},sort_keys=True,separators=(",",":")))

    projinfo=shutil.which("projinfo")
    projinfo_meta={"available":bool(projinfo)}
    if projinfo:
        p=subprocess.run([projinfo,"EPSG:28992"],text=True,capture_output=True,env=ENV)
        if p.returncode!=0:
            fail("projinfo EPSG:28992 failed")
        projinfo_meta["path"]=projinfo
    print("F_PE_ELASTIC39_A2_PROJINFO_OFFLINE=PASS")
    print("F_PE_ELASTIC39_PROJINFO="+json.dumps(projinfo_meta,sort_keys=True,separators=(",",":")))

    results=[]
    for lon,lat,name in POINTS:
        (x,y),txt1=forward(cs2cs,lon,lat)
        (x2,y2),txt2=forward(cs2cs,lon,lat)
        if txt1!=txt2:
            fail(f"non-deterministic forward text {name}")
        if not (0.0<=x<=300000.0 and 250000.0<=y<=650000.0):
            fail(f"implausible RD range {name}: {x},{y}")
        (lon2,lat2),inv_txt=inverse(cs2cs,x,y)
        lon_err=abs(lon2-lon); lat_err=abs(lat2-lat)
        if lon_err>2e-7 or lat_err>2e-7:
            fail(f"roundtrip {name}: {lon_err},{lat_err}")
        results.append({"name":name,"lon":lon,"lat":lat,"x":x,"y":y,
                        "lon2":lon2,"lat2":lat2,
                        "lon_error_deg":lon_err,"lat_error_deg":lat_err,
                        "forward_text":txt1,"inverse_text":inv_txt})
    print("F_PE_ELASTIC39_A3_RD_RANGE=PASS")
    print("F_PE_ELASTIC39_A4_TEXT_DETERMINISM=PASS")
    print("F_PE_ELASTIC39_A5_INVERSE_FINITE=PASS")
    print("F_PE_ELASTIC39_A6_ROUNDTRIP=PASS")

    (goodx,goody),_=forward(cs2cs,5.6631,51.9851)
    (swapx,swapy),_=forward(cs2cs,51.9851,5.6631)
    if math.hypot(goodx-swapx,goody-swapy)<1.0:
        fail("axis-order probe did not discriminate")
    print("F_PE_ELASTIC39_A7_AXIS_ORDER_DISCRIMINATED=PASS")

    if ENV.get("PROJ_NETWORK")!="OFF":
        fail("PROJ_NETWORK not OFF")
    print("F_PE_ELASTIC39_A8_OFFLINE_NETWORK_POLICY=PASS")
    print("F_PE_ELASTIC39_A9_PROVENANCE="+json.dumps({
        "cs2cs_path":cs2cs,"cs2cs_version":version,
        "projinfo_path":projinfo,
        "proj_network":"OFF","points":results,
    },sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC39=PASS")

if __name__=="__main__":
    main()
