"""Focused current publisher/bundle external transaction and isolation control."""
import argparse
import json
import sys
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--qualification',type=Path,required=True)
p.add_argument('--reference',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output.mkdir();reports=[]

def native(path):
    with zipfile.ZipFile(path) as z:
        return {n:z.read(n) for n in h.CHECKPOINT_FILES}

def physical(budget):
    return {k:v for k,v in budget.items() if k not in
            ('column','revision','committed','candidate_only')}

for name,project in [('grass',h.GRASSGROWTH),('hupsel',h.HUPSEL),('saltfarm',h.SALTFARM)]:
    for opt in ('O0','O2'):
        label=name+'-'+opt;bundle=a.qualification/(label+'-candidate-build')
        root=a.output/label;root.mkdir()
        x=CoupledDailyColumn(bundle,a.reference,root/'a',project,'a')
        y=CoupledDailyColumn(bundle,a.reference,root/'b',project,'b')
        discarded=x.prepare();first=physical(discarded.budget)
        assert not list((root/'a').glob('accepted-*.zip'))
        x.discard(discarded);assert x.day==x.revision==0
        other=y.prepare();ypath=y.accept(other)
        again=x.prepare();assert physical(again.budget)==first==physical(other.budget)
        xpath=x.accept(again);assert native(xpath)==native(ypath)
        try:x.accept(discarded)
        except ValueError:pass
        else:raise AssertionError('Discarded token accepted')
        origin_hash=h.sha(xpath)
        restored=CoupledDailyColumn(bundle,a.reference,root/'restore',project,'a',origin=xpath,day=1)
        proposed=restored.prepare();saved=restored.accept(proposed)
        assert h.sha(xpath)==origin_hash
        control=[json.loads(s) for s in (a.qualification/(label+'-candidate-full')/'daily.jsonl').read_text().splitlines()]
        assert physical(proposed.budget)==physical(control[1])
        reports.append(dict(project=name,opt=opt,discard_replay_exact=True,
            interleaved_instance_native_exact=True,external_day1_restore_day2_exact=True,
            origin_unchanged=True,discarded_token_refused=True))
(a.output/'RESULT.json').write_text(json.dumps(dict(status='PUBLISHER_EXTERNAL_CONTRACT_PASS',profiles=reports),indent=2)+'\n')
print('PUBLISHER_EXTERNAL_CONTRACT_PASS',flush=True)
