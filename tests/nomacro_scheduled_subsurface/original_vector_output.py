"""Original GNU vector catalog counterexample and exact source-table correction."""
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import time
import original_output_baseline as baseline
import original_binary_output as binary
from original_output_files import records

ROOT=baseline.ROOT
spec=importlib.util.spec_from_file_location('vector_source',ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py')
patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';tt=provider/'ttutil-obj'
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    original=(provider/'swap-selected/swap_csv_output.f90').read_bytes().replace(b'\r\n',b'\n');corrected=patch.source(original)
    combined=binary.patch.source(original)
    for old,new in patch.edits(original):combined=combined.replace(old.encode(),new.encode(),1)
    probe=binary.value_probe(combined)
    anchor=b'      call original_vector_catalog_init()'
    probe=probe.replace(anchor,anchor+b"\n      do i=1,M_v\n       write(*,'(a,i0,a,a,a,a,a,3(i0,a))')'VECTOR_CATALOG|',i,'|',trim(vars_v%name(i)),'|',trim(vars_v%unit(i)),'|',vars_v%conv(i),'|',vars_v%subr(i),'|',vars_v%itzq(i),'|'\n      end do",1)
    variants={'original':original,'corrected':corrected,'combined':combined,'probe':probe}
    q=dict(status='RUNNING',scope='Original vector metadata and output serialization; no physical oracle',original_source_sha256=hashlib.sha256(original).hexdigest(),corrected_source_sha256=hashlib.sha256(corrected).hexdigest(),catalog_rows=patch.catalog(original.decode('cp1252')),provider_objects={p.name:sha(p) for p in objects.glob('*.o')},library_sha256=sha(tt/'libttutil.a'),profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,cwd,label):
        start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=60)
        (cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr)
        return r,dict(returncode=r.returncode,seconds=time.monotonic()-start,stdout=r.stdout,stderr=r.stderr)
    try:
        for opt in ('O0','O2'):
            report=dict(builds={},runs={});q['profiles'][opt]=report;exes={}
            for name,body in variants.items():
                build=a.output/(opt+'-'+name+'-build');build.mkdir();source=build/'swap_csv_output.f90';source.write_bytes(body)
                flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-fbacktrace','-ffp-contract=off','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(tt)]
                r,compile_report=call(['gfortran',*flags,'-c',source],build,'compile');assert r.returncode==0,r.stderr
                exe=build/'component.exe';closure=[build/'swap_csv_output.o' if p.stem.lower()=='swap_csv_output' else p for p in sorted(objects.glob('*.o'))]
                r,link_report=call(['gfortran','-o',exe,*closure,tt/'libttutil.a'],build,'link');assert r.returncode==0,r.stderr
                exes[name]=exe;report['builds'][name]=dict(flags=flags,source_sha256=sha(source),executable_sha256=sha(exe),compile=compile_report,link=link_report)
            folders={}
            for name,variant,fmt,vector in [('original-scalar','original',1,False),('fixed-scalar','corrected',1,False),('original-vector','original',1,True),('fixed-vector','corrected',1,True),('combined-binary','combined',3,True),('probe-binary','probe',3,True)]:
                case=a.output/(opt+'-'+name);baseline.fixture(case,'water-csv3');control=case/'swap.swp';text=control.read_text(encoding='cp1252')
                for key,value in [('SWSOLU',1),('SWCSV',fmt),('TEND','2002-01-04'),('INLIST_CSV',"'GWL,H[1;3],S_CONC[1;3],Q[1;3]'" if vector else "'GWL'")]:text=baseline.assignment(text,key,value)
                text=text.replace(' -10.0 0.0',' -10.0 0.1').replace(' -95.0 0.0',' -95.0 0.1');control.write_text(text,encoding='cp1252')
                r,result=call([exes[variant],'./swap.swp'],case,'run');result['swap_ok']=(case/'swap.ok').exists();result['input_sha256']={p.name:sha(p) for p in case.iterdir() if p.suffix.lower() in ('.swp','.crp','.met','.dra','.bbc','.irg')};report['runs'][name]=result;folders[name]=case;save()
                if name=='original-vector':assert not result['swap_ok'] and 'not known in vars%name' in (case/'swap.err').read_text()
                else:assert r.returncode in (0,100) and result['swap_ok'],(name,r.stderr)
            scalar=records(folders['original-scalar']/'result_output.csv');assert len(scalar)==5 and records(folders['fixed-scalar']/'result_output.csv')==scalar
            lines=report['runs']['probe-binary']['stdout'].splitlines();observed=[line.split('|')[2:7] for line in lines if line.startswith('VECTOR_CATALOG|')]
            assert observed==[list(row) for row in q['catalog_rows']]
            packets=binary.packets(report['runs']['probe-binary']['stdout']);payload=records(folders['combined-binary']/'result_output.bin');probed=records(folders['probe-binary']/'result_output.bin')
            assert len(payload)==len(packets)==5 and payload==probed
            ascii_rows=records(folders['fixed-vector']/'result_output.csv');assert len(ascii_rows)==5
            for packet,raw,line in zip(packets,payload,ascii_rows):
                values=list(map(float,next(csv.reader([line]))[1:]));assert len(values)==len(packet['values'])==7
                assert raw[19:]==struct.pack('<7f',*packet['values'])
                assert all(abs(x-y)<=5.1e-13 for x,y in zip(values,packet['values']))
            report.update(original_vector_refused=True,corrected_58_catalog_records_five_attributes_exact=True,scalar_output_unchanged=True,five_vector_ASCII_and_REAL4_source_values_exact=True,probe_payload_unchanged=True)
            print(opt,'ORIGINAL_VECTOR_CATALOG_COMPONENT_PASS',flush=True);save()
        assert q['provider_objects']=={p.name:sha(p) for p in objects.glob('*.o')} and q['library_sha256']==sha(tt/'libttutil.a')
        q['status']='ORIGINAL_VECTOR_CATALOG_O0_O2_EXACT_TABLE_SCALAR_PRESERVATION_AND_VECTOR_SERIALIZATION_PASS_NOT_ACTIVE'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
