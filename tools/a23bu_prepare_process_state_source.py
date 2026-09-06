#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import a23bt_prepare_reporting_source as bt

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def rename_context_refs(root: Path) -> None:
    for path in root.glob('*.f90'):
        s=path.read_text(encoding='latin1')
        s=s.replace('mod_a23bt_worker_execution_context','mod_a23bu_worker_execution_context')
        s=s.replace('a23bt_','a23bu_')
        path.write_text(s,encoding='latin1',newline='')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--ttutil-prefs',type=Path,required=True)
    ns=ap.parse_args()
    bt.build_a23bs(ns.source,ns.output,ns.ttutil_prefs)
    bt.rename_context_refs(ns.output)
    bt.transform_timecontrol(ns.output/'timecontrol.f90')
    bt.transform_swap_output(ns.output/'swap.f90')
    bt.transform_integral(ns.output/'integral.f90')
    bt.transform_solute(ns.output/'solute.f90')
    bt.transform_swap_reset_and_calls(ns.output/'swap.f90')
    bt.transform_initialize_integral(ns.output/'initialize.f90')
    rename_context_refs(ns.output)
    info=bt.audit(ns.output)
    info['a23bu_scope']='adapter process continuation minimization; no physics formula change'
    info['legacy_irrigation_event_workspace']='serial backend projection remains'
    info['postimage_sha256']={p.name:sha256_bytes(p.read_bytes()) for p in ns.output.glob('*.f90')}
    print(json.dumps(info,indent=2,sort_keys=True))
if __name__=='__main__': main()
