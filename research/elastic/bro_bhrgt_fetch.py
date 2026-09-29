#!/usr/bin/env python3
"""Bounded official-BRO BHR-GT service probe and raw retriever."""
from __future__ import annotations
import argparse, hashlib, json, time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

USER_AGENT="SWAP5-F-PE-ELASTIC10/0.1 research reproducibility"
DEFAULT_BASE="https://publiek.broservices.nl/sr/bhrgt/v2"

def fetch(url: str, timeout: float=20.0, attempts: int=3, method: str="GET",
          body: bytes|None=None) -> tuple[int,str,bytes]:
    last=None
    for i in range(attempts):
        headers={
            "User-Agent":USER_AGENT,
            "Accept":"application/xml, application/json;q=0.9, */*;q=0.1",
        }
        if body is not None:
            headers["Content-Type"]="application/json"
        req=Request(url,data=body,headers=headers,method=method)
        try:
            with urlopen(req,timeout=timeout) as r:
                return int(r.status),r.headers.get("Content-Type",""),r.read()
        except HTTPError as e:
            return int(e.code),e.headers.get("Content-Type",""),e.read()
        except URLError as e:
            last=e
            if i+1<attempts:
                time.sleep(0.5*(i+1))
    raise RuntimeError(f"network failure for {url}: {last}")

def manifest(url,status,ctype,data):
    return {
        "retrieved_utc":datetime.now(timezone.utc).isoformat(),
        "url":url,
        "http_status":status,
        "content_type":ctype,
        "size_bytes":len(data),
        "sha256":hashlib.sha256(data).hexdigest(),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--base",default=DEFAULT_BASE)
    ap.add_argument("--path",default="")
    ap.add_argument("--output")
    ap.add_argument("--manifest")
    ap.add_argument("--require-success",action="store_true")
    ap.add_argument("--method",default="GET",choices=["GET","POST"])
    ap.add_argument("--json-body")
    a=ap.parse_args()
    url=a.base.rstrip("/") + (("/"+a.path.lstrip("/")) if a.path else "")
    body=Path(a.json_body).read_bytes() if a.json_body else None
    status,ctype,data=fetch(url,method=a.method,body=body)
    m=manifest(url,status,ctype,data)
    print("BHRGT_PROBE|"+"|".join(f"{k}={v}" for k,v in m.items()))
    if a.output:
        Path(a.output).write_bytes(data)
    if a.manifest:
        Path(a.manifest).write_text(json.dumps(m,indent=2)+"\n")
    if a.require_success and not (200<=status<300):
        return 2
    return 0

if __name__=="__main__":
    raise SystemExit(main())
