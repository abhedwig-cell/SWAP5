#!/usr/bin/env python3
"""Bounded official-BRO BHR-P service probe and raw-object retriever."""
from __future__ import annotations
import argparse, hashlib, json, sys, time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

USER_AGENT="SWAP5-F-HYDROFIT02/0.1 research reproducibility"
DEFAULT_BASE="https://publiek.broservices.nl/sr/bhrp/v2"

def fetch(url: str, timeout: float=20.0, attempts: int=3) -> tuple[int,str,bytes]:
    last=None
    for i in range(attempts):
        req=Request(url,headers={"User-Agent":USER_AGENT,"Accept":"application/xml, application/json;q=0.9, */*;q=0.1"})
        try:
            with urlopen(req,timeout=timeout) as r:
                return int(r.status), r.headers.get("Content-Type",""), r.read()
        except HTTPError as e:
            body=e.read()
            return int(e.code), e.headers.get("Content-Type",""), body
        except URLError as e:
            last=e
            if i+1<attempts: time.sleep(0.5*(i+1))
    raise RuntimeError(f"network failure for {url}: {last}")

def manifest(url,status,ctype,data):
    return {
      "retrieved_utc":datetime.now(timezone.utc).isoformat(),
      "url":url,"http_status":status,"content_type":ctype,
      "size_bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--base",default=DEFAULT_BASE)
    ap.add_argument("--path",default="")
    ap.add_argument("--output")
    ap.add_argument("--manifest")
    ap.add_argument("--require-success",action="store_true")
    a=ap.parse_args()
    url=a.base.rstrip("/") + (("/"+a.path.lstrip("/")) if a.path else "")
    status,ctype,data=fetch(url)
    m=manifest(url,status,ctype,data)
    print("BRO_PROBE|"+ "|".join(f"{k}={v}" for k,v in m.items()))
    if a.output: Path(a.output).write_bytes(data)
    if a.manifest: Path(a.manifest).write_text(json.dumps(m,indent=2)+"\n")
    if a.require_success and not (200<=status<300): return 2
    return 0
if __name__=="__main__": raise SystemExit(main())
