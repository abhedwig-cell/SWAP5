#!/usr/bin/env python3
"""Compare identity-corrected live corpus to frozen pre-identity corpus."""
from __future__ import annotations
import argparse,json,collections
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--old",required=True);ap.add_argument("--new",required=True);a=ap.parse_args()
 old=json.load(open(a.old))["intervals"];new=json.load(open(a.new))["intervals"]
 print(f"BRO_IDENTITY_COMPARE|OLD={len(old)}|NEW={len(new)}")
 oc=collections.Counter((r["bro_id"],str(r["begin_depth"]),str(r["end_depth"])) for r in old)
 nc=collections.Counter((r["bro_id"],str(r["begin_depth"]),str(r["end_depth"])) for r in new)
 for k in sorted(set(oc)|set(nc)):
  if oc[k]!=nc[k] or oc[k]>1:
   print(f"BRO_IDENTITY_KEY|BRO={k[0]}|DEPTH={k[1]}:{k[2]}|OLD={oc[k]}|NEW={nc[k]}")
 hashes=[r.get("hyd_sha256") for r in new]; print(f"BRO_IDENTITY_HASH|PRESENT={sum(bool(x) for x in hashes)}|UNIQUE={len(set(x for x in hashes if x))}")
 dup=[(k,n) for k,n in collections.Counter(hashes).items() if k and n>1]
 print(f"BRO_IDENTITY_DUP_HASHES|N={len(dup)}")
if __name__=="__main__":main()
