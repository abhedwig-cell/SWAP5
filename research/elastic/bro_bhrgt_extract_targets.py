#!/usr/bin/env python3
"""F-PE-ELASTIC10C: source-bound mechanical target extraction from frozen BHR-GT pilot."""
from __future__ import annotations
import argparse, hashlib, json, math, statistics
from pathlib import Path
import xml.etree.ElementTree as ET
from bro_bhrgt_fetch import fetch, manifest

FROZEN_IDS=("BHR000000339285","BHR000000339288","BHR000000351603")
RHO_W=1000.0
G=9.80665
GAMMA_W=RHO_W*G

def local(tag:str)->str:
    return tag.rsplit("}",1)[-1]

def direct_text(e,name):
    for ch in list(e):
        if local(ch.tag)==name:
            t=(ch.text or "").strip()
            return t or None
    return None

def descendant_text(e,name):
    for ch in e.iter():
        if local(ch.tag)==name:
            t=(ch.text or "").strip()
            if t: return t
    return None

def href_of(e):
    for k,v in e.attrib.items():
        if k.endswith("}href") or k=="href":
            return v
    return None

def schema_definition(url:str, cache:dict, outdir:Path):
    if url in cache: return cache[url]
    fetch_url="https://"+url.split("://",1)[1] if url.startswith("http://") else url
    status,ctype,data=fetch(fetch_url)
    if not (200<=status<300):
        raise RuntimeError(f"schema fetch failed {status} {fetch_url}")
    sha=hashlib.sha256(data).hexdigest()
    name=fetch_url.rsplit("/",1)[-1]
    sdir=outdir/"schemas"; sdir.mkdir(exist_ok=True)
    (sdir/name).write_bytes(data)
    (sdir/(name+".manifest.json")).write_text(json.dumps(manifest(fetch_url,status,ctype,data),indent=2)+"\n")
    root=ET.fromstring(data)
    fields=[]
    for field in (x for x in root.iter() if local(x.tag)=="field"):
        fname=field.attrib.get("name")
        if not fname: continue
        unit=None
        for q in field.iter():
            if local(q.tag)=="uom":
                unit=q.attrib.get("code") or q.attrib.get("href")
                if unit: break
        fields.append({"name":fname,"unit":unit})
    if not fields:
        raise RuntimeError(f"no fields in DataRecord {fetch_url}")
    info={"original_url":url,"fetch_url":fetch_url,"sha256":sha,"fields":fields}
    cache[url]=info
    print("F_PE_ELASTIC10C_SCHEMA="+json.dumps(info,separators=(",",":"),sort_keys=True))
    return info

def parse_num(s):
    if s is None: return None
    s=s.strip()
    if not s or s.lower() in {"nan","nil","null"}: return None
    try: return float(s)
    except ValueError: return None

def parse_series(container, cache, outdir):
    count=None; href=None; values=None
    decimal="."; token=","; block=" "
    for e in container.iter():
        k=local(e.tag)
        if k=="elementCount":
            for q in e.iter():
                if local(q.tag)=="value" and (q.text or "").strip():
                    count=int(float((q.text or "").strip())); break
        elif k=="elementType":
            href=href_of(e)
        elif k=="TextEncoding":
            decimal=e.attrib.get("decimalSeparator",decimal)
            token=e.attrib.get("tokenSeparator",token)
            block=e.attrib.get("blockSeparator",block)
        elif k=="values" and (e.text or "").strip():
            values=(e.text or "").strip()
    if not href or values is None:
        raise RuntimeError("series missing elementType/values")
    schema=schema_definition(href,cache,outdir)
    names=[x["name"] for x in schema["fields"]]
    chunks=values.split() if block.isspace() else [x for x in values.split(block) if x]
    rows=[]
    for raw in chunks:
        parts=raw.split(token)
        if len(parts)!=len(names):
            raise RuntimeError(f"tuple width {len(parts)} != schema fields {len(names)} for {href}")
        vals=[]
        for p in parts:
            if decimal!=".": p=p.replace(decimal,".")
            vals.append(parse_num(p))
        rows.append(dict(zip(names,vals)))
    if count is not None and len(rows)!=count:
        raise RuntimeError(f"series count {len(rows)} != declared {count}")
    return {"schema":schema,"rows":rows,"count":len(rows)}

def finite_endpoints(rows,stress_name,strain_name):
    pairs=[]
    for r in rows:
        s=r.get(stress_name); e=r.get(strain_name)
        if s is not None and e is not None and math.isfinite(s) and math.isfinite(e):
            pairs.append((s,e))
    if len(pairs)<2: return None
    return pairs[0],pairs[-1]

def strain_endpoints(rows,strain_name="verticalStrain"):
    vals=[r.get(strain_name) for r in rows]
    vals=[v for v in vals if v is not None and math.isfinite(v)]
    if len(vals)<2: return None
    return vals[0],vals[-1]

def make_target(meta,delta_sigma_pa,delta_eps):
    out=dict(meta)
    out["delta_sigma_pa"]=delta_sigma_pa
    out["delta_epsilon_fraction"]=delta_eps
    if delta_sigma_pa==0:
        out["classification"]="ZERO_STRESS_CHANGE"; return out
    if delta_sigma_pa*delta_eps<=0:
        out["classification"]="SIGN_INCONSISTENT"; return out
    mv=delta_eps/delta_sigma_pa
    if not math.isfinite(mv) or mv<=0:
        out["classification"]="INVALID_MV"; return out
    ss_m=GAMMA_W*mv
    out.update({
      "mv_pa_inv":mv,
      "ss_skeleton_m_inv":ss_m,
      "ss_skeleton_cm_inv":ss_m/100.0,
      "classification":"VALID"
    })
    return out

def manifest_sha(root:Path,broid:str):
    d=json.loads((root/(broid+".xml.manifest.json")).read_text())
    return d["sha256"]

def extract_object(path:Path, outdir:Path, cache:dict):
    broid=path.stem
    root=ET.fromstring(path.read_bytes())
    targets=[]; determinations=[]
    for iv in (e for e in root.iter() if local(e.tag)=="investigatedInterval"):
        analysis=direct_text(iv,"analysisType")
        if analysis not in {"zetting","zettingWaterdoorlatendheid"}: continue
        depth={"begin_m":parse_num(direct_text(iv,"beginDepth")),"end_m":parse_num(direct_text(iv,"endDepth"))}
        quality=direct_text(iv,"sampleQuality")
        for wrap in list(iv):
            if local(wrap.tag)!="settlementCharacteristicsDetermination": continue
            det=next((x for x in list(wrap) if local(x.tag)=="SettlementCharacteristicsDetermination"),None)
            if det is None: continue
            method=direct_text(det,"determinationMethod")
            procedure=direct_text(det,"determinationProcedure")
            detid=next((v for k,v in det.attrib.items() if k.endswith("}id") or k=="id"),None)
            steps=[x for x in list(det) if local(x.tag)=="determinationStep"]
            step_records=[]
            for s in steps:
                rec={
                  "step_number":int(float(direct_text(s,"stepNumber"))) if direct_text(s,"stepNumber") else None,
                  "step_type":direct_text(s,"stepType"),
                  "vertical_stress_kpa":parse_num(direct_text(s,"verticalStress")),
                  "strain_24h_pct":parse_num(direct_text(s,"strainPoint24hours")),
                  "wet_performed":direct_text(s,"wetPerformed"),
                  "swell_observed":direct_text(s,"swellObserved"),
                  "deformation_rate_mm_h":parse_num(direct_text(s,"deformationRate")),
                }
                h=next((x for x in list(s) if local(x.tag)=="heightChangeDuringSettlement"),None)
                sc=next((x for x in list(s) if local(x.tag)=="stressChangeDuringSettlement"),None)
                if h is not None: rec["height_series"]=parse_series(h,cache,outdir)
                if sc is not None: rec["stress_series"]=parse_series(sc,cache,outdir)
                step_records.append(rec)

            base={
              "bro_id":broid,"raw_sha256":manifest_sha(outdir,broid),
              "begin_depth_m":depth["begin_m"],"end_depth_m":depth["end_m"],
              "sample_quality":quality,"determination_id":detid,
              "method":method,"procedure":procedure
            }
            determinations.append({**base,"steps":step_records})

            for idx,s in enumerate(step_records):
                if idx==0: continue
                prev=step_records[idx-1]
                kind=None
                if s["step_type"]=="ontlastingstap":
                    kind="unload"
                elif prev["step_type"]=="ontlastingstap" and s["step_type"]=="belastingstap":
                    kind="reload"
                if not kind: continue

                meta={**base,"kind":kind,"from_step":prev["step_number"],"to_step":s["step_number"],
                      "from_step_type":prev["step_type"],"to_step_type":s["step_type"]}

                if method=="samendrukkenBelastinggestuurd":
                    if prev["vertical_stress_kpa"] is None or s["vertical_stress_kpa"] is None or "height_series" not in s:
                        t={**meta,"classification":"MISSING_LOAD_CONTROLLED_INPUT"}; targets.append(t); continue
                    ep=strain_endpoints(s["height_series"]["rows"])
                    if ep is None:
                        t={**meta,"classification":"MISSING_STRAIN_ENDPOINTS"}; targets.append(t); continue
                    e0,e1=ep
                    ds=(s["vertical_stress_kpa"]-prev["vertical_stress_kpa"])*1000.0
                    de=(e1-e0)/100.0
                    meta.update({
                      "stress_start_kpa":prev["vertical_stress_kpa"],
                      "stress_end_kpa":s["vertical_stress_kpa"],
                      "strain_start_pct":e0,"strain_end_pct":e1,
                      "datarecord_sha256":s["height_series"]["schema"]["sha256"]
                    })
                    targets.append(make_target(meta,ds,de))

                elif method=="samendrukkenSnelheidgestuurd":
                    if "stress_series" not in s:
                        t={**meta,"classification":"MISSING_RATE_SERIES"}; targets.append(t); continue
                    rows=s["stress_series"]["rows"]
                    names=set(rows[0]) if rows else set()
                    stress_name="verticalEffectiveStress"
                    strain_name="verticalStrain"
                    if stress_name not in names or strain_name not in names:
                        t={**meta,"classification":"SCHEMA_MISSING_EFFECTIVE_STRESS_OR_STRAIN",
                           "fields":sorted(names)}; targets.append(t); continue
                    ep=finite_endpoints(rows,stress_name,strain_name)
                    if ep is None:
                        t={**meta,"classification":"MISSING_EFFECTIVE_ENDPOINTS"}; targets.append(t); continue
                    (s0,e0),(s1,e1)=ep
                    ds=(s1-s0)*1000.0
                    de=(e1-e0)/100.0
                    meta.update({
                      "stress_start_kpa":s0,"stress_end_kpa":s1,
                      "strain_start_pct":e0,"strain_end_pct":e1,
                      "datarecord_sha256":s["stress_series"]["schema"]["sha256"]
                    })
                    targets.append(make_target(meta,ds,de))
    return determinations,targets

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--pilot-dir",required=True)
    a=ap.parse_args()
    root=Path(a.pilot_dir)
    for broid in FROZEN_IDS:
        if not (root/(broid+".xml")).exists():
            raise SystemExit(f"F_PE_ELASTIC10C_FAIL missing frozen object {broid}")
    cache={}; all_det=[]; targets=[]
    for broid in FROZEN_IDS:
        d,t=extract_object(root/(broid+".xml"),root,cache)
        all_det.extend(d); targets.extend(t)
    valid=[x for x in targets if x.get("classification")=="VALID"]
    unload=[x for x in valid if x["kind"]=="unload"]
    reload=[x for x in valid if x["kind"]=="reload"]
    result={"objects":list(FROZEN_IDS),"schemas":list(cache.values()),"targets":targets}
    (root/"mechanical-targets.json").write_text(json.dumps(result,indent=2)+"\n")
    for x in targets:
        print("F_PE_ELASTIC10C_TARGET="+json.dumps(x,separators=(",",":"),sort_keys=True))
    print(f"F_PE_ELASTIC10C_VALID_UNLOAD={len(unload)}")
    print(f"F_PE_ELASTIC10C_VALID_RELOAD={len(reload)}")
    if len(valid)>=3:
        vals=[x["ss_skeleton_cm_inv"] for x in valid]
        print("F_PE_ELASTIC10C_SS_CM_INV="+json.dumps({
          "min":min(vals),"median":statistics.median(vals),"max":max(vals),"n":len(vals)
        },separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC10C=PASS")

if __name__=="__main__":
    raise SystemExit(main())
