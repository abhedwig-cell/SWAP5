#!/usr/bin/env python3
"""F-MACRO-ALT42 selector contract smoke test."""
import json, subprocess, sys, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parent
SEL=ROOT/'macropore_alt42_paired_event_selector.py'
FIX=ROOT/'fixtures'/'macropore_alt42_synthetic_events.json'

def main():
    out=subprocess.check_output([sys.executable,str(SEL),str(FIX),'--top-k','20'],text=True)
    data=json.loads(out)
    sl=data['pairs']['short_long']
    cf=data['pairs']['continuous_fragmented']
    wi=data['pairs']['weak_intermediate']
    assert any({p['event_a'],p['event_b']}=={'w_short','w_long'} for p in sl)
    assert any({p['event_a'],p['event_b']}=={'i_short','i_long'} for p in sl)
    assert any({p['event_a'],p['event_b']}=={'cont','frag'} for p in cf)
    assert any(set((p['event_a'],p['event_b'])) & {'w_short','w_long'} and set((p['event_a'],p['event_b'])) & {'i_short','i_long','cont','frag'} for p in wi)
    assert not any(p['event_a']=='other' or p['event_b']=='other' for kind in data['pairs'].values() for p in kind)
    print('PASS F-MACRO-ALT42 paired-event selector contract')

if __name__=='__main__': main()
