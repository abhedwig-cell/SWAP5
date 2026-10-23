"""Checked pulse accuracy and separate-process committed disk qualification."""
import argparse,hashlib,importlib.util,itertools,json,os,runpy,struct,subprocess,sys,tempfile,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
PREVIOUS=HERE.parent/'fct_reactive'
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--pulse-only',action='store_true');a=ap.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    generated=runpy.run_path(str(HERE/'generate.py'))['sources']()
    for name,b in generated.items():(out/name).write_bytes(b)
    dep=ROOT/'tests/support/augment_bartholomeus_backend_sources.py';spec=importlib.util.spec_from_file_location('deps',dep);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
    with tempfile.TemporaryDirectory(dir=ROOT,prefix='.mc-sol01-disk-') as name:
        folder=Path(name);lookup={}
        for name,b in generated.items():
            p=folder/name;p.write_bytes(b);lookup[p]=out/name
        extra=[*map(str,lookup),str(PREVIOUS/'mod_research_composed_fct.f90'),str(HERE/'mod_research_restart_bridge.f90'),'app/solute_column/link_context.f90']
        pulse,_=deps.strict_closure(ROOT,[str(HERE/'pulse_driver.f90')],extra)
        disk,_=deps.strict_closure(ROOT,[str(folder/'disk_driver.f90')],extra)
        disk.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
        closures={k:[lookup.get(p,p) for p in v] for k,v in [('pulse',pulse),('disk',disk)]}
    inputs={p for v in closures.values() for p in v if p.is_relative_to(ROOT)}
    inputs.update([dep,HERE/'generate.py',HERE/'run.py',HERE/'checkpoint.py',HERE/'disk_body.inc',PREVIOUS/'generate.py',
        ROOT/'integration/mc-sol01/fct_joint_acceptance/run.py',ROOT/'integration/mc-sol01/fct_joint_acceptance/driver.inc',
        ROOT/'integration/mc-sol01/fct_accepted_trace/qualify_replay.py',ROOT/'integration/mc-sol01/fct_accepted_trace/water_driver.f90',
        ROOT/'integration/mc-sol01/fct_accepted_trace/mod_research_trace_replay.f90',
        ROOT/'integration/mc-sol01/fct_joint_acceptance/mod_research_joint_fct.f90',
        ROOT/'integration/mc-sol01/fct_water_sorption/mod_research_storage_fct.f90'])
    r=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sorted(inputs)},generated={p:sha(b) for p,b in generated.items()},
        closures={k:list(map(str,v)) for k,v in closures.items()},events=[],pulse_cases=[],disk_cases=[],artifacts={},production_activated=False)
    policy=sha(json.dumps(dict(inputs=r['inputs'],generated=r['generated']),sort_keys=True).encode());r['policy']=policy
    cp=runpy.run_path(str(HERE/'checkpoint.py'));save=lambda:(out/'execution.json').write_text(json.dumps(r,indent=2)+'\n')
    def artifact(path):r['artifacts'][str(path.relative_to(out))]=sha(path.read_bytes())
    def run(cmd,cwd,expected=0):
        t=time.monotonic()
        try:c=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=180)
        except subprocess.TimeoutExpired as e:c=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'')
        e=dict(command=list(map(str,cmd)),returncode=c.returncode,expected=expected,seconds=time.monotonic()-t)
        for s in ['stdout','stderr']:
            b=getattr(c,s);e[s]=f'{len(r["events"]):03d}.{s}';e[s+'_sha256']=sha(b);(out/e[s]).write_bytes(b)
        r['events'].append(e)
        if c.returncode!=expected:r['status']='CENSORED' if c.returncode==124 else 'FAILED'
        save();assert c.returncode==expected,(e,c.stdout[-1000:],c.stderr[-2000:]);return e
    save();fc=os.environ.get('FC','gfortran');run([fc,'--version'],out)
    r['toolchain_files']={str(Path(p).resolve()):sha(Path(p).read_bytes()) for p in [fc,*filter(None,os.environ.get('SWAP5_FC_IDENTITY_FILES','').split(':'))] if Path(p).is_file()}
    for category in ['pulse']+([] if a.pulse_only else ['disk']):
        for opt in ['O0','O2']:
            folder=out/(category+'-'+opt);folder.mkdir();exe=folder/'driver'
            run([fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*closures[category],'-o',exe],folder)
            if category=='pulse':
                for n,steps,flag in itertools.product([40,80,160],[80,160,320],[0,1]):
                    e=run([exe,n,steps,flag],folder);r['pulse_cases'].append(dict(**e,optimization=opt,n=n,steps=steps,flag=flag));save()
                continue
            for n,factor,exponent in itertools.product([40,80],[.8,1.2],[.5,1.,2.]):
                case=folder/f'case-{n}-{factor}-{exponent}';case.mkdir();context=dict(n=n,factor=factor,exponent=exponent)
                events={};negative=[];crashes=[]
                def native(label,mode,payload,stop=4,exp=exponent):
                    dest=case/label;dest.mkdir();e=run([exe,n,factor,exp,mode,payload,dest,stop],folder)
                    if (dest/'payload.bin').exists():artifact(dest/'payload.bin')
                    events[label]=e;return dest
                full=native('full','full','none')
                split=native('split','full','none',2)
                authority=case/'authority.fct';raw=cp['encode']((split/'payload.bin').read_bytes(),policy,context)
                cp['publish'](raw,authority);artifact(authority)
                extracted=case/'extracted.bin';extracted.write_bytes(cp['decode'](authority.read_bytes(),policy,context));artifact(extracted)
                resumed=native('resumed','resume',extracted)
                assert (full/'payload.bin').read_bytes()==(resumed/'payload.bin').read_bytes(),'fresh process endpoint'
                full_lines=(out/events['full']['stdout']).read_text().splitlines()
                resumed_lines=(out/events['resumed']['stdout']).read_text().splitlines()
                assert [l for l in full_lines if l.startswith(('WINDOW 3 ','WINDOW 4 '))]==[l for l in resumed_lines if l.startswith('WINDOW ')]
                for name,b,pol,ctx in [('damaged',raw[:-1]+bytes([raw[-1]^1]),policy,context),('truncated',raw[:len(raw)//2],policy,context),
                    ('policy',raw,'0'*64,context),('context',raw,policy,{**context,'factor':factor+.1})]:
                    try:cp['decode'](b,pol,ctx)
                    except(AssertionError,ValueError,KeyError):negative.append(name)
                    else:raise AssertionError('accepted '+name)
                wrong=native('wrong-parameters','wrong_parameters',extracted)
                assert not (wrong/'payload.bin').exists();negative.append('native_parameters')
                payload=bytearray(extracted.read_bytes());payload[-10]^=1;corrupt=case/'crc-corrupt.bin';corrupt.write_bytes(payload);artifact(corrupt)
                rejected=native('crc-reject','reject',corrupt);assert not(rejected/'payload.bin').exists();negative.append('native_crc')
                payload=bytearray(extracted.read_bytes());at=len(payload)-4-16*n
                value=struct.unpack_from('<d',payload,at)[0];struct.pack_into('<d',payload,at,value+.125)
                payload[-4:]=struct.pack('<I',zlib.crc32(payload[:-4]));bad=case/'equilibrium-corrupt.bin';bad.write_bytes(payload);artifact(bad)
                rejected=native('equilibrium-reject','reject',bad);assert not(rejected/'payload.bin').exists();negative.append('native_equilibrium_valid_crc')
                if (n,factor,exponent)==(40,.8,1.):
                    third=native('third','resume',extracted,3);generation=case/'new-generation.fct'
                    generation.write_bytes(cp['encode']((third/'payload.bin').read_bytes(),policy,context));artifact(generation)
                    for point in ['before','after']:
                        cp['publish'](raw,authority)
                        e=run([sys.executable,HERE/'checkpoint.py',generation,authority,'--crash',point],folder,-9)
                        expected=raw if point=='before' else generation.read_bytes();assert authority.read_bytes()==expected
                        snapshot=case/('authority-'+point+'.fct');snapshot.write_bytes(authority.read_bytes());artifact(snapshot)
                        restore=case/('restore-'+point+'.bin');restore.write_bytes(cp['decode'](authority.read_bytes(),policy,context));artifact(restore)
                        continued=native('continued-'+point,'resume',restore)
                        assert (continued/'payload.bin').read_bytes()==(full/'payload.bin').read_bytes()
                        crashes.append(dict(point=point,event=e,authority=str(snapshot.relative_to(out)),continued=str((continued/'payload.bin').relative_to(out))))
                    # Record the final authority bytes, not the earlier split generation.
                    artifact(authority)
                r['disk_cases'].append(dict(optimization=opt,**context,events=events,negative_controls=negative,crashes=crashes,
                    full=str((full/'payload.bin').relative_to(out)),split=str((split/'payload.bin').relative_to(out)),resumed=str((resumed/'payload.bin').relative_to(out))))
                save()
    r['status']='PULSE_EXECUTED' if a.pulse_only else 'EXECUTED';save();print(json.dumps(dict(status=r['status'],pulse_cases=len(r['pulse_cases']),disk_cases=len(r['disk_cases'])),indent=2))
if __name__=='__main__':main()
