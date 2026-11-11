"""Bounded physical proposal plus nonphysical corruption/publication guards."""
import argparse
import json
import os
from pathlib import Path
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--platform',choices=['windows','linux'],required=True)
p.add_argument('--workspace',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output.mkdir();begin=time.monotonic()
if a.platform=='linux':
    bundle=a.workspace/'generic-hupsel-O2';reference=a.workspace/'generic-reference'
    full=a.workspace/'generic-hupsel-full/full/accepted-column-1-day-1096.zip'
else:
    bundle=a.workspace/'s5-hybrid-hupsel-O2-season-20261111'
    reference=a.workspace/'s5-water-integrated-reference'
    full=a.workspace/'s5-hybrid-hupsel-full-season-20261111/full/accepted-column-1-day-1096.zip'
origin=bundle/'continuous/accepted-column-1-day-2.zip'
def refuses(fn,exceptions=(ValueError,)):
    try:fn()
    except exceptions:return
    raise AssertionError('Guard accepted invalid state')

model=CoupledDailyColumn(bundle,reference,a.output/'owner',h.HUPSEL,'guard-owner',
                         origin=origin,day=2,adopt_native=True)
proposal=model.prepare()
stage=model._candidate[0]/'macro.bin';saved=stage.read_bytes()
stage.write_bytes(saved[:-1]+bytes([saved[-1]^1]))
refuses(lambda:model.accept(proposal))
assert model.day==2 and model.revision==0 and not list(model.output.glob('accepted-*.zip'))
stage.write_bytes(saved)
accepted=model.accept(proposal)
assert model.day==3 and model.revision==1
raw=accepted.read_bytes();accepted.write_bytes(raw[:-1]+bytes([raw[-1]^1]))
refuses(model.prepare)
assert model.day==3 and model.revision==1 and not (model.output/'trial-2').exists()
accepted.write_bytes(raw)
refuses(lambda:CoupledDailyColumn(bundle,reference,model.output,h.HUPSEL,'guard-owner',
                                  origin=accepted,day=3),(FileExistsError,))
refuses(lambda:CoupledDailyColumn(bundle,reference,a.output/'unadmitted-native',h.HUPSEL,
                                  'guard-owner',origin=origin,day=2))
assert not (a.output/'unadmitted-native').exists()
terminal=CoupledDailyColumn(bundle,reference,a.output/'terminal',h.HUPSEL,'terminal',
                            origin=full,day=1096,adopt_native=True)
full_hash=h.sha(full);refuses(terminal.prepare)
assert terminal.day==1096 and h.sha(full)==full_hash and not list(terminal.output.glob('trial-*'))
report={'status':'MUTATED_NATIVE_ORIGIN_OWNER_NATIVE_ADOPTION_AND_TERMINAL_GUARDS_PASS',
        'platform':a.platform,'seconds':time.monotonic()-begin,
        'source_sha256':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py',
                          'research/hybrid-water01/qualify_daily_coupling_corruption.py']},
        'candidate_native_corruption_refused':True,'accepted_origin_corruption_refused_before_trial':True,
        'exclusive_owner':True,'native_adoption_explicit':True,'terminal_refused_before_trial':True,
        'retained_terminal_origin_sha256':full_hash,'accepted_guard_day3_sha256':h.sha(accepted)}
(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
