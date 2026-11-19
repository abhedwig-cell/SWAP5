"""Actual public, compiled-loader, CLI and transactional drainage controls."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as prior
from age_groundwater_controls import transactions
from daily_coupling import CoupledDailyColumn

m=prior.m;ROOT=prior.ROOT

def attacks(raw):
    length=struct.unpack_from('<i',raw,len(raw)-4)[0];at=len(raw)-length;nv=(length-92)//16
    result={}
    def change(label,offset,fmt,value,mirror=None,compiled=True):
        wire=bytearray(raw);struct.pack_into('<'+fmt,wire,offset,value)
        if mirror is not None:struct.pack_into('<'+fmt,wire,mirror,value)
        result[label]=(bytes(wire),compiled)
    for i,v in enumerate(struct.unpack_from('<8i',raw,at)):change('domain-'+str(i),at+4*i,'i',v+1,at+32+4*i)
    change('domain-copy',at,'i',99)
    change('clock',at+64,'d',-1.)
    change('clock-both',at+64,'d',-1.,at+72)
    change('negative-counter',at+80,'i',-1,at+84)
    change('counter-copy',at+84,'i',-1)
    change('counter-receipt',at+80,'i',struct.unpack_from('<i',raw,at+80)[0]+1,at+84,False)
    for i in (0,2,4,nv-1):
        change('nonfinite-'+str(i),at+88+8*i,'d',float('nan'),at+88+8*(nv+i))
    for i in (2,4):change('negative-'+str(i),at+88+8*i,'d',-1.,at+88+8*(nv+i))
    change('value-copy',at+88,'d',12345.)
    change('stock-receipt',at+104,'d',struct.unpack_from('<d',raw,at+104)[0]+1.,at+104+8*nv,False)
    change('trailer',len(raw)-4,'i',1)
    result.update({'old-codec':(b'S5HUP012'+raw[8:],True),'truncated':(raw[:-1],True),'trailing':(raw+b'x',True)})
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','profile-root','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();cohort=json.loads((a.profile_root/'RESULT.json').read_text())
    project=m.e.load(Path(cohort['input_root']));build=Path(cohort['build_root']);meta,case=m.validate_bundle(build,a.reference_work,project)
    source=a.profile_root/'trajectory/accepted-column-1-day-4.zip';digest=m.sha(source)
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),build_sha256=m.sha(build/'BUILD.json'),public_refusals=[],native_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    def native(label,origin,receipt,directory):
        directory.parent.mkdir(exist_ok=True)
        m.h.prepare_column(case,directory,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        start=time.monotonic();r=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input='0 -1\n',capture_output=True,text=True,timeout=30)
        (directory/'actual.stdout').write_text(r.stdout,encoding='utf8');(directory/'actual.stderr').write_text(r.stderr,encoding='utf8')
        return dict(label=label,returncode=r.returncode,seconds=time.monotonic()-start,no_day_return='HYBRID_DAY_RETURN' not in r.stdout,stderr=r.stderr[:1000])
    save()
    try:
        with zipfile.ZipFile(source) as z:members={n:z.read(n) for n in z.namelist()}
        accepted=json.loads(members['checkpoint.json']);origin=a.output/'valid-origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        q['positive_native']=native('positive',origin,receipt,a.output/'native-positive/column');assert q['positive_native']['returncode']==100
        for label,(raw,compiled) in attacks(members['macro.bin']).items():
            directory=a.output/label;directory.mkdir();forged=dict(members);forged['macro.bin']=raw;manifest=copy.deepcopy(accepted)
            manifest['files']['macro.bin']=hashlib.sha256(raw).hexdigest();forged['checkpoint.json']=json.dumps(manifest).encode();package=directory/'deliberately-forged.zip'
            with zipfile.ZipFile(package,'w') as z:
                for name,value in forged.items():z.writestr(name,value)
            try:
                column=CoupledDailyColumn(build,a.reference_work,directory/'public',project,'extended-controls',origin=package,day=4,adopt_native=True)
                column.prepare()
            except ValueError as error:
                assert 'extended drain' in str(error).lower(),str(error)
                assert not list((directory/'public').rglob('accepted-*.zip')) and not list((directory/'public').rglob('donor.stdout'))
                q['public_refusals'].append(dict(label=label,error=str(error),before_physical_worker=True,no_publication=True))
            else:raise AssertionError('Public route accepted forged '+label)
            if compiled:
                unpacked=directory/'origin';copied=m.h.verify_checkpoint(package,4,meta['binding'],unpacked)
                actual=native(label,unpacked,copied,directory/'native/column')
                assert actual['returncode']!=100 and actual['no_day_return'],actual
                assert any(t in actual['stderr'].lower() for t in ('extended drain','nonmacro checkpoint','negative original surface storage or perimeter')),actual
                q['native_refusals'].append(actual)
            assert m.sha(source)==digest;save()
        q['transactions']=transactions(build,a.reference_work,project,a.profile_root/'trajectory',a.output/'transactions');save()
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--reference-work',str(a.reference_work),'--build-bundle',str(build),'--days','5','--checkpoint-at','5','--restart',str(source),'--restart-day','4','--output',str(a.output/'public-cli')]
        r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=90)
        (a.output/'public-cli.stdout').write_text(r.stdout,encoding='utf8');(a.output/'public-cli.stderr').write_text(r.stderr,encoding='utf8')
        q['public_cli']=dict(command=command,returncode=r.returncode);assert r.returncode==0,r.stderr
        assert m.physical(m.rows(a.output/'public-cli'))==m.physical(m.rows(a.profile_root/'trajectory')[4:5])
        with zipfile.ZipFile(a.output/'public-cli/accepted-column-1-day-5.zip') as cold:
            # Full cohorts need not checkpoint day5; the transaction accepted
            # the same actual day and owns its exact native comparison here.
            with zipfile.ZipFile(a.output/'transactions/external/accepted-column-1-day-5.zip') as warm:
                assert all(cold.read(n)==warm.read(n) for n in ('result.end','macro.bin'))
        assert m.sha(source)==digest
        q.update(status='ACTUAL_EXTENDED_NATIVE_PUBLIC_TRANSACTION_CONTROLS_PASS',origin_unchanged=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['public_refusals']),len(q['native_refusals']))

if __name__=='__main__':main()
