"""Execute the independent actually affected weather codec; no rotation promotion."""
import argparse,json,os,sys
from pathlib import Path
import native_crop_adapter_runtime as base
ROOT=base.ROOT

def verify_build(folder):
    b=json.loads((folder/'BUILD.json').read_text())
    assert all(base.sha(Path(p))==h for field in ('sources_sha256','objects_sha256','drivers_sha256')for p,h in b[field].items())
    suffix='.exe'if os.name=='nt'else''
    assert all(base.sha(folder/(name+suffix))==h for name,h in b['executables_sha256'].items())
    return b

def execute(exes,fixture,out,opt):
    events=[];sys.path.insert(0,str(ROOT/'tests/mc-irr01'))
    from tcs6_native_controls import execute as controls
    base.command([exes['m']],out,events,'weather-schema-matrix')
    args=[fixture/n for n in ('weather.999','altered.999','bad.999','backup.999')]
    base.command([exes['w'],*args,'continuous','neutral'],out,events,'weather-independent-continuous',900)
    class Session:
        def command(self,args,cwd,label):
            raw=base.command(args,cwd,events,label)
            return raw,dict(returncode=events[-1]['returncode'],wall_seconds=events[-1]['seconds'])
    reports={}
    for phase in ('neutral','hydraulic'):
        for mode in ('native-write','native-resume','native-write-active','native-resume-active'):
            base.command([exes['w'],*args,mode,phase],out,events,'weather-'+phase+'-'+mode,900)
        tag='morning'if phase=='neutral'else'dayend'
        files=[Path(str(exes['w'])+'.'+tag+'.'+suffix)for suffix in ('full','opaque','resumed','active.resumed')]
        assert all(p.read_bytes()==files[0].read_bytes()for p in files)
        assert files[0].read_bytes()[:4]==b'S5WI','actual weather adapter native tag'
        reports[phase]=controls(Session(),exes['w'],fixture,phase,out,opt,'weather')
        assert len(reports[phase])>=16
    (out/'WEATHER_EXECUTED.json').write_text(json.dumps(dict(status='ACTUAL_WEATHER_DEFAULT_CODEC_AND_NATIVE_REFUSALS_PASS',events=events,controls=reports),indent=2)+'\n')

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--existing-incumbent',action='store_true');a=p.parse_args()
    os.environ['OMP_NUM_THREADS']='1';out=a.out.resolve();compiler=a.compiler.resolve();suffix='.exe'if os.name=='nt'else''
    if a.existing_incumbent:
        b=verify_build(out/'incumbent');assert not b['candidate']
        assert (out/'ROTATION_BASELINE_REFUSAL.json').is_file()
        prepared=json.loads((out/'PREPARED.json').read_text());providers=[ROOT/p for p in prepared['providers']]
        external=[Path(p)for p in prepared['externals']]
        from native_crop_adapter_fixture import prepare as rotation_fixture
        external+=rotation_fixture(ROOT,out/'fixture')
        drivers={n:Path(path)for n,path in prepared['drivers'].items()if n in ('w','m')}
        verify_build(out/'incumbent')
    else:
        providers,external,drivers,inputs=base.prepare(out);drivers={n:path for n,path in drivers.items()if n in ('w','m')}
        base.build(out/'incumbent',compiler,a.optimization,providers,external,drivers,out/'fixture',False)
    for name in ('incumbent','candidate'):
        folder=out/name
        if name=='candidate':base.build(folder,compiler,a.optimization,providers,external,drivers,out/'fixture',True)
        b=verify_build(folder);assert '-'+a.optimization in b['flags']
        execute({n:folder/(n+suffix)for n in ('w','m')},out/'fixture',folder,a.optimization)
    before=json.loads((out/'incumbent/BUILD.json').read_text());after=json.loads((out/'candidate/BUILD.json').read_text())
    left=dict(before['sources_sha256']);right=dict(after['sources_sha256']);left.pop(str(ROOT/base.policy.SOURCE));right.pop(str(out/'candidate/private_codec.f90'));assert left==right
    names=[f'schema-{mode}-{j}.bin'for mode in range(4)for j in range(2)]+['w'+suffix+'.'+phase+'.'+kind for phase in ('morning','dayend')for kind in ('full','opaque','resumed','active.resumed')]
    for name in names:assert(out/'incumbent'/name).read_bytes()==(out/'candidate'/name).read_bytes(),name
    (out/'WEATHER_RESULT.json').write_text(json.dumps(dict(status='ACTUAL_WEATHER_NATIVE_AND_EIGHT_SCHEMAS_BYTE_EXACT_PASS',optimization=a.optimization,providers=len(providers),byte_exact_files={n:base.sha(out/'candidate'/n)for n in names},rotation_qualified=False,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('WEATHER_DEFAULT_CODEC_NATIVE_AND_SCHEMA_MATRIX_PASS',a.optimization)

if __name__=='__main__':main()
