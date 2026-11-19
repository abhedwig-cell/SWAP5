"""Independent archive observations, native payloads and actual compiler custody.

No production adapter imports and no model executions. Temporary extraction
only makes original archive bytes available to the independent file readers.
"""
from contextlib import contextmanager
import ast
import copy
from datetime import date
import hashlib
import io
import json
from pathlib import Path
import tempfile
import subprocess
import zipfile
from calendar_publisher import publisher_equivalence

import calendar_forensics as science
import extended_evidence as prior
from extended_forensics import require


@contextmanager
def extracted(path):
    record=json.loads(path.with_suffix('.json').read_text(encoding='utf8'))
    with prior.archive(path,record) as z,tempfile.TemporaryDirectory(prefix='calendar-raw-') as temporary:
        for name in z.namelist():
            require('\\' not in name and not name.startswith('/') and ':' not in name and all(p not in ('','..','.') for p in name.split('/')),'Unsafe raw archive path')
        z.extractall(temporary)
        yield Path(temporary),z


def capsule(root,prefix='source'):
    directory=root/prefix;q=json.loads((directory/'RESULT.json').read_text())
    raw=(directory/q['archive']).read_bytes()
    require(prior.digest(raw)==q['sha256'] and len(raw)==q['bytes'],'Actual phase source archive changed')
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        expected={name for name,item in q['members'].items() if item.get('checkout')!='ABSENT'}
        require(set(z.namelist())==expected,'Actual phase source members changed')
        for name in expected:
            body=z.read(name);item=q['members'][name]
            require(prior.digest(body)==item['sha256'] and len(body)==item['bytes'],'Actual phase source changed: '+name)
    return q


def source_binding(build,cap,provider,phase=None):
    if phase is not None:
        # This is an explicit Git-to-compiler hash proof for the earlier short
        # phase, not an earlier filesystem snapshot relabelled as current.
        repository=Path(__file__).resolve().parents[2]
        git=lambda *args:subprocess.check_output(['git',*args],cwd=repository)
        full='6d931e66afb653a7930cbb4e3fa56a623b01788d'
        changed=git('diff','--name-only',phase,full,'--','app','src','tools/solute','tools/vq','reference/swap-4.3.1').decode().splitlines()
        require(changed==['app/hybrid_water/extended_drainage.py','app/hybrid_water/extended_output_receipt.py'],'Earlier short phase has another affected dependency')
        derived=copy.deepcopy(cap)
        for path,key in [('app/hybrid_water/extended_drainage.py','source_sha256'),('app/hybrid_water/extended_output_receipt.py','output_receipt_renderer_sha256')]:
            earlier=git('show',phase+':'+path);later=git('show',full+':'+path)
            oldnodes={node.name:node for node in ast.parse(earlier).body if isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef))}
            newnodes={node.name:node for node in ast.parse(later).body if isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef))}
            excluded={'describe','validate_candidate'} if path.endswith('/extended_drainage.py') else set()
            require(all(name in newnodes and ast.dump(node)==ast.dump(newnodes[name]) for name,node in oldnodes.items() if name not in excluded),'Earlier short physical renderer/function changed')
            require(set(newnodes)-set(oldnodes)<= {'validate_candidate'},'Unexpected short/full function addition')
            expected=build['identity']['extended_drainage'][key]
            require(expected in {prior.digest(earlier),prior.digest(earlier.replace(b'\n',b'\r\n'))},'Earlier short compiler source hash differs from its exact Git byte/line-ending identity')
            derived['members'][path]['sha256']=expected
        # Only the two explicitly derived source roles enter this projection;
        # the actual BUILD, archive and phase capsules are never modified.
        cap=derived
    prior.source_binding(build,cap,provider)
    identity=build['identity'];selected=identity['original_output']
    for key,name in [('source_sha256','original_output.py'),('calendar_owner_sha256','age_output_calendar.py'),('clock_owner_sha256','age_output_clock.py')]:
        require(selected[key]==cap['members']['app/hybrid_water/'+name]['lf_normalized_sha256'],'Actual LF-defined calendar source binding changed: '+name)
    require(identity['extended_drainage']['output_receipt_renderer_sha256']==cap['members']['app/hybrid_water/extended_output_receipt.py']['sha256'],'Actual read-only calendar receipt source changed')
    for key,path in [('receipt_provider_sha256','src/process/mod_original_output_receipt.f90'),('cde_output_state_sha256','app/hybrid_water/original_cde_output_state.f90'),('vector_catalog_correction_sha256','reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py'),('binary_correction_sha256','reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py')]:
        if selected[key] is not None:require(selected[key]==cap['members'][path]['lf_normalized_sha256'],'Actual original output provider binding changed: '+path)


def compiled(z,prefix,build,opt):
    prior.build_files(z,prefix,build)
    require(json.loads(z.read(prefix+'BUILD.json'))==build,'Actual executed and retained compiler identity differs')
    for key in ('donor_flags','kernel_flags'):
        require({'-'+opt,'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][key]),'Original separate operation arithmetic changed')
    require(build['identity']['extended_drainage']['codec']=='S5EDO001','Actual calendar codec changed')


def period(root,z,prefix,opt,days):
    directory=root/prefix;buildroot=root/(prefix+'-build')
    q=json.loads((directory/'RESULT.json').read_text());build=json.loads((buildroot/'BUILD.json').read_text())
    require(q['parameters']['days']==days and q['parameters']['optimization']==opt,'Actual calendar period/optimization differs')
    compiled(z,prefix+'-build/',build,opt)
    result=science.audit_root(directory,buildroot)
    require(result['actual_days']==days,'Actual calendar period censored')
    require(build['identity']['original_output']['kind'] in ('water','cde'),'Unqualified AGE composed into calendar admission')
    return result,build,prior.lines((directory/'trajectory/daily.jsonl').read_bytes())


def controls(root,profile,build,data,cap,positive=False):
    base=root/profile;control=base/('positive-controls' if positive else 'controls-v2' if (base/'controls-v2').is_dir() else 'controls')
    q=json.loads((control/'RESULT.json').read_text());origin=base/'trajectory/accepted-column-1-day-4.zip'
    original,parts=prior.package(origin.read_bytes());dz=science.geometry((base/'input/swap.swp').read_text(encoding='cp1252'))
    selected=science.selected_input(base/'input/swap.swp')
    require(q['build_sha256']==prior.digest((root/(profile+'-build')/'BUILD.json').read_bytes()),'Actual controls used another compiler bundle')
    require(original['binding']==build['binding'] and original['receipt']==data[3],'Actual control origin differs')
    inherited=control.parent/'controls'
    def location(label,native=False):
        path=control/label
        if not (path/('native/column/actual.stdout' if native else 'deliberately-forged.zip')).is_file():path=inherited/label
        return path
    if 'inherited' in q:
        for name,digest in q['inherited']['members'].items():require(prior.digest((inherited/name).read_bytes())==digest,'Inherited original failed/control observation was overwritten')
    require(q['positive_native']['returncode']==100 and 'HYBRID_READY ' in ((inherited if 'inherited' in q else control)/'native-positive/column/actual.stdout').read_text(),'Actual valid compiled origin refused')
    public={item['label'] for item in q['public_refusals']};native={item['label'] for item in q['native_refusals']}
    n,r=build['identity']['extended_drainage']['domain'][1:3];nv=11+3*r+r*n
    expected={*('domain-'+str(i) for i in range(8)),'domain-copy','clock','clock-both','negative-counter','counter-copy','counter-receipt',*('nonfinite-'+str(i) for i in (0,2,4,nv-1)),'negative-2','negative-4','value-copy','stock-receipt','trailer','old-codec','truncated','trailing'}
    expected|={*('calendar-header-'+str(i) for i in range(7)),*('calendar-'+name for name in ('negative-counter','receipt-counter','date-pointer','flag','header-copy','value-copy','nonfinite','negative-period','old-drain-codec'))}
    if selected['kind']=='cde':expected|={*('calendar-'+name for name in ('CDE-shape','CDE-value-copy','CDE-negative-initial'))}
    require(public==(set() if positive else expected) and native==(set() if positive else expected-{'counter-receipt','stock-receipt','calendar-receipt-counter'}),'Actual calendar negative denominator changed')
    require(len(q['public_refusals'])==len(public) and len(q['native_refusals'])==len(native),'Duplicate actual calendar refusal label')
    for item in q['public_refusals']:
        label=item['label'];path=location(label);meta,forged=prior.package((path/'deliberately-forged.zip').read_bytes())
        require(meta['binding']==original['binding'] and meta['receipt']==original['receipt'] and forged['result.end']==parts['result.end'] and forged['macro.bin']!=parts['macro.bin'],'Actual forged control changed its declared context')
        require(not list((path/'public').rglob('donor.stdout')) and not list((path/'public').rglob('accepted-*.zip')),'Invalid public control entered worker/publication')
        try:science.checkpoint(path/'deliberately-forged.zip',build,data[3],selected,dz)
        except ValueError:pass
        else:raise ValueError('Independent reader accepted actual calendar mutant '+label)
        if label in native:
            nativepath=location(label,True)/'native/column'
            require((nativepath/'macro-origin.bin').read_bytes()==forged['macro.bin'],'Actual compiled loader received another mutant')
            require('ERROR STOP' in (nativepath/'actual.stderr').read_text() and 'HYBRID_DAY_RETURN ' not in (nativepath/'actual.stdout').read_text(),'Actual compiled loader did not refuse calendar mutant')
    require(all(item['returncode']!=100 and item['no_day_return'] is True for item in q['native_refusals']),'Actual native refusal receipt differs')
    require(q['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True),'Actual transaction assertions omitted')
    proposals=[]
    for folder,day in [('external/trial-1',5),('external/trial-2',5),('recovered/trial-1',6)]:
        directory=control/'transactions'/folder;path=directory/f'accepted-column-1-day-{day}.zip';meta,payload=prior.package(path.read_bytes());rows=[meta['receipt']]
        require(prior.physical(rows)==prior.physical(data[day-1:day]),'Actual transaction changed physical day')
        science.inventory(rows);science.observed((directory/'original/donor.stdout').read_bytes(),rows,build)
        science.checkpoint(path,build,rows[0],selected,dz);proposals.append((meta,payload))
    require(proposals[0]==proposals[1],'Actual rejected/discarded proposal failed exact replay')
    published,payload=prior.package((control/'transactions/external/accepted-column-1-day-5.zip').read_bytes())
    external=dict(version=1,source_sha256=cap['members']['app/hybrid_water/daily_coupling.py']['sha256'],coupling_id='original-output',forcing='original-project')
    require(published['binding']=={**build['binding'],'external_daily':external} and payload==proposals[1][1],'Actual accepted ownership/native differs')
    base_day=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    coupling=dict(id='original-output',revision=1,origin_revision=0,origin_sha256=prior.digest(origin.read_bytes()),origin_day=4,window_day1900=[base_day+4,base_day+5],forcing='original-project')
    require(published['receipt']=={**proposals[1][0]['receipt'],'coupling':coupling} and not (control/'transactions/recovered/accepted-column-1-day-6.zip').exists(),'Actual accept/recovery publication differs')
    rows=prior.lines((control/'public-cli/daily.jsonl').read_bytes())
    require(q['public_cli']['returncode']==0 and prior.physical(rows)==prior.physical(data[4:5]),'Actual public CLI differs')
    science.inventory(rows);science.observed((control/'public-cli/original/donor.stdout').read_bytes(),rows,build)
    path=control/'public-cli/accepted-column-1-day-5.zip';science.checkpoint(path,build,rows[0],selected,dz)
    require(prior.package(path.read_bytes())[1]==payload,'Actual CLI/native accepted payload differs')
    return dict(actual_public_refusals=len(public),actual_compiled_refusals=len(native),actual_cli_contexts=1,actual_transaction_contexts=1)


def differences(left,right,prefix=''):
    if isinstance(left,dict) and isinstance(right,dict):
        require(set(left)==set(right),'Actual postimage compiler identity keys differ')
        return [path for key in left for path in differences(left[key],right[key],prefix+'.'+key if prefix else key)]
    return [] if left==right else [prefix]


def postimage(root,oldroot,prefix,oldprefix,current,before,rows,oldrows):
    now=root/(prefix+'-build');old=oldroot/(oldprefix+'-build')
    require({p.name:p.read_bytes() for p in now.glob('*.f90')}=={p.name:p.read_bytes() for p in old.glob('*.f90')},'Actual current generated Fortran differs')
    require(current['inputs']==before['inputs'] and current['project']==before['project'],'Actual current project/input differs')
    changed=differences(before['identity'],current['identity'])
    require(set(changed)<={'host','extended_drainage.source_sha256','restart_publisher.library_sha256'},'Actual current physical/provider/compiler dependency changed')
    pe=None
    if 'restart_publisher.library_sha256' in changed:
        for directory,build in ((now,current),(old,before)):
            require(prior.digest((directory/'restart_publish.dll').read_bytes())==build['identity']['restart_publisher']['library_sha256'],'Actual PE publisher identity differs')
        pe=publisher_equivalence(old/'restart_publish.dll',now/'restart_publish.dll')
    require(prior.physical(rows)==prior.physical(oldrows[:35]),'Actual current physical prefix changed')
    for day in (2,4,14,17,30,35):
        require(prior.package((root/prefix/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1]==prior.package((oldroot/oldprefix/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1],'Actual current native prefix changed')
    return dict(actual_days=35,exact_native_days=[2,4,14,17,30,35],changed_source_roles=changed,publisher=pe)


def compatibility(root,z,opt,proof):
    report={}
    with zipfile.ZipFile(proof/f'EXTENDED_DRAINAGE_WINDOWS_{opt}_RAW_ARCHIVE.zip') as old:
        for case in ('water','automatic'):
            prefix='compatibility-'+case
            before=json.loads(old.read(case+'-build/BUILD.json'));current=json.loads(z.read(prefix+'-build/BUILD.json'))
            prior.build_files(z,prefix+'-build/',current)
            expected={name[len(case+'-build/'):]:old.read(name) for name in old.namelist() if name.startswith(case+'-build/') and name.endswith('.f90')}
            require(expected=={p.name:p.read_bytes() for p in (root/(prefix+'-build')).glob('*.f90')},'Actual compatibility generated Fortran differs')
            require(current['inputs']==before['inputs'] and current['identity']['kernel_sources']==before['identity']['kernel_sources'],'Actual compatibility input/kernel changed')
            rows=prior.lines(z.read(prefix+'/trajectory/daily.jsonl'));before_rows=prior.lines(old.read(case+'/trajectory/daily.jsonl'))
            require(len(rows)==5 and prior.physical(rows)==prior.physical(before_rows[:5]),'Actual compatibility physical prefix changed')
            science.inventory(rows);science.observed(z.read(prefix+'/trajectory/original/donor.stdout'),rows,current)
            for day in (2,4):require(prior.package(z.read(prefix+f'/trajectory/accepted-column-1-day-{day}.zip'))[1]==prior.package(old.read(case+f'/trajectory/accepted-column-1-day-{day}.zip'))[1],'Actual compatibility native differs')
            report[case]=dict(actual_days=5,exact_native_days=[2,4])
    q=json.loads(z.read('named-seam/RESULT.json'))
    require(q['actual_days']==2 and q['full_periods_repeated']==0,'Actual named seam period differs')
    require(prior.package(z.read('named-seam/cold/accepted-column-1-day-2.zip'))[1]==prior.package(z.read('named-seam/warm-endpoint/accepted-column-1-day-2.zip'))[1],'Actual named seam native replay differs')
    report['named']=dict(actual_days=2,exact_native_replay=True)
    return report


def windows(path,opt):
    sourcepath=path.with_name('EXTENDED_DRAINAGE_CALENDAR_WINDOWS_SOURCE_RAW_ARCHIVE.zip')
    with extracted(sourcepath) as (sources,_):
        cap=capsule(sources);fullcap=capsule(sources,'full-source')
        provider=json.loads((sources/'provider-PREPARED.json').read_text())
    reports={}
    with extracted(path) as (root,z):
        for label in ('water','cde'):
            oldprefix='full-'+label;prefix='current-'+label
            full,before,oldrows=period(root,z,oldprefix,opt,1096);source_binding(before,fullcap,provider)
            full['controls']=controls(root,oldprefix,before,oldrows,fullcap)
            current,build,rows=period(root,z,prefix,opt,35);source_binding(build,cap,provider)
            current['postimage']=postimage(root,root,prefix,oldprefix,build,before,rows,oldrows)
            current['controls']=controls(root,prefix,build,rows,cap,positive=True)
            reports[label]=dict(full=full,current=current)
        for prefix,days in [('limit',2),('format0',5),('format0-terminal',5),('short-cde',35),('short-subdaily',35),('short-monthly',35),('short-combined',35),('short-perstep',5)]:
            reports[prefix],build,_=period(root,z,prefix,opt,days)
            selectedcap=cap if build['identity']['host']==cap['members']['app/hybrid_water/daily_host.py']['sha256'] else fullcap
            phase=json.loads((root/prefix/'RESULT.json').read_text())['source'] if prefix.startswith('short-') else None
            source_binding(build,selectedcap,provider,phase=phase)
        reports['nonselected']=compatibility(root,z,opt,path.parent)
    return reports


def ubuntu(fullpath,currentpath,opt):
    reports={}
    for path in (fullpath,currentpath):
        record=json.loads(path.with_suffix('.json').read_text())
        require(record['repacked'] is False,'Original Ubuntu artifact repacked')
    with extracted(fullpath) as (oldroot,oldz),extracted(currentpath) as (root,z):
        cap=capsule(root);fullcap=capsule(oldroot)
        provider=json.loads((root/'provider-PREPARED.json').read_text());oldprovider=json.loads((oldroot/'provider-PREPARED.json').read_text())
        for label in ('water','cde'):
            full,before,oldrows=period(oldroot,oldz,label,opt,1096);source_binding(before,fullcap,oldprovider)
            full['controls']=controls(oldroot,label,before,oldrows,fullcap)
            current,build,rows=period(root,z,label,opt,35);source_binding(build,cap,provider)
            current['postimage']=postimage(root,oldroot,label,label,build,before,rows,oldrows)
            current['controls']=controls(root,label,build,rows,cap,positive=True)
            reports[label]=dict(full=full,current=current)
        failure=json.loads((oldroot/'age/RESULT.json').read_text())
        require(failure['status']=='FAILED' and len(prior.lines((oldroot/'age/trajectory/daily.jsonl').read_bytes()))==1,'Retained whole-workflow AGE failure censored')
    return reports


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('archive',type=Path);p.add_argument('--current',type=Path);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();report=ubuntu(a.archive,a.current,a.optimization) if a.current else windows(a.archive,a.optimization)
    a.output.write_text(json.dumps(dict(status='INDEPENDENT_CALENDAR_ARCHIVE_BUILD_INPUT_OBSERVATION_NATIVE_CONTROL_PASS',reports=report,model_executions=0,public_admission=False),indent=2)+'\n')
    print('INDEPENDENT_CALENDAR_ARCHIVE_PASS',a.optimization)
