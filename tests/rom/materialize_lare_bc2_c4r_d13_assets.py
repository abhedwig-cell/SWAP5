#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re, hashlib, json

VALIDATION = {
    1: ("V01 ", "0.375_real64"),
    2: ("V02 ", "0.625_real64"),
    3: ("V03 ", "0.875_real64"),
    4: ("V04 ", "1.125_real64"),
}

def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def materialize_fortran(src: pathlib.Path, dst: pathlib.Path):
    text=src.read_text(encoding="utf-8")
    label_pat=re.compile(
        r"(?ms)  function history_label\(ih\) result\(label\).*?  end function history_label\n"
    )
    lambda_pat=re.compile(
        r"(?ms)  pure real\(real64\) function history_lambda\(ih\) result\(lambda\).*?  end function history_lambda\n"
    )
    split_pat=re.compile(
        r"(?ms)  pure function split_label\(ih\) result\(label\).*?  end function split_label\n"
    )
    if len(label_pat.findall(text))!=1 or len(lambda_pat.findall(text))!=1 or len(split_pat.findall(text))!=1:
        raise SystemExit("unexpected D13 Fortran history function structure")
    label_block="""  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=4) :: label
    select case(ih)
    case(1);label='V01 '
    case(2);label='V02 '
    case(3);label='V03 '
    case(4);label='V04 '
    case default;label='BAD '
    end select
  end function history_label
"""
    lambda_block="""  pure real(real64) function history_lambda(ih) result(lambda)
    integer,intent(in) :: ih
    select case(ih)
    case(1);lambda=0.375_real64
    case(2);lambda=0.625_real64
    case(3);lambda=0.875_real64
    case(4);lambda=1.125_real64
    case default;lambda=-1.0_real64
    end select
  end function history_lambda
"""
    split_block="""  pure function split_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=10) :: label
    label='BLIND     '
  end function split_label
"""
    out=label_pat.sub(label_block,text,count=1)
    out=lambda_pat.sub(lambda_block,out,count=1)
    out=split_pat.sub(split_block,out,count=1)
    dst.write_text(out,encoding="utf-8")

def materialize_analyzer(src: pathlib.Path, dst: pathlib.Path):
    text=src.read_text(encoding="utf-8")
    old='HISTS={"G25":0.25,"G50":0.50,"G75":0.75,"G125":1.25}'
    new='HISTS={"V01":0.375,"V02":0.625,"V03":0.875,"V04":1.125}'
    if text.count(old)!=1:
        raise SystemExit("unexpected D13 analyzer HISTS structure")
    out=text.replace(old,new,1)
    dst.write_text(out,encoding="utf-8")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fortran-source",required=True,type=pathlib.Path)
    ap.add_argument("--fortran-output",required=True,type=pathlib.Path)
    ap.add_argument("--analyzer-source",required=True,type=pathlib.Path)
    ap.add_argument("--analyzer-output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    materialize_fortran(a.fortran_source,a.fortran_output)
    materialize_analyzer(a.analyzer_source,a.analyzer_output)
    manifest={
      "schema":"swap5.lare.bc2.c4r.materialization.v1",
      "fortran_source_sha256":sha(a.fortran_source),
      "fortran_output_sha256":sha(a.fortran_output),
      "analyzer_source_sha256":sha(a.analyzer_source),
      "analyzer_output_sha256":sha(a.analyzer_output),
      "allowed_changes":{
        "fortran":["history labels G* -> V01..V04","lambda values -> 0.375,0.625,0.875,1.125","split label -> BLIND"],
        "analyzer":["HISTS mapping only"]
      }
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
if __name__=="__main__":
    main()
