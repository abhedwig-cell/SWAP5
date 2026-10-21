"""Verify the bounded precision finding and retain unsuccessful full-model trials."""
import base64
import csv
from decimal import Decimal
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[2]
BASE='fda2a6de35ab60e8c836a6687482efa3774d95dc'
INDEX=ROOT/'integration/diagnostics/evidence/perf01-precision-20261021/INDEX.json'


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(raw):return hashlib.sha256(raw).hexdigest()


def capsule():
    index=json.loads(INDEX.read_text())
    raw=base64.b64decode(b''.join((INDEX.parent/p).read_bytes() for p in index['parts']),validate=True)
    require(sha(raw)==index['decoded_sha256'],'capsule hash')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members=archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe member')
        require(len(members)==len({m.name for m in members}),'duplicate member')
        files={m.name:archive.extractfile(m).read() for m in members}
    manifest=files.pop('MEMBERS.json');inventory=json.loads(manifest)
    require(sha(manifest)==index['members_sha256'] and files.keys()==inventory.keys(),'member manifest')
    require(all(sha(files[p])==h for p,h in inventory.items()),'member digest')
    return files


def validate(files):
    load=lambda p:json.loads(files[p])
    rows=lambda p:list(csv.DictReader(io.StringIO(files[p].decode())))
    counters=lambda p:[{k:v for k,v in r.items() if k!='cpu'} for r in rows(p)]
    prior=runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_dry.py'))['capsule']()
    replay=runpy.run_path(str(ROOT/'integration/diagnostics/replay_perf01_precision.py'))
    for opt in ['O0','O2']:
        prefix='capture-'+opt
        b=load(prefix+'/BUILD.json')
        require(len(b['build']['input_sha256'])==178,'fresh column closure')
        require('-'+opt in b['build']['flags'] and '-ffpe-trap=invalid,zero,overflow' in b['build']['flags'],'profile flags')
        if opt=='O0':require('-fcheck=all' in b['build']['flags'],'checked profile')
        for p,h in b['build']['input_sha256'].items():
            require(sha(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT))==h,'historical provider '+p)
        require(load(prefix+'/RESULT.json')['returncode']==1,'original failure relabelled')
        for name in ['budget.csv','trajectory.csv','stdout']:
            require(files[prefix+'/native/'+name]==prior['oracle/'+name],'native failure changed '+name)
        require(counters(prefix+'/native/work.csv')==[{k:v for k,v in r.items() if k!='cpu'} for r in list(csv.DictReader(io.StringIO(prior['oracle/work.csv'].decode())))],'native work changed')
        for p,h in b['generated_sha256'].items():require(sha(files[prefix+'/observer/'+p])==h,'capture source')
        for p,h in load(prefix+'/RESULT.json')['raw_sha256'].items():require(sha(files[prefix+'/native/'+p])==h,'capture raw')
        with tempfile.TemporaryDirectory(prefix='perf01-precision-verify-') as tmp:
            native=Path(tmp)
            for name in ['iterate.csv','coefficients.csv','solve.csv']:(native/name).write_bytes(files[prefix+'/native/'+name])
            for digits,observed in zip([80,120],load('standalone-'+opt+'/REPLAY.json')['arithmetic']):
                calculated=replay['high_precision'](native,digits)
                require(calculated==observed,'independent arithmetic reconstruction')
                require(calculated['unchanged_heads_after_native_subtraction']==32 and calculated['maximum_newton_to_head_ulp']<.5,'head quantization')
                tol=calculated['total_tolerance']
                require(abs(calculated['exact_rounded_primitive_sum_float'])>tol,'exact primitive criterion')
                require(abs(Decimal(calculated['high_precision_retention_frozen_heads']['total']))>Decimal(tol),'high precision frozen criterion')
                require(abs(Decimal(calculated['high_precision_retention_unrounded_newton_heads']['total']))<Decimal('1e-14'),'unrounded Newton counterfactual')
        for name in ['replay-'+opt,'standalone-'+opt]:
            r=load(name+'/REPLAY.json')
            require(r['returncode']==0 and b'FROZEN_NATIVE_RESIDUAL_AND_INCREMENT_EXACT=PASS' in files[name+'/stdout'],'native isolated replay')
            require(sum(x['valid']=='T' for x in rows(name+'/candidates.csv'))==25,'one ULP feasible set')
            require(r['source_sha256']==sha((ROOT/'integration/diagnostics/perf01_precision_replay.f90').read_bytes()),'driver source')
            if name.startswith('standalone'):
                require(len(r['fresh_closure_sha256'])==3 and not r['linked_object_sha256'],'standalone closure')
                for p,h in r['fresh_closure_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'standalone source')
        result=load('prefix-'+opt+'/TRIAL.json')['runs']
        require(len(result)==1 and result[0]['windows']==5 and result[0]['returncode']==0,'prefix completion')
        require(result[0]['address_space_mib']==512 and result[0]['timeout_seconds']==30,'prefix resource bound')
        for p,h in result[0]['raw_sha256'].items():require(sha(files['prefix-'+opt+'/5/'+p])==h,'prefix raw')
    for p in ['iterate.csv','coefficients.csv','solve.csv']:
        require(files['capture-O0/native/'+p]==files['capture-O2/native/'+p],'capture O0/O2')
    for p in ['budget.csv','trajectory.csv','state.csv','endpoint.csv','restart.bin','rounding.csv']:
        require(files['prefix-O0/5/'+p]==files['prefix-O2/5/'+p],'prefix O0/O2 '+p)
    require(counters('prefix-O0/5/work.csv')==counters('prefix-O2/5/work.csv'),'prefix work O0/O2')
    for p in ['candidates.csv','best.csv']:
        require(files['standalone-O0/'+p]==files['standalone-O2/'+p]==files['replay-O2/'+p],'isolated O0/O2')
    budgets=rows('prefix-O2/5/budget.csv')
    require(len(budgets)==5 and float(rows('prefix-O2/5/endpoint.csv')[0]['time_day'])==.078125,'prefix horizon')
    mass={p:max(abs(float(r[p])) for r in budgets) for p in ['water_residual_cm','solute_residual_mg_cm2']}
    require(all(v<1e-10 for v in mass.values()),'prefix balances')
    killed=load('trial-O2/TRIAL.json')['runs']
    require(len(killed)==1 and killed[0]['windows']==6 and killed[0]['returncode']==-9,'retained SIGKILL relabelled')
    bounded=load('progress-O2/TRIAL.json')['runs']
    require(len(bounded)==1 and bounded[0]['returncode']==1 and bounded[0]['address_space_mib']==512,'bounded progress failure')
    require(b'Cannot allocate memory' in files['progress-O2/6/stderr'],'progress allocation failure')
    control=load('resource-control/CONTROL.json')['runs']
    require(len(control)==2 and [r['returncode'] for r in control]==[0,1],'paired unmodified control')
    require(all(r['address_space_mib']==512 for r in control) and b'Cannot allocate memory' in files['resource-control/6/stderr'],'paired resource failure')
    progress=rows('progress-O2/6/progress.csv')[-1]
    require(.078125<float(progress['cursor'])<.09375,'partial progress relabelled complete')
    return dict(status='ISOLATED_HEAD_QUANTIZATION_VERIFIED_NO_PRODUCTION_CORRECTION',baseline=BASE,
        fresh_column_builds=2,source_providers_per_build=178,exact_native_captures=2,
        native_isolated_replays=4,fresh_standalone_providers=3,feasible_one_ulp_neighbours=25,
        completed_experimental_prefixes=2,prefix_mass_residuals=mass,progress_last_sample=progress,
        full_model_censored_or_resource_limited_runs=3,paired_resource_control_retained=True,
        production_changed=False,production_qualified=False,long_dry_regime_qualified=False)


def self_test(files):
    rejected=[]
    for key,edit in [
        ('capture-O0/native/iterate.csv',lambda r:r+b'altered'),
        ('standalone-O2/REPLAY.json',lambda r:r.replace(b'"unchanged_heads_after_native_subtraction": 32',b'"unchanged_heads_after_native_subtraction": 0')),
        ('trial-O2/TRIAL.json',lambda r:r.replace(b'"returncode": -9',b'"returncode": 0')),
        ('prefix-O0/5/restart.bin',lambda r:r+b'!'),
        ('resource-control/6/stderr',lambda r:b''),
        ('progress-O2/6/progress.csv',lambda r:r.replace(b'8.65437051650269490E-002',b'9.37500000000000000E-002'))]:
        broken=dict(files);broken[key]=edit(broken[key])
        try:validate(broken)
        except (ValueError,KeyError):rejected.append(key)
        else:raise ValueError('accepted corruption '+key)
    return dict(count=len(rejected),negative_controls=rejected)


if __name__=='__main__':
    files=capsule();report=validate(files)
    if '--self-test' in sys.argv:report['self_test']=self_test(files)
    print(json.dumps(report,indent=2))
