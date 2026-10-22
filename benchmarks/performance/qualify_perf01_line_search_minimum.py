"""Confirm the existing typed legacy-minimum-step deferral for both option states."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
base=Path('/tmp/perf01-line-search-direct-final');out=Path('/tmp/perf01-lsr-minimum');out.mkdir(exist_ok=False)
meta=json.loads((base/'RESULT.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert all(sha(ROOT/p)==h for p,h in meta['input_sha256'].items())
text=(base/'driver.f90').read_text().replace(' implicit none',' use variables,only:fldtmin\n implicit none',1)
anchor=" print *, 'WEATHER_LINE_SEARCH_RETRY_TYPED_CONTRACT_PASS'"
assert text.count(anchor)==1
extra=""" r%request_interface_sensitivity=.false.
 fldtmin=.true.
 r%numerical%abort_failed_line_search=.false.;call solver%solve(r,cold,c)
 r%numerical%abort_failed_line_search=.true.;call solver%solve(r,warm,v)
 call require(v%status==SW_SOLVE_FAILED.and.c%status==SW_SOLVE_FAILED,'legacy minimum mode remains deferred')
 call require(v%diagnostics%headcalc_calls==0.and.c%diagnostics%headcalc_calls==0,'minimum mode never enters Newton')
 call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta),'minimum rejection immutable')
 fldtmin=.false.
 print *, 'WEATHER_LINE_SEARCH_MINIMUM_DEFERRED_OFF_ON_PASS'
"""
text=text.replace(anchor,extra+anchor,1);driver=out/'driver.f90';driver.write_text(text)
events=[]
for opt in ['O0','O2']:
    b=out/opt;b.mkdir()
    old=[e for e in meta['events']if e['optimization']==opt and e['label']=='compile']
    objects=[Path(e['command'][-1])for e in old];pinned={str(p):sha(p)for p in objects}
    command=old[0]['command'];flags=command[1:command.index('-c')]
    flags=[('-J'+str(b))if p.startswith('-J')else p for p in flags]
    for label,cmd in [('link',[command[0],*flags,str(driver),*map(str,objects),'-o',str(b/'minimum')]),('native',[str(b/'minimum')])]:
        started=time.monotonic();r=subprocess.run(cmd,cwd=b,capture_output=True)
        for stream in ['stdout','stderr']:(b/(label+'.'+stream)).write_bytes(getattr(r,stream))
        events.append(dict(command=cmd,label=label,optimization=opt,seconds=time.monotonic()-started,returncode=r.returncode))
        r.check_returncode()
        if label=='native':assert b'WEATHER_LINE_SEARCH_MINIMUM_DEFERRED_OFF_ON_PASS'in r.stdout
    assert all(sha(Path(p))==h for p,h in pinned.items())
(out/'RESULT.json').write_text(json.dumps(dict(status='EXISTING_TYPED_MINIMUM_DEFERRAL_OFF_ON_O0_O2_PASS',events=events,
    input_sha256=meta['input_sha256'],generated_driver_sha256=sha(driver)),indent=2)+'\n')
print('EXISTING_TYPED_MINIMUM_DEFERRAL_OFF_ON_O0_O2_PASS')
