#!/usr/bin/env python3
"""F-PE-ELASTIC10E deterministic BHR-GT mechanical target extractor."""
from __future__ import annotations
import argparse, csv, hashlib, json, math, re
import xml.etree.ElementTree as ET
from pathlib import Path

GAMMA_W = 9806.65
HEIGHT_SHA = "eaf6fa175a8530d4b3fa7d26960c2796a892c080ab73d5cf6bf72a7befbbc0ec"
STRESS_SHA = "7d2d9a3cef1e91513621cc7d3f3064f461100dadbd0f21bbe3559d98e4b5d895"
HEIGHT_FIELDS = [("elapsedTime","s"),("verticalStrain","%")]
STRESS_FIELDS = [
    ("elapsedTime","s"),("verticalStrain","%"),
    ("excessPoreWaterPressure","kPa"),
    ("verticalEffectiveStress","kPa"),
    ("horizontalEffectiveStress","kPa"),
]

def local(tag: str) -> str:
    return tag.rsplit("}",1)[-1]

def text(e) -> str:
    return (e.text or "").strip()

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def finite_float(value):
    try:
        x=float(value)
    except (TypeError,ValueError):
        return None
    return x if math.isfinite(x) else None

def descendants(e,name):
    return [x for x in e.iter() if local(x.tag)==name]

def bind_schema(schema_dir: Path):
    specs=[]
    for name,expected,expected_sha in (
        ("HeightAtSpecificState.xml",HEIGHT_FIELDS,HEIGHT_SHA),
        ("StressAtSpecificSettlement.xml",STRESS_FIELDS,STRESS_SHA),
    ):
        p=schema_dir/name
        if not p.exists():
            raise RuntimeError(f"missing schema {name}")
        got=sha256(p)
        if got != expected_sha:
            raise RuntimeError(f"schema SHA mismatch {name}: {got}")
        root=ET.fromstring(p.read_bytes())
        fields=[]
        for field in descendants(root,"field"):
            q=next((x for x in field if local(x.tag) in ("Quantity","Time")),None)
            u=next((x for x in q.iter() if local(x.tag)=="uom"),None) if q is not None else None
            fields.append((field.attrib.get("name",""),u.attrib.get("code","") if u is not None else ""))
        if fields != expected:
            raise RuntimeError(f"schema fields mismatch {name}: {fields!r}")
        specs.append({"name":name,"sha256":got,"fields":fields})
    return specs

def step_type_tokens(step):
    out=[]
    for e in descendants(step,"stepType"):
        if text(e):
            out.append(text(e))
        for k,v in e.attrib.items():
            if local(k).lower()=="href":
                out.append(v.rsplit("/",1)[-1])
    return out

def is_unload(step):
    return any("ontlast" in x.lower() or "unload" in x.lower() for x in step_type_tokens(step))

def scalar(step,name):
    vals=[]
    for e in descendants(step,name):
        x=finite_float(text(e))
        if x is not None:
            vals.append(x)
    return vals[0] if vals else None

def parse_series(step,element_name,record_name,ncol):
    blocks=[]
    for block in descendants(step,element_name):
        hrefs=[]
        for e in block.iter():
            for k,v in e.attrib.items():
                if local(k).lower()=="href":
                    hrefs.append(v)
        if not any(x.endswith(record_name) for x in hrefs):
            continue
        enc=next((e for e in block.iter() if local(e.tag)=="TextEncoding"),None)
        values=next((text(e) for e in block.iter() if local(e.tag)=="values" and text(e)),None)
        if enc is None or values is None:
            continue
        if (enc.attrib.get("decimalSeparator",".")!="." or
            enc.attrib.get("tokenSeparator",",")!="," or
            enc.attrib.get("blockSeparator"," ")!=" "):
            raise RuntimeError(f"unsupported SWE encoding {record_name}: {enc.attrib}")
        rows=[]
        for rec in values.split(" "):
            rec=rec.strip()
            if not rec:
                continue
            parts=rec.split(",")
            if len(parts)!=ncol:
                raise RuntimeError(f"{record_name}: expected {ncol} columns, got {len(parts)}")
            rows.append([finite_float(x) for x in parts])
        blocks.append({"rows":rows,"hrefs":hrefs})
    if len(blocks)>1:
        raise RuntimeError(f"multiple {element_name} blocks inside one determination step")
    return blocks[0] if blocks else None

def nearest_ancestor(parent,e,wanted):
    x=parent.get(e)
    while x is not None:
        if local(x.tag)==wanted:
            return x
        x=parent.get(x)
    return None

def values(scope,names):
    if scope is None:
        return []
    wanted=set(names)
    return [text(e) for e in scope.iter() if local(e.tag) in wanted and text(e)]

def target_base(bro_id,auth,det,det_index,parent,obj_sha,determination_readiness=None):
    interval=nearest_ancestor(parent,det,"investigatedInterval")
    gml_id=next((v for k,v in det.attrib.items() if local(k)=="id"),None)
    return {
        "bro_id":bro_id,
        "owning_cell":auth["owning_cell"],
        "object_readiness":auth["readiness"],
        "authority_readiness":determination_readiness if determination_readiness is not None else auth["readiness"],
        "object_sha256":obj_sha,
        "determination_index":det_index,
        "determination_gml_id":gml_id,
        "interval_begin_depth_values":values(interval,("beginDepth","startDepth")),
        "interval_end_depth_values":values(interval,("endDepth",)),
    }

def make_target(base,route,step_index,tokens,s0,s1,e0,e1,schema):
    ds=(s1-s0)*1000.0
    de=(e1-e0)/100.0
    if ds==0.0 or not math.isfinite(ds) or not math.isfinite(de):
        return None
    mv=abs(de/ds)
    ssk=GAMMA_W*mv
    if not (math.isfinite(mv) and mv>0.0 and math.isfinite(ssk) and ssk>0.0):
        return None
    return {
        **base,
        "route":route,
        "step_index":step_index,
        "step_type_tokens":tokens,
        "schema_record":schema,
        "stress_start_kpa":s0,
        "stress_end_kpa":s1,
        "strain_start_pct":e0,
        "strain_end_pct":e1,
        "delta_stress_pa_signed":ds,
        "delta_strain_signed":de,
        "mv_pa_inv":mv,
        "ssk_m_inv":ssk,
        "ssk_cm_inv":ssk/100.0,
    }

def process_object(object_dir: Path,auth,determination_authority=None):
    bro_id=auth["bro_id"]
    p=object_dir/f"object-{bro_id}.response"
    if not p.exists():
        raise RuntimeError(f"missing frozen object {bro_id}")
    got=sha256(p)
    if got!=auth["sha256"] or p.stat().st_size!=auth["size_bytes"]:
        raise RuntimeError(f"frozen object identity mismatch {bro_id}")
    root=ET.fromstring(p.read_bytes())
    parent={child:par for par in root.iter() for child in par}
    dets=[e for e in root.iter() if local(e.tag)=="SettlementCharacteristicsDetermination"]
    targets=[]; rejected=[]
    det_auth_by_index={}
    if determination_authority is not None:
        da=determination_authority.get(bro_id)
        if da is None:
            raise RuntimeError(f"missing determination authority {bro_id}")
        if int(da["physical_determination_count"]) != len(dets):
            raise RuntimeError(f"physical determination count mismatch {bro_id}: {len(dets)}")
        det_auth_by_index={int(x["physical_index"]):x["readiness"] for x in da["determinations"]}
        if sorted(det_auth_by_index) != list(range(1,len(dets)+1)):
            raise RuntimeError(f"non-contiguous determination authority {bro_id}")

    for di,det in enumerate(dets,1):
        frozen_route=det_auth_by_index.get(di) if determination_authority is not None else None
        base=target_base(bro_id,auth,det,di,parent,got,frozen_route)
        steps=[e for e in det.iter() if local(e.tag)=="determinationStep"]
        stress_blocks=[
            parse_series(s,"stressChangeDuringSettlement","StressAtSpecificSettlement.xml",5)
            for s in steps
        ]
        observed_route="R3" if any(b is not None for b in stress_blocks) else "R2"
        if frozen_route is not None and observed_route != frozen_route:
            raise RuntimeError(f"determination route mismatch {bro_id} physical_index={di}: observed={observed_route} frozen={frozen_route}")
        route=frozen_route if frozen_route is not None else observed_route

        if route=="R3":
            for si,(step,block) in enumerate(zip(steps,stress_blocks),1):
                if not is_unload(step):
                    continue
                if block is None:
                    rejected.append({**base,"route":"R3","step_index":si,"reason":"UNLOAD_WITHOUT_STRESS_SERIES"})
                    continue
                valid=[r for r in block["rows"] if r[1] is not None and r[3] is not None]
                if len(valid)<3 or len({r[3] for r in valid})<2:
                    rejected.append({**base,"route":"R3","step_index":si,
                                     "reason":"INSUFFICIENT_VALID_DISTINCT_ROWS","valid_rows":len(valid)})
                    continue
                target=make_target(base,"R3",si,step_type_tokens(step),
                                   valid[0][3],valid[-1][3],valid[0][1],valid[-1][1],
                                   "StressAtSpecificSettlement.xml")
                if target is None:
                    rejected.append({**base,"route":"R3","step_index":si,"reason":"NONPOSITIVE_OR_ZERO_SECANT"})
                else:
                    target["valid_row_count"]=len(valid)
                    target["series_row_count"]=len(block["rows"])
                    targets.append(target)
            continue

        endpoints=[]
        for si,step in enumerate(steps,1):
            stress=scalar(step,"verticalStress")
            block=parse_series(step,"heightChangeDuringSettlement","HeightAtSpecificState.xml",2)
            valid=[] if block is None else [r for r in block["rows"] if r[1] is not None]
            endpoints.append({
                "step":step,"step_index":si,"stress":stress,
                "strain":valid[-1][1] if valid else None,
                "series_rows":len(block["rows"]) if block else 0,
            })
        for i,ep in enumerate(endpoints):
            if not is_unload(ep["step"]):
                continue
            if i==0:
                rejected.append({**base,"route":"R2","step_index":ep["step_index"],
                                 "reason":"UNLOAD_WITHOUT_PREVIOUS_STEP"})
                continue
            prev=endpoints[i-1]
            if None in (prev["stress"],prev["strain"],ep["stress"],ep["strain"]):
                rejected.append({**base,"route":"R2","step_index":ep["step_index"],
                                 "reason":"MISSING_PREVIOUS_OR_UNLOAD_ENDPOINT"})
                continue
            target=make_target(base,"R2",ep["step_index"],step_type_tokens(ep["step"]),
                               prev["stress"],ep["stress"],prev["strain"],ep["strain"],
                               "HeightAtSpecificState.xml")
            if target is None:
                rejected.append({**base,"route":"R2","step_index":ep["step_index"],
                                 "reason":"NONPOSITIVE_OR_ZERO_SECANT"})
            else:
                target["previous_step_index"]=prev["step_index"]
                target["previous_series_row_count"]=prev["series_rows"]
                target["unload_series_row_count"]=ep["series_rows"]
                targets.append(target)
    return targets,rejected,{
        "bro_id":bro_id,
        "determination_count":len(dets),
        "target_count":len(targets),
        "reject_count":len(rejected),
    }

def write_csv(path,rows):
    keys=sorted({k for r in rows for k in r}) if rows else ["bro_id","route","reason"]
    with path.open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=keys)
        w.writeheader()
        for row in rows:
            cooked={k:(json.dumps(v,separators=(",",":"),sort_keys=True)
                       if isinstance(v,(list,dict)) else v) for k,v in row.items()}
            w.writerow(cooked)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--objects",required=True)
    ap.add_argument("--schemas",required=True)
    ap.add_argument("--authority",required=True)
    ap.add_argument("--determination-authority")
    ap.add_argument("--out",required=True)
    a=ap.parse_args()
    out=Path(a.out); out.mkdir(parents=True,exist_ok=True)
    schemas=bind_schema(Path(a.schemas))
    authority=json.loads(Path(a.authority).read_text())
    determination_authority=None
    if a.determination_authority:
        raw=json.loads(Path(a.determination_authority).read_text())
        if raw.get("historical_classifier_records") != 100 or raw.get("physical_determinations") != 50:
            raise RuntimeError("determination authority count mismatch")
        if raw.get("route_counts") != {"R2":29,"R3":21}:
            raise RuntimeError("determination authority route-count mismatch")
        determination_authority={x["bro_id"]:x for x in raw["objects"]}
    targets=[]; rejected=[]; object_stats=[]
    for auth in authority["objects"]:
        t,r,s=process_object(Path(a.objects),auth,determination_authority)
        targets.extend(t); rejected.extend(r); object_stats.append(s)
    targets.sort(key=lambda r:(r["bro_id"],r["determination_index"],r["step_index"],r["route"]))
    rejected.sort(key=lambda r:(r["bro_id"],r["determination_index"],r.get("step_index",0),r["route"],r["reason"]))
    vals=sorted(x["ssk_m_inv"] for x in targets)
    median=None
    if vals:
        n=len(vals)
        median=vals[n//2] if n%2 else 0.5*(vals[n//2-1]+vals[n//2])
    summary={
        "schema_binding":schemas,
        "object_count":len(authority["objects"]),
        "targets":len(targets),
        "rejects":len(rejected),
        "route_counts":{"R2":sum(x["route"]=="R2" for x in targets),
                        "R3":sum(x["route"]=="R3" for x in targets)},
        "objects":object_stats,
        "ssk_m_inv_min":min(vals) if vals else None,
        "ssk_m_inv_median":median,
        "ssk_m_inv_max":max(vals) if vals else None,
    }
    (out/"targets.json").write_text(json.dumps(targets,indent=2,sort_keys=True)+"\n")
    (out/"rejections.json").write_text(json.dumps(rejected,indent=2,sort_keys=True)+"\n")
    (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
    write_csv(out/"targets.csv",targets)
    write_csv(out/"rejections.csv",rejected)
    print(f"F_PE_ELASTIC10E_OBJECTS={len(authority['objects'])}")
    print(f"F_PE_ELASTIC10E_TARGETS={len(targets)}|R2={summary['route_counts']['R2']}|R3={summary['route_counts']['R3']}")
    print(f"F_PE_ELASTIC10E_REJECTIONS={len(rejected)}")
    print("F_PE_ELASTIC10E_SSK_RANGE="+json.dumps({
        "min":summary["ssk_m_inv_min"],"median":summary["ssk_m_inv_median"],"max":summary["ssk_m_inv_max"]
    },separators=(",",":")))
    if not targets:
        raise SystemExit("F_PE_ELASTIC10E_FAIL zero valid targets")
    print("F_PE_ELASTIC10E_TARGET_EXTRACTION=PASS")

if __name__=="__main__":
    main()
