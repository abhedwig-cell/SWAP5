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

def calendar_attacks(raw,project):
    from extended_drainage import size,selection
    n=project.nodes;r=selection(project)['levels'];nr=6068+10*n+(3*n+3)*r
    prefix=raw[:-size(project)];marker=struct.pack('<4i',1,n,r,nr);positions=[];at=prefix.find(marker)
    while at>=0:
        if prefix[at:at+80]==prefix[at+80:at+160]:positions.append(at)
        at=prefix.find(marker,at+1)
    assert len(positions)==1;at=positions[0];h=struct.unpack_from('<20i',raw,at);result={}
    def change(label,offset,fmt,value,mirror=None,compiled=True):
        wire=bytearray(raw);struct.pack_into('<'+fmt,wire,offset,value)
        if mirror is not None:struct.pack_into('<'+fmt,wire,mirror,value)
        result['calendar-'+label]=(bytes(wire),compiled)
    for index in (0,1,2,3,4,5,6):change('header-'+str(index),at+4*index,'i',h[index]+1,at+80+4*index)
    change('negative-counter',at+28,'i',-1,at+108)
    change('receipt-counter',at+28,'i',h[7]+1,at+108,False)
    change('date-pointer',at+36,'i',0,at+116)
    change('flag',at+48,'i',2,at+128)
    change('header-copy',at+80,'i',99)
    change('value-copy',at+160,'d',12345.)
    change('nonfinite',at+160,'d',float('nan'),at+160+8*nr)
    offset=at+160+8*(nr-1)
    change('negative-period',offset,'d',-1.,offset+8*nr)
    end=at+160+16*nr
    if project.solute:
        change('CDE-shape',end+8,'i',1,end+20)
        change('CDE-value-copy',end+24,'d',12345.)
        change('CDE-negative-initial',end+24,'d',-1.,end+24+8*(18+n))
    if project.age:
        change('AGE-forcing',end+8*(3*n+3),'d',10.)
        change('AGE-total',len(prefix)-44,'d',-1.)
        change('AGE-private-day',len(prefix)-20,'i',-1)
    result['calendar-old-drain-codec']=(b'S5EDR001'+raw[8:],True)
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','profile-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--original-output',action='store_true')
    p.add_argument('--continue-from',type=Path)
    p.add_argument('--positive-only',action='store_true')
    a=p.parse_args();a.output.mkdir();cohort=json.loads((a.profile_root/'RESULT.json').read_text())
    project=m.e.load(Path(cohort['input_root']),original_output=a.original_output);build=Path(cohort['build_root']);meta,case=m.validate_bundle(build,a.reference_work,project)
    source=a.profile_root/'trajectory/accepted-column-1-day-4.zip';digest=m.sha(source)
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),build_sha256=m.sha(build/'BUILD.json'),public_refusals=[],native_refusals=[])
    if a.positive_only:
        assert a.original_output and not a.continue_from
        q['negative_controls_selection']='NOT_SELECTED_IMPACT: unchanged actual native/parser bodies; prior full-cohort controls remain separately retained'
    if a.continue_from:
        previous=json.loads((a.continue_from/'RESULT.json').read_text())
        assert previous['build_sha256']==q['build_sha256'],'Cannot inherit controls from a different actual build'
        q['public_refusals']=copy.deepcopy(previous['public_refusals']);q['native_refusals']=copy.deepcopy(previous['native_refusals'])
        q['positive_native']=copy.deepcopy(previous['positive_native'])
        q['inherited']={'root':str(a.continue_from),'source_commit':previous['source_commit'],
                        'public_labels':[v['label'] for v in q['public_refusals']],
                        'native_labels':[v['label'] for v in q['native_refusals']],
                        'members':{str(path.relative_to(a.continue_from)).replace('\\','/'):m.sha(path) for path in sorted(a.continue_from.rglob('*')) if path.is_file()}}
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    def native(label,origin,receipt,directory):
        directory.parent.mkdir(exist_ok=True)
        m.h.prepare_column(case,directory,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        start=time.monotonic();r=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input='0 -1\n',capture_output=True,text=True,timeout=30)
        (directory/'actual.stdout').write_text(r.stdout,encoding='utf8');(directory/'actual.stderr').write_text(r.stderr,encoding='utf8')
        actual=dict(label=label,returncode=r.returncode,seconds=time.monotonic()-start,no_day_return='HYBRID_DAY_RETURN' not in r.stdout,stderr=r.stderr[:1000])
        (directory/'ACTUAL_NATIVE.json').write_text(json.dumps(actual,indent=2)+'\n',encoding='utf8')
        return actual
    save()
    try:
        with zipfile.ZipFile(source) as z:members={n:z.read(n) for n in z.namelist()}
        accepted=json.loads(members['checkpoint.json']);origin=a.output/'valid-origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        if not a.continue_from:q['positive_native']=native('positive',origin,receipt,a.output/'native-positive/column')
        assert q['positive_native']['returncode']==100
        variants=attacks(members['macro.bin'])
        if a.original_output:variants.update(calendar_attacks(members['macro.bin'],project))
        if a.positive_only:variants={}
        public_done={v['label'] for v in q['public_refusals']};native_done={v['label'] for v in q['native_refusals']}
        for label,(raw,compiled) in variants.items():
            if label in public_done:
                previous_root=a.continue_from/label
                with zipfile.ZipFile(previous_root/'deliberately-forged.zip') as z:assert z.read('macro.bin')==raw
                assert not list((previous_root/'public').rglob('accepted-*.zip')) and not list((previous_root/'public').rglob('donor.stdout'))
                if label in native_done:
                    prior=next(v for v in q['native_refusals'] if v['label']==label)
                    assert prior['returncode']!=100 and prior['no_day_return'] and 'HYBRID_DAY_RETURN' not in (previous_root/'native/column/actual.stdout').read_text()
                    assert (previous_root/'native/column/actual.stderr').read_text()[:1000]==prior['stderr']
                if not compiled or label in native_done:continue
            directory=a.output/label;directory.mkdir();forged=dict(members);forged['macro.bin']=raw;manifest=copy.deepcopy(accepted)
            manifest['files']['macro.bin']=hashlib.sha256(raw).hexdigest();forged['checkpoint.json']=json.dumps(manifest).encode();package=directory/'deliberately-forged.zip'
            with zipfile.ZipFile(package,'w') as z:
                for name,value in forged.items():z.writestr(name,value)
            if label not in public_done:
                try:
                    column=CoupledDailyColumn(build,a.reference_work,directory/'public',project,'extended-controls',origin=package,day=4,adopt_native=True)
                    column.prepare()
                except ValueError as error:
                    assert 'extended drain' in str(error).lower(),str(error)
                    assert not list((directory/'public').rglob('accepted-*.zip')) and not list((directory/'public').rglob('donor.stdout'))
                    q['public_refusals'].append(dict(label=label,error=str(error),before_physical_worker=True,no_publication=True))
                else:raise AssertionError('Public route accepted forged '+label)
            if compiled and label not in native_done:
                unpacked=directory/'origin';copied=m.h.verify_checkpoint(package,4,meta['binding'],unpacked)
                actual=native(label,unpacked,copied,directory/'native/column')
                assert actual['returncode']!=100 and actual['no_day_return'],actual
                assert any(t in actual['stderr'].lower() for t in ('extended drain','nonmacro checkpoint','negative original surface storage or perimeter','original output','original age','original cde','original zero-period')),actual
                q['native_refusals'].append(actual)
            assert m.sha(source)==digest;save()
        q['transactions']=transactions(build,a.reference_work,project,a.profile_root/'trajectory',a.output/'transactions');save()
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--reference-work',str(a.reference_work),'--build-bundle',str(build),'--days','5','--checkpoint-at','5','--restart',str(source),'--restart-day','4','--output',str(a.output/'public-cli')]
        if a.original_output:command.append('--original-output')
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
        q.update(status='ACTUAL_EXTENDED_POSITIVE_NATIVE_CLI_TRANSACTION_PRESERVATION_PASS' if a.positive_only else 'ACTUAL_EXTENDED_NATIVE_PUBLIC_TRANSACTION_CONTROLS_PASS',origin_unchanged=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['public_refusals']),len(q['native_refusals']))

if __name__=='__main__':main()
