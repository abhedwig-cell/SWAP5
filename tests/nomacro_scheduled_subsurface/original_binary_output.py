"""Real original csv_out lifetime counterexample and exact REAL4 roundtrip."""
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

ROOT=baseline.ROOT
PATCH=ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01'
spec=importlib.util.spec_from_file_location('binary_source',PATCH/'source.py')
patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def allocation_probe(source):
    anchor=b'      else if (swcsv == 3) then ! binary\n         ! datetime'
    assert source.count(anchor)==1
    return source.replace(anchor,b"      else if (swcsv == 3) then ! binary\n         if(.not.allocated(buffer))error stop 'Original csv_out binary buffer is unallocated at dynamic write'\n         ! datetime",1)


def value_probe(source):
    anchor=b'         pos = 0\n';assert source.count(anchor)==1
    source=source.replace(anchor,b"         write(*,'(a,1x,a)')'CSV_BINARY_PACKET',datexti\n"+anchor,1)
    anchor=b'                  buffer(pos) = real(vars_s%value(i))';assert source.count(anchor)==1
    source=source.replace(anchor,b"                  write(*,'(a,1x,i0,1x,es25.17e3)')'CSV_BINARY_VALUE',pos,vars_s%value(i)\n"+anchor,1)
    anchor=b'                  buffer(pos+1:pos+nvars) = real(vars_v%value(i)%val)';assert source.count(anchor)==1
    source=source.replace(anchor,b"                  do j=1,nvars\n                   write(*,'(a,1x,i0,1x,es25.17e3)')'CSV_BINARY_VALUE',pos+j,vars_v%value(i)%val(j)\n                  end do\n"+anchor,1)
    return source


def packets(stdout):
    result=[]
    for line in stdout.splitlines():
        if line.startswith('CSV_BINARY_PACKET '):result.append(dict(date=line.split(maxsplit=1)[1].strip(),values=[]))
        if line.startswith('CSV_BINARY_VALUE '):
            tag,index,value=line.split();assert int(index)==len(result[-1]['values'])+1
            result[-1]['values'].append(float(value))
    return result


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','baseline','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';ttutil=provider/'ttutil-obj'
    original=(provider/'swap-selected/swap_csv_output.f90').read_bytes().replace(b'\r\n',b'\n')
    corrected=patch.source(original);source={'original':original,'allocation-probe':allocation_probe(original),'corrected':corrected,'values-probe':value_probe(corrected)}
    object_hashes={p.name:sha(p) for p in objects.glob('*.o')};library_hash=sha(ttutil/'libttutil.a')
    q=dict(status='RUNNING',scope='Original SWCSV3 local scratch lifetime and output bytes only; not SWAP5activation or scientific equivalence',original_source_sha256=hashlib.sha256(original).hexdigest(),corrected_source_sha256=hashlib.sha256(corrected).hexdigest(),compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],original_objects=object_hashes,ttutil_library_sha256=library_hash,profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,cwd,label,check=True):
        t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=60)
        (cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr)
        if check:assert r.returncode==0,r.stderr
        return r,time.monotonic()-t
    def run(exe,opt,label,swcsv):
        case=a.output/(opt+'-'+label);shutil.copytree(a.baseline/'water-csv3/input',case)
        control=case/'swap.swp';text=control.read_text(encoding='cp1252');text=baseline.assignment(text,'SWCSV',swcsv);text=baseline.assignment(text,'TEND','2002-01-04');control.write_text(text,encoding='cp1252')
        hashes={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
        r,seconds=call([exe,'./swap.swp'],case,'run',False)
        return case,r,dict(returncode=r.returncode,seconds=seconds,swap_ok=(case/'swap.ok').exists(),input_sha256=hashes,stdout=r.stdout,stderr=r.stderr)
    try:
        for opt in ('O0','O2'):
            exes={};report=dict(builds={},runs={});q['profiles'][opt]=report
            for name,body in source.items():
                build=a.output/(opt+'-'+name+'-build');build.mkdir();path=build/'swap_csv_output.f90';path.write_bytes(body)
                flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-fbacktrace','-g','-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(ttutil)]
                _,compile_seconds=call(['gfortran',*flags,'-c',path],build,'compile')
                linked=[build/'swap_csv_output.o' if p.name.lower()=='swap_csv_output.o' else p for p in sorted(objects.glob('*.o'))]
                exe=build/'swap_binary_component.exe';_,link_seconds=call(['gfortran','-o',exe,*linked,ttutil/'libttutil.a'],build,'link');exes[name]=exe
                report['builds'][name]=dict(source_sha256=sha(path),executable_sha256=sha(exe),flags=flags,compile_seconds=compile_seconds,link_seconds=link_seconds)
            for name,variant,mode in [('original-ascii','original',1),('original-binary','original',3),('original-allocation-probe','allocation-probe',3),('corrected-ascii','corrected',1),('corrected-binary','corrected',3),('corrected-values-probe','values-probe',3)]:
                case,r,result=run(exes[variant],opt,name,mode);report['runs'][name]=result;save()
                if name=='original-binary':assert r.returncode not in (0,100) and not result['swap_ok']
                elif name=='original-allocation-probe':assert r.returncode not in (0,100) and 'Original csv_out binary buffer is unallocated at dynamic write' in r.stderr
                else:assert r.returncode in (0,100) and result['swap_ok'],(name,r.stderr)
            def rows(name):return [line for line in (a.output/(opt+'-'+name)/'result_output.csv').read_text(encoding='cp1252').splitlines() if re.match(r'\d{4}-\d{2}-\d{2}',line)]
            ascii_rows=rows('original-ascii');assert len(ascii_rows)==5 and rows('corrected-ascii')==ascii_rows
            observed=packets(report['runs']['corrected-values-probe']['stdout']);assert len(observed)==5
            columns=len(next(csv.reader([ascii_rows[0]])))-1
            assert all(len(packet['values'])==columns for packet in observed)
            size=19+4*columns;count=5;payload=(a.output/(opt+'-corrected-binary')/'result_output.bin').read_bytes()[-size*count:]
            probed=(a.output/(opt+'-corrected-values-probe')/'result_output.bin').read_bytes()[-size*count:];assert payload==probed
            for i,packet in enumerate(observed):
                raw=payload[i*size:(i+1)*size];assert raw[:19].decode('ascii').strip()==packet['date']==next(csv.reader([ascii_rows[i]]))[0].strip()
                assert raw[19:]==struct.pack('<'+'f'*columns,*packet['values'])
            report['roundtrip']=dict(actual_original_API=True,original_unallocated_lifetime_observed=True,corrected_ascii_five_rows_exact=True,real4_values_exact=True,dates_exact=True,probe_did_not_change_payload=True,records=count,columns=columns,record_bytes=size,payload_sha256=hashlib.sha256(payload).hexdigest())
            save();print(opt,'ACTUAL_ORIGINAL_BINARY_LIFETIME_AND_REAL4_ROUNDTRIP_PASS',flush=True)
        assert object_hashes=={p.name:sha(p) for p in objects.glob('*.o')} and sha(ttutil/'libttutil.a')==library_hash
        q['status']='ORIGINAL_BINARY_SCRATCH_LIFETIME_CORRECTION_O0_O2_REAL4_ROUNDTRIP_PASS_NOT_ACTIVE_IN_SWAP5'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
