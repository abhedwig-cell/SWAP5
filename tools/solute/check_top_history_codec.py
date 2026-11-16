"""Execute the production lookup codec in its complete native original closure."""
import argparse,hashlib,json,shutil,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from history_top_state import render
from daily_host import NO_MACRO_FP_FLAGS

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--scheduled-pond',action='store_true');a=p.parse_args()
    ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    prepared=json.loads((ref/'PREPARED.json').read_text());compiler=Path(shutil.which('gfortran'))
    assert sha(compiler)==prepared['toolchain']['gfortran']['sha256']
    selected=ref/'build/swap-selected';objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj'
    source=selected/'boundtop.f90';assert sha(source)==prepared['provider_files']['build/swap-selected/boundtop.f90']
    profiles=[]
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir();generated=target/'boundtop.f90';generated.write_text(render(source.read_text(encoding='cp1252'),scheduled_pond=a.scheduled_pond),encoding='cp1252')
        driver=ROOT/('tools/solute/drivers/original_scheduled_pond_codec.f90' if a.scheduled_pond else 'tools/solute/drivers/original_top_history_codec.f90')
        flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*NO_MACRO_FP_FLAGS,'-I',str(objects),'-I',str(ttutil)]
        commands=[['gfortran',*flags,'-c',str(generated),str(driver)],
                  ['gfortran','-o',str(target/'codec.exe'),*[str(q) for q in sorted(objects.glob('*.o')) if q.name not in ('swap_main.o','boundtop.o')],str(target/'boundtop.o'),str(target/(driver.stem+'.o')),str(ttutil/'libttutil.a')]]
        compilation=[]
        for command in commands:
            r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        def execute(name,mode,payload=None,refused=False):
            directory=target/name;directory.mkdir()
            if payload is not None:(directory/'state.bin').write_bytes(payload)
            r=subprocess.run([str(target/'codec.exe'),mode],cwd=directory,capture_output=True,text=True,timeout=15)
            (directory/'stdout.log').write_text(r.stdout);(directory/'stderr.log').write_text(r.stderr)
            assert (r.returncode!=0)==refused,(opt,name,r.stdout,r.stderr)
            if refused:assert 'top history' in r.stderr.lower(),(name,r.stderr)
            return directory,dict(name=name,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr)
        valid,positive=execute('valid','valid')
        data=(valid/'state.bin').read_bytes();assert len(data)==(80 if a.scheduled_pond else 72) and data==(valid/'roundtrip.bin').read_bytes()
        attacks=[]
        for name,offset,fmt,value in [('version',0,'i',9),('clock',4,'d',0.),('nan',12,'d',float('nan')),('theta-upper',12,'d',2.),
             ('theta-negative',12,'d',-1.),('katm-negative',20,'d',-1.),('h0max-negative',28,'d',-1.),('k1max-negative',36,'d',-1.),
             ('flag1',60,'i',2),('flag2',64,'i',-1),('trailer',68,'i',0)]:
            offset=offset+8 if a.scheduled_pond and offset>=60 else offset
            changed=bytearray(data);struct.pack_into('='+fmt,changed,offset,value);_,record=execute(name,'consume',bytes(changed),True);attacks.append(record)
        if a.scheduled_pond:
            for name,value in [('pond-negative',-1.),('pond-nan',float('nan'))]:
                changed=bytearray(data);struct.pack_into('=d',changed,60,value);_,record=execute(name,'consume',bytes(changed),True);attacks.append(record)
            _,record=execute('pond-writer-negative','pond-writer-negative',refused=True);attacks.append(record)
        _,record=execute('short','consume',data[:-1],True);attacks.append(record)
        for mode in ('writer-nan','writer-negative','stale-apply'):
            _,record=execute(mode,mode,refused=True);attacks.append(record)
        profiles.append(dict(optimization=opt,original_provider_optimization='O2',compilation=compilation,positive=positive,refusals=attacks,
          roundtrip_exact=True,staged_read_before_assignment=True,generated_source_sha256=sha(generated),executable_sha256=sha(target/'codec.exe')))
    (out/'RESULT.json').write_text(json.dumps(dict(status='PRODUCTION_ORIGINAL_SCHEDULED_POND_CODEC_O0_O2_PASS' if a.scheduled_pond else 'PRODUCTION_ORIGINAL_TOP_HISTORY_CODEC_O0_O2_PASS',compiler=prepared['toolchain']['gfortran'],profiles=profiles,
      production_generator_sha256=sha(ROOT/'app/hybrid_water/history_top_state.py'),original_source_sha256=sha(source),driver_sha256=sha(driver),
      scope='Actual production top component codec in complete original native dependency closure; no model or active macropore execution'),indent=2)+'\n')
    print('PRODUCTION_ORIGINAL_SCHEDULED_POND_CODEC_O0_O2_PASS' if a.scheduled_pond else 'PRODUCTION_ORIGINAL_TOP_HISTORY_CODEC_O0_O2_PASS')

if __name__=='__main__':main()
