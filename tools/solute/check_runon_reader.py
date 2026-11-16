"""Execute the complete original runon reader at O0/O2 without a model run."""
import argparse,hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    prepared=json.loads((ref/'PREPARED.json').read_text());assert sha(Path(shutil.which('gfortran')))==prepared['toolchain']['gfortran']['sha256']
    objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj';original=ref/'build/swap-selected/MOD_runon.f90';profiles=[]
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir();source=target/'MOD_runon.f90';source.write_bytes(original.read_bytes())
        driver=ROOT/'tools/solute/drivers/original_runon_reader.f90'
        commands=[['gfortran','-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(objects),'-I',str(ttutil),'-c',str(source),str(driver)],
                  ['gfortran','-o',str(target/'reader.exe'),*[str(q) for q in sorted(objects.glob('*.o')) if q.name.lower() not in ('swap_main.o','mod_runon.o')],str(target/'MOD_runon.o'),str(target/'original_runon_reader.o'),str(ttutil/'libttutil.a')]]
        compilation=[]
        for cmd in commands:
            r=subprocess.run(cmd,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=cmd,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        valid='DATE AMOUNT\n2002-01-01 0.0\n2002-01-02 3.0\n2002-01-03 0.0\n2002-01-04 6.0\n2002-01-05 0.0\n2002-01-08 0.0\n'
        def execute(name,start,body=valid,missing=False,refused=False):
            work=target/name;work.mkdir();(work/'reader.swp').write_text("RUFIL = 'surface'\n")
            if not missing:(work/'surface.ru').write_text(body)
            r=subprocess.run([str(target/'reader.exe'),str(start)],cwd=work,capture_output=True,text=True,timeout=15)
            (work/'stdout.log').write_text(r.stdout);(work/'stderr.log').write_text(r.stderr)
            error=(work/'reader.err').read_text(errors='replace')
            if refused:
                # Original swap_error terminates with STOP0; require its real
                # diagnostic and absence of the successful reader publication.
                assert not (work/'values.txt').exists() and 'ERROR' in error,(opt,name,r.stdout,r.stderr,error)
            else:assert r.returncode==0 and (work/'values.txt').exists(),(opt,name,r.stdout,r.stderr,error)
            data=[list(map(float,line.split())) for line in (work/'values.txt').read_text().splitlines()] if not refused else None
            return dict(name=name,returncode=r.returncode,refused=refused,original_error_log=error,values=data,stdout=r.stdout,stderr=r.stderr)
        warm=execute('warm',37256);cold=execute('cold',37258);between=execute('between-events',37258.5)
        assert warm['values']==[[37257,3*.1],[37258,0],[37259,6*.1],[37260,0],[37263,0],[37265,0]],warm
        assert cold['values']==[v for v in warm['values'] if v[0]>=37258]
        assert between['values']==[v for v in warm['values'] if v[0]>=37258.5]
        attacks=[execute('missing',37256,missing=True,refused=True),execute('negative',37256,body=valid.replace('2002-01-04 6.0','2002-01-04 -1.0'),refused=True),execute('duplicate',37256,body=valid.replace('2002-01-03 0.0','2002-01-02 0.0'),refused=True),execute('unordered',37256,body=valid.replace('2002-01-03 0.0','2001-12-30 0.0'),refused=True)]
        profiles.append(dict(optimization=opt,original_provider_optimization='O2',compilation=compilation,warm=warm,cold=cold,between_events=between,refusals=attacks,original_source_sha256=sha(source),executable_sha256=sha(target/'reader.exe')))
    result=dict(status='COMPLETE_ORIGINAL_RUNON_READER_O0_O2_PASS',profiles=profiles,compiler=prepared['toolchain']['gfortran'],driver_sha256=sha(driver),scope='Actual original MOD_runon + original native dependency/TTUTIL closure; no copied reader or formula and no model/macro execution')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])


if __name__=='__main__':main()
