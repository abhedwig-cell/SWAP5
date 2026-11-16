"""Actual complete production irrigation reader/event and source audit O0/O2."""
import argparse,hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--build-bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--expect-chemical-type2-refusal',action='store_true');a=p.parse_args()
    ref=a.reference_work.resolve();bundle=a.build_bundle.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    prepared=json.loads((ref/'PREPARED.json').read_text());assert sha(Path(shutil.which('gfortran')))==prepared['toolchain']['gfortran']['sha256']
    meta=json.loads((bundle/'BUILD.json').read_text());original=bundle/'irrigation.f90';assert sha(original)==meta['identity']['donor_generated']['irrigation.f90']
    objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj';profiles=[]
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir();source=target/'irrigation.f90';source.write_bytes(original.read_bytes());driver=ROOT/'tools/solute/drivers/original_fixed_irrigation_reader.f90'
        commands=[['gfortran','-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(objects),'-I',str(ttutil),'-c',str(source),str(driver)],
                  ['gfortran','-o',str(target/'reader.exe'),*[str(q) for q in sorted(objects.glob('*.o')) if q.name.lower() not in ('swap_main.o','irrigation.o')],str(target/'irrigation.o'),str(target/'original_fixed_irrigation_reader.o'),str(ttutil/'libttutil.a')]]
        compilation=[]
        for cmd in commands:
            r=subprocess.run(cmd,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=cmd,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        def execute(name,kind,*,solute=0,start=37256,inco=1,depth='24.0',rate='12.0',second_date='2002-01-05',zone='-30.0',missing=False,refused=False,native_compatibility=False):
            work=target/name;work.mkdir();(work/'reader.swp').write_text("SWIRGFIL = 1\nIRGFIL = 'fixed'\n")
            body=f'IRDATE IRDEPTH IRCONC IRTYPE IRRATE\n2002-01-03 {depth} 20.0 {kind} {rate}\n{second_date} 12.0 10.0 {kind} {rate}\n'
            if kind==2:body+='\nIR_Z = '+zone+'\n'
            if not missing:(work/'fixed.irg').write_text(body)
            r=subprocess.run([str(target/'reader.exe'),str(start),str(solute),str(inco)],cwd=work,capture_output=True,text=True,timeout=15)
            (work/'stdout.log').write_text(r.stdout);(work/'stderr.log').write_text(r.stderr);error=(work/'reader.err').read_text(errors='replace')
            if native_compatibility:assert r.returncode!=0 and not (work/'values.txt').exists() and 'Unsupported fixed subsurface solute irrigation' in r.stderr,(name,r.stdout,r.stderr,error)
            elif refused:assert not (work/'values.txt').exists() and 'ERROR' in error,(name,r.stdout,r.stderr,error)
            else:assert r.returncode==0 and (work/'values.txt').exists(),(name,r.stdout,r.stderr,error)
            data=[line.split() for line in (work/'values.txt').read_text().splitlines()] if not refused else None
            return dict(name=name,returncode=r.returncode,refused=refused,values=data,stdout=r.stdout,stderr=r.stderr,original_error_log=error)
        positive=[];compatibility_refusals=[]
        for kind,zone in ((0,'-30.0'),(1,'-30.0'),(2,'-30.0'),(2,'-10.0 -40.0')):
            for solute in (0,1):
                name='type'+str(kind)+'-'+('range' if ' ' in zone else 'single')+'-solute'+str(solute)
                if a.expect_chemical_type2_refusal and kind==2 and solute:
                    compatibility_refusals.append(execute(name,kind,solute=solute,zone=zone,refused=True,native_compatibility=True));continue
                r=execute(name,kind,solute=solute,zone=zone);ints=list(map(int,r['values'][0]));v=list(map(float,r['values'][1]));assert ints[0]==1 and ints[1]==kind and v[:2]==[37258.,37260.]
                count=2 if kind==2 and ' ' in zone else 1
                assert abs(v[2]-24*.1/count)<1e-12 and abs(v[4]-12*.1*24)<1e-12
                if kind<2:assert abs(v[8]-12*.1*24)<1e-12 and v[9]==0 and v[10]==(20 if solute else 0)
                else:
                    assert ints[2:4]==([2,3] if count==2 else [3,3])
                    assert v[8]==0 and abs(v[9]*v[11]-24*.1)<1e-12 and v[10]==0
                    if solute:assert v[6]==20; r['original_prescribed_subsurface_solute_delivery']='MISSING: IRCONC20 but CIRR0 and QSSDI positive; original CDE lacks QSSDI source'
                positive.append(r)
        late=execute('past-last-cold',1,start=37262,inco=3);assert int(late['values'][0][0])==3
        late_values=list(map(float,late['values'][1]));assert late_values[8:11]==[0,0,0]
        refusals=[execute('missing-file',1,missing=True,refused=True),execute('negative-depth',1,depth='-1.0',refused=True),execute('negative-rate',1,rate='-1.0',refused=True),execute('duration-over-day',1,rate='0.5',refused=True),execute('duplicate-date',1,second_date='2002-01-03',refused=True),execute('unordered-date',1,second_date='2002-01-01',refused=True),execute('invalid-depth-coordinate',2,zone='1.0',refused=True)]
        profiles.append(dict(optimization=opt,original_provider_optimization='O2',compilation=compilation,positive=positive,past_last=late,refusals=refusals,chemical_type2_refusals=compatibility_refusals,generated_source_sha256=sha(source),executable_sha256=sha(target/'reader.exe')))
    solute_source=ref/'build/swap-selected/solute.f90';assert 'qssdi' not in solute_source.read_text(encoding='cp1252').lower()
    result=dict(status='ACTUAL_GUARDED_FIXED_IRRIGATION_FILE_O0_O2_PASS' if a.expect_chemical_type2_refusal else 'ACTUAL_ORIGINAL_FIXED_IRRIGATION_READER_AND_EVENT_O0_O2_PASS',profiles=profiles,production_preimage_sha256=sha(original),driver_sha256=sha(driver),original_CDE_sha256=sha(solute_source),subsurface_chemical='EXPLICIT_NATIVE_REFUSAL; original missing delivery diagnostic stays NOT_QUALIFIED' if a.expect_chemical_type2_refusal else 'ORIGINAL_PRESCRIBED_DELIVERY_MISSING_NOT_QUALIFIED; gate before exposing chemical TYPE2',scope='Complete actually emitted original irrigation owner/native closure; no copied reader/event/chemical implementation, no model/macro execution')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])


if __name__=='__main__':main()
