"""Real original top component, selected v2 and byte-exact old v1 emission."""
from pathlib import Path
import json, struct, subprocess, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from history_top_state import render
from daily_host import NO_MACRO_FP_FLAGS,sha


def main():
    reference=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
    objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
    raw=(reference/'build/swap-selected/boundtop.f90').read_text(encoding='cp1252')
    previous={};exec(subprocess.check_output(['git','show','d4ccdc7cb:app/hybrid_water/history_top_state.py'],cwd=ROOT,text=True),previous)
    assert render(raw)==previous['render'](raw),'unselected v1 source drift'
    reports={}
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir()
        source=target/'boundtop.f90';source.write_text(render(raw,scheduled_pond=True),encoding='cp1252')
        driver=(ROOT/'tools/solute/drivers/original_top_history_codec.f90').read_text()
        driver=driver.replace('use variables,only:t1900','use variables,only:t1900,pondmx')
        driver=driver.replace('theatm=.2d0;', 'pondmx=.197938023450583d0\nif(trim(mode)==\'pondmx-nan\')pondmx=ieee_value(0d0,ieee_quiet_nan)\nif(trim(mode)==\'pondmx-negative\')pondmx=-.1d0\ntheatm=.2d0;')
        driver=driver.replace('theatm=.4d0;', 'pondmx=.2d0\ntheatm=.4d0;')
        driver=driver.replace("if(theatm/=.4d0.or.katm/=.002d0)","if(pondmx/=.2d0.or.theatm/=.4d0.or.katm/=.002d0)")
        driver=driver.replace("if(theatm/=.2d0.or.katm/=.001d0", "if(pondmx/=.197938023450583d0.or.theatm/=.2d0.or.katm/=.001d0")
        path=target/'original_top_history_codec.f90';path.write_text(driver)
        flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*NO_MACRO_FP_FLAGS,'-I',str(objects),'-I',str(ttutil)]
        commands=[['gfortran',*flags,'-c',str(source),str(path)],['gfortran','-o',str(target/'codec.exe'),*[str(p) for p in sorted(objects.glob('*.o')) if p.name not in ('swap_main.o','boundtop.o')],str(target/'boundtop.o'),str(target/'original_top_history_codec.o'),str(ttutil/'libttutil.a')]]
        events=[]
        for command in commands:
            r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=60);events.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        def execute(name,mode,payload=None,refuse=False):
            folder=target/name;folder.mkdir()
            if payload is not None:(folder/'state.bin').write_bytes(payload)
            r=subprocess.run([str(target/'codec.exe'),mode],cwd=folder,capture_output=True,text=True,timeout=10)
            (folder/'stdout').write_text(r.stdout);(folder/'stderr').write_text(r.stderr)
            assert (r.returncode!=0)==refuse,(name,r.stdout,r.stderr)
            return folder,dict(name=name,returncode=r.returncode,stderr=r.stderr)
        valid,positive=execute('valid','valid');data=(valid/'state.bin').read_bytes()
        assert len(data)==80 and data==(valid/'roundtrip.bin').read_bytes()
        assert struct.unpack_from('=i',data)[0]==2 and struct.unpack_from('=d',data,60)[0]==.197938023450583
        attacks=[]
        for name,payload in [('old-version',struct.pack('=i',1)+data[4:]),('short',data[:-1]),('nan-pondmx',data[:60]+struct.pack('=d',float('nan'))+data[68:]),('negative-pondmx',data[:60]+struct.pack('=d',-.1)+data[68:]),('clock',data[:4]+struct.pack('=d',0.)+data[12:]),('trailer',data[:-4]+struct.pack('=i',72)),('invalid-flag',data[:68]+struct.pack('=i',2)+data[72:])]:
            _,result=execute(name,'consume',payload,True);attacks.append(result)
        for mode in ('pondmx-nan','pondmx-negative','stale-apply'):
            _,result=execute(mode,mode,refuse=True);attacks.append(result)
        reports[opt]=dict(status='PASS',state_bytes=80,roundtrip_exact=True,staged_assignment=True,negative_tests=attacks,compilation=events,executable_sha256=sha(target/'codec.exe'))
    (out/'RESULT.json').write_text(json.dumps(dict(status='SCHEDULED_PONDMX_TOP_CODEC_O0_O2_PASS',legacy_v1_emitted_source_byte_exact=True,profiles=reports),indent=2))
    print('SCHEDULED_PONDMX_TOP_CODEC_O0_O2_PASS')


if __name__=='__main__':main()
