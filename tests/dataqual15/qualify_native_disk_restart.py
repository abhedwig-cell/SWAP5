"""Short real original Grassgrowth trajectory, exact disk resume and bad streams.

The unchanged native codec is tested on the new publication platform. This is
not a full-season scientific or cross-platform binary restart qualification.
"""
import argparse,csv,hashlib,json,math,shutil,struct,subprocess,time,zlib
from pathlib import Path
from checkpoint_layout import layout

sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();base=args.bundle.resolve();out=args.output.resolve();out.mkdir(parents=True)
    build=json.loads((base/'BUILD.json').read_text());exe=base/build.get('executable','swap5_grass_startup')
    assert sha(exe)==build['executable_sha256']
    assert build['native_returncode']==0 and build['original_project_completed_days']==1
    assert all(sha(Path(p))==h for p,h in build['source_sha256'].items())
    checkpoint=base/'original-interval/checkpoint.bin';raw=checkpoint.read_bytes();d=layout(raw);assert d['clock']==1
    names=[*build['original_inputs_sha256'],'application.binding'];events=[]
    thermal=build.get('grass_numerical_profile','water-only')=='thermal-control-1e-5C'
    def case(name):
        folder=out/name;folder.mkdir()
        for n in names:shutil.copyfile(base/'original-interval'/n,folder/n)
        return folder
    def run(folder,restart=None):
        cmd=[str(exe),'3','retain-step','100000']+([str(restart)] if restart else [])
        if thermal:cmd=[str(exe),'3','retain-step','100000',str(restart)if restart else'','thermal-control']
        start=time.monotonic();r=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=90)
        (folder/'stdout').write_bytes(r.stdout);(folder/'stderr').write_bytes(r.stderr)
        events.append(dict(case=folder.name,command=cmd,returncode=r.returncode,seconds=time.monotonic()-start))
        return r
    uninterrupted=case('continuous');assert run(uninterrupted).returncode==0
    resumed=case('resume');incoming=resumed/'incoming.bin';incoming.write_bytes(raw)
    assert run(resumed,incoming).returncode==0 and incoming.read_bytes()==raw
    assert (uninterrupted/'checkpoint.bin').read_bytes()==(resumed/'checkpoint.bin').read_bytes()
    for name in ['budget.csv','crop.csv']:
        rows=lambda folder:list(csv.DictReader((folder/name).open()))
        assert rows(uninterrupted)[1:]==rows(resumed),name
    budget=list(csv.DictReader((uninterrupted/'budget.csv').open()))
    assert [int(row['day'])for row in budget]==[1,2,3]
    for row in budget:
        assert all(math.isfinite(float(v))for v in row.values())
        assert abs(float(row['residual_cm']))<1e-10
        assert abs(float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['input_cm'])+float(row['output_cm']))<1e-10
    controls=['crc','truncated','layout','clock','source','roots','delay','potential_delay','cut_index','yield_nan']
    active_compat=[at for at in d['compatibility']if struct.unpack_from('=i',raw,at)[0]]
    if active_compat:controls.append('compatibility_nan')
    for kind in controls:
        folder=case(kind);bad=bytearray(raw)
        if kind=='crc':bad[d['header']+16]^=1
        elif kind=='truncated':bad=bad[:-7]
        elif kind=='layout':struct.pack_into('=i',bad,d['header'],112)
        elif kind=='clock':struct.pack_into('=d',bad,d['header']+4,1.5)
        elif kind=='source':(folder/'input.swp').write_bytes(b'* changed input\n'+(folder/'input.swp').read_bytes())
        elif kind=='roots':struct.pack_into('=d',bad,d['roots']+8,1000.)
        elif kind=='delay':struct.pack_into('=i',bad,d['actual']['start']+164+24*d['actual']['leaves']-4,-1)
        elif kind=='potential_delay':struct.pack_into('=i',bad,d['management'],-1)
        elif kind=='cut_index':struct.pack_into('=i',bad,d['management']+20,0)
        elif kind=='yield_nan':struct.pack_into('=d',bad,d['management']+4,float('nan'))
        elif kind=='compatibility_nan':struct.pack_into('=d',bad,active_compat[-1]+4,float('nan'))
        if kind not in ['crc','truncated']:struct.pack_into('=I',bad,len(bad)-4,zlib.crc32(bad[:-4]))
        incoming=folder/'bad.bin';incoming.write_bytes(bad);r=run(folder,incoming)
        assert r.returncode!=0 and b'bound grass prefix restart rejected'in r.stdout,kind
        assert not(folder/'checkpoint.bin').exists()and not(folder/'budget.csv').exists(),kind
    assert checkpoint.read_bytes()==raw
    profile_controls=[]
    if thermal:
        for kind in ['missing-marker','wrong-marker','duplicate-marker','missing-switch','wrong-switch']:
            folder=case('profile-'+kind)
            binding=folder/'application.binding';data=json.loads(binding.read_text())
            if kind=='missing-marker':del data['grass_numerical_profile']
            if kind=='wrong-marker':data['grass_numerical_profile']='unknown-profile'
            binding.write_text(json.dumps(data,sort_keys=True))
            if kind=='duplicate-marker':binding.write_text(binding.read_text()[:-1]+',"grass_numerical_profile": "thermal-control-1e-5C"}')
            cmd=[str(exe),'3','retain-step','100000','','thermal-control']
            if kind=='missing-switch':cmd=cmd[:4]
            if kind=='wrong-switch':cmd[-1]='unknown-profile'
            r=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=30)
            (folder/'stdout').write_bytes(r.stdout);(folder/'stderr').write_bytes(r.stderr)
            assert r.returncode!=0 and not(folder/'checkpoint.bin').exists()and not(folder/'budget.csv').exists(),kind
            profile_controls.append(dict(case=kind,returncode=r.returncode,command=cmd))
    result=dict(status='NATIVE_ORIGINAL_DISK_RESTART_PASS',original_days=3,
                optimization=next(f[1:] for f in build['flags']if f in ['-O0','-O2']),
                exact_restart='1 -> 3; final full checkpoint and daily water/crop rows byte exact',
                invalid_restart_controls=controls,profile_controls=profile_controls,inactive_compatibility_control_not_selected=not bool(active_compat),
                executable_sha256=sha(exe),source_sha256=build['source_sha256'],
                maximum_water_residual_cm=max(abs(float(row['residual_cm']))for row in budget),
                final_checkpoint_sha256=sha(uninterrupted/'checkpoint.bin'),events=events)
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items()if k not in ['source_sha256','events']},indent=2))

if __name__=='__main__':main()
