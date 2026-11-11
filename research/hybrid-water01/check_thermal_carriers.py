"""Validate actual accepted carrier traces; no model runs or temperature proxies."""
import argparse
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from thermal_carriers import read_accepted_carriers
from heat_receipts import read_accepted_heat

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--runs',type=Path,required=True)
a=p.parse_args();results={}
for folder in sorted(a.runs.iterdir()):
    key=folder.name.split('-')[0]
    if key not in ('hupsel','grass','andelst') or not folder.is_dir():continue
    project={'hupsel':h.HUPSEL,'grass':h.GRASSGROWTH,'andelst':h.ANDELST}[key]
    window=next(folder.glob('window-*'))
    receipts=[json.loads(l) for l in (window/'daily.jsonl').read_text().splitlines()]
    trace=window/'original/original-thermal-carriers.txt'
    heat=window/'original/original-heat-accounting.txt'
    report=read_accepted_carriers(trace,receipts,project)
    thermal=read_accepted_heat(heat,receipts,project)
    assert [(d['day'],d['steps']) for d in report['daily']]==[(d['day'],d['steps']) for d in thermal['daily']]
    # Match every actual water/heat frame and nodal state, not daily integrals alone.
    cl=iter(trace.read_text().splitlines());hl=iter(heat.read_text().splitlines())
    for line in cl:
        c=line.split();t=next(hl).split()
        assert list(map(float,c[1:3]))==list(map(float,t[1:3])) and int(c[3])==int(t[3])
        for _ in range(project.nodes):
            cn=next(cl).split();hn=next(hl).split()
            assert cn[1]==hn[1]
            assert list(map(float,[cn[i] for i in (2,4,5,14,15)]))==list(map(float,[hn[i] for i in (2,4,5,6,7)]))
    assert next(hl,None) is None
    assert not read_accepted_carriers(trace,[],project)['daily']
    assert not read_accepted_carriers(trace,[dict(r,committed=False) for r in receipts],project)['daily']
    assert len(read_accepted_carriers(trace,receipts[:1],project)['daily'])==1
    # Actual-data corruptions. Tiny nonzero paths remain active; no heat cutoff.
    rows=trace.read_text().splitlines();bad=folder/'bad-carrier.txt'
    attacks={}
    for name,index,value in [('face',8,1e-3),('water',5,1e-3),('temperature',14,float('nan'))]:
        copy=rows.copy();node=copy[1].split();node[index]=str(float(node[index])+value);copy[1]=' '.join(node)
        bad.write_text('\n'.join(copy)+'\n')
        try:read_accepted_carriers(bad,receipts,project)
        except ValueError:attacks[name]='REFUSED'
        else:raise AssertionError(name+' corruption accepted')
    copy=rows.copy();header=copy[0].split();header[1]=str(float(header[1])+0.001);copy[0]=' '.join(header)
    bad.write_text('\n'.join(copy)+'\n')
    try:read_accepted_carriers(bad,receipts,project)
    except ValueError:attacks['clock']='REFUSED'
    else:raise AssertionError('clock corruption accepted')
    bad.unlink()
    report['guards']=attacks
    report['trace_sha256']=h.sha(trace)
    report['heat_trace_sha256']=h.sha(heat)
    report['accepted_receipts_sha256']=h.sha(window/'daily.jsonl')
    report['exact_original_water_heat_step_and_nodal_alignment']=True
    results[folder.name]=report
assert results,'No actual cases selected'
out={'status':'ACTUAL_ACCEPTED_THERMAL_CARRIER_INVENTORY_PASS_FULL_ENERGY_UNAVAILABLE',
     'results':results,'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/thermal_carriers.py',
     'app/hybrid_water/heat_receipts.py',
     'research/hybrid-water01/check_thermal_carriers.py','research/hybrid-water01/qualify_original_heat_accounting.py']}}
(a.runs/'THERMAL_CARRIERS.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:r['daily'] for k,r in results.items()}))
