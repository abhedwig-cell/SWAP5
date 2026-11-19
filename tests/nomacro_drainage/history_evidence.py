"""Independent actual history archive/native/compiler/transaction observations.

No production imports or model executions. The control audit derives from the
frozen predecessor95f784d54, extended with explicit history payloads and actual
reused-build custody. Earlier scientific readers remain unchanged.
"""
from datetime import date
import json
from pathlib import Path
import zipfile
import history_forensics as science
import extended_evidence as prior
from extended_forensics import require
from calendar_evidence import extracted,capsule,differences
from calendar_publisher import publisher_equivalence


def controls(root,profile,build,data,cap,positive=False,compiled_prefix=None,control_name=None):
    base=root/profile;control=base/(control_name or ('positive-controls' if positive else 'controls-v2' if (base/'controls-v2').is_dir() else 'controls'))
    q=json.loads((control/'RESULT.json').read_text());require(q['status']==('ACTUAL_EXTENDED_POSITIVE_NATIVE_CLI_TRANSACTION_PRESERVATION_PASS' if positive else 'ACTUAL_EXTENDED_NATIVE_PUBLIC_TRANSACTION_CONTROLS_PASS'),'Incomplete actual history controls');origin=base/'trajectory/accepted-column-1-day-4.zip'
    original,parts=prior.package(origin.read_bytes());dz=science.geometry((base/'input/swap.swp').read_text(encoding='cp1252'))
    selected=science.selected_input(base/'input/swap.swp')
    require(q['build_sha256']==prior.digest((root/(compiled_prefix or profile+'-build')/'BUILD.json').read_bytes()),'Actual controls used another compiler bundle')
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
    expected|={*('history-'+where+'-domain-'+str(index) for where in ('physical','calendar') for index in range(5)),*('history-'+where+'-copy' for where in ('physical','calendar'))}
    expected|={*('history-nonfinite-'+str(index) for index in (0,n,2*n,3*n+1,4*n+2,5*n+2,5*n+3)),*('history-negative-'+str(index) for index in (n,2*n,3*n+1,4*n+2,5*n+3)),'history-head-receipt','history-groundwater-receipt','history-stock-receipt','history-weighted-theta','history-old-calendar-codec'}
    require(public==(set() if positive else expected) and native==(set() if positive else expected-{'counter-receipt','stock-receipt','calendar-receipt-counter','history-head-receipt','history-groundwater-receipt'}),'Actual history negative denominator changed')
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


def source_binding(build,cap,provider):
    prior.source_binding(build,cap,provider)
    identity=build['identity'];selected=identity['original_output']
    for key,path in [('source_sha256','app/hybrid_water/original_output_hysteresis.py'),('ordinary_owner_sha256','app/hybrid_water/original_output.py'),('domain_source_sha256','app/hybrid_water/original_output_hysteresis_domain.f90'),('calendar_owner_sha256','app/hybrid_water/age_output_calendar.py'),('clock_owner_sha256','app/hybrid_water/age_output_clock.py'),('receipt_provider_sha256','src/process/mod_original_output_receipt.f90'),('cde_output_state_sha256','app/hybrid_water/original_cde_output_state.f90'),('vector_catalog_correction_sha256','reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py'),('binary_correction_sha256','reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py')]:
        if selected[key] is not None:require(selected[key]==cap['members'][path]['lf_normalized_sha256'],'Actual history output source binding differs: '+path)
    require(selected['swhyst'] in (1,2) and selected['original_hysteresis_sha256']=='e6f5e4744e0a393a9e890abc0aaedaead91fe0128d84c9a7f8864b381c4c2fb8','Actual original hysteresis provider changed')
    require(identity['extended_drainage']['output_receipt_renderer_sha256']==cap['members']['app/hybrid_water/extended_output_receipt.py']['sha256'],'Actual composed history receipt renderer changed')
    require(identity['restart_publisher']['source_sha256']==cap['members']['app/support/restart_publish.c']['sha256'],'Actual native publisher C source changed')


def compiled(z,prefix,build,opt):
    prior.build_files(z,prefix,build)
    require(json.loads(z.read(prefix+'BUILD.json'))==build,'Executed/retained history compiler identity differs')
    require(build['identity']['extended_drainage']['codec']=='S5EDH001','Actual history native codec differs')
    for key in ('donor_flags','kernel_flags'):
        require({'-'+opt,'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][key]),'Actual history arithmetic flags differ')
    libraries=[prefix+name for name in ('restart_publish.dll','restart_publish.so') if prefix+name in z.namelist()]
    require(len(libraries)==1 and prior.digest(z.read(libraries[0]))==build['identity']['restart_publisher']['library_sha256'],'Actual history publisher executable differs')


def period(root,z,prefix,opt,days,compiled_prefix=None):
    compiled_prefix=compiled_prefix or prefix+'-build';directory=root/prefix
    q=json.loads((directory/'RESULT.json').read_text());build=json.loads((root/compiled_prefix/'BUILD.json').read_text())
    require(q['parameters']['days']==days and q['parameters']['optimization']==opt,'Actual history period/optimization changed')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['public_admission'] is False,'Actual history producer promoted whole scope')
    compiled(z,compiled_prefix+'/',build,opt)
    result=science.audit_root(directory,root/compiled_prefix)
    rows=prior.lines((directory/'trajectory/daily.jsonl').read_bytes());require(rows[0]['day']==1,'Actual history warm period origin censored')
    return result,build,rows


def postimage(root,prefix,oldprefix,build,before,rows,oldrows,compiled_prefix,old_compiled_prefix):
    now=root/compiled_prefix;old=root/old_compiled_prefix
    require({p.name:p.read_bytes() for p in now.glob('*.f90')}=={p.name:p.read_bytes() for p in old.glob('*.f90')},'Actual current history generated Fortran changed')
    require(build['inputs']==before['inputs'] and build['project']==before['project'],'Actual current history input/project changed')
    changed=differences(before['identity'],build['identity'])
    require(set(changed)<={'experimental_input_adapter','restart_publisher.library_sha256'},'Actual current history physical/provider/compiler dependency changed')
    pe=publisher_equivalence(old/'restart_publish.dll',now/'restart_publish.dll') if 'restart_publisher.library_sha256' in changed else None
    require(len(rows)==6 and prior.physical(rows)==prior.physical(oldrows[:6]),'Actual current history physical prefix changed')
    for day in (2,4):require(prior.package((root/prefix/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1]==prior.package((root/oldprefix/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1],'Actual current history complete native changed')
    # The prior full cohort independently executes/replays original day6 in
    # its transaction control, even though full warm cuts need not include6.
    require(prior.package((root/prefix/'trajectory/accepted-column-1-day-6.zip').read_bytes())[1]==prior.package((root/oldprefix/'positive-controls/transactions/recovered/trial-1/accepted-column-1-day-6.zip').read_bytes())[1],'Actual current day6 differs from prior independently recovered native')
    return dict(actual_days=6,exact_prior_native_days=[2,4,6],changed_source_roles=changed,publisher=pe)


def nonselected(root,z,opt,proof,aliases):
    reports={}
    with zipfile.ZipFile(proof/f'EXTENDED_DRAINAGE_CALENDAR_WINDOWS_{opt}_RAW_ARCHIVE.zip') as old:
        for case,label in [('water','water'),('automatic','cde')]:
            prefix='off-'+case;oldprefix='current-'+label;buildprefix=aliases[prefix]['actual_build_prefix']
            build=json.loads(z.read(buildprefix+'/BUILD.json'));before=json.loads(old.read(oldprefix+'-build/BUILD.json'))
            prior.build_files(z,buildprefix+'/',build)
            expected={name[len(oldprefix+'-build/'):]:old.read(name) for name in old.namelist() if name.startswith(oldprefix+'-build/') and '/' not in name[len(oldprefix+'-build/'):] and name.endswith('.f90')}
            require(expected=={p.name:p.read_bytes() for p in (root/buildprefix).glob('*.f90')},'Actual history-off generated Fortran changed')
            require(build['inputs']==before['inputs'] and build['project']==before['project'],'Actual history-off input/project changed')
            changed=differences(before['identity'],build['identity'])
            require(set(changed)<={'extended_drainage.source_sha256','extended_drainage.output_receipt_renderer_sha256','original_output.source_sha256','restart_publisher.library_sha256'},'Actual history-off compiler/provider changed')
            if 'restart_publisher.library_sha256' in changed:
                copied=root/buildprefix/'prior-admitted-publisher.dll'
                require(copied.read_bytes()==old.read(oldprefix+'-build/restart_publish.dll'),'Actual compared prior publisher bytes differ')
                publisher_equivalence(copied,root/buildprefix/'restart_publish.dll')
            rows=prior.lines(z.read(prefix+'/trajectory/daily.jsonl'));previous=prior.lines(old.read(oldprefix+'/trajectory/daily.jsonl'))
            require(len(rows)==5 and prior.physical(rows)==prior.physical(previous[:5]),'Actual history-off physical prefix changed')
            for day in (2,4):require(prior.package(z.read(prefix+f'/trajectory/accepted-column-1-day-{day}.zip'))[1]==prior.package(old.read(oldprefix+f'/trajectory/accepted-column-1-day-{day}.zip'))[1],'Actual history-off complete native changed')
            import calendar_forensics as earlier
            reports[case]=earlier.audit_root(root/prefix,root/buildprefix)
    return reports


def windows(path,opt):
    with extracted(path.with_name('EXTENDED_DRAINAGE_HISTORY_WINDOWS_SOURCE_RAW_ARCHIVE.zip')) as (sources,_):
        cap=capsule(sources);fullcap=capsule(sources,'full-source');provider=json.loads((sources/'provider-PREPARED.json').read_text())
    reports={}
    with extracted(path) as (root,z):
        aliases=json.loads(z.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']
        expected={'full-water','full-cde','current-water','current-cde',*('short-'+case+'-h'+str(mode) for case in ('water','automatic') for mode in (1,2)),'off-water','off-automatic','output-subdaily','output-perstep'}
        require(set(aliases)==expected,'Actual history profile/build custody inventory changed')
        for prefix,item in aliases.items():
            q=json.loads(z.read(prefix+'/RESULT.json'));raw=z.read(item['actual_build_prefix']+'/BUILD.json')
            require(prior.digest(raw)==item['actual_build_sha256']==q['trajectory']['build_sha256'] and item['producer_source']==q['source'],'Reused actual history compiler phase rebound')
        for label in ('water','cde'):
            full='full-'+label;current='current-'+label;oldbuild=aliases[full]['actual_build_prefix'];newbuild=aliases[current]['actual_build_prefix']
            before_report,before,previous=period(root,z,full,opt,1096,oldbuild);source_binding(before,fullcap,provider)
            before_report['controls']=controls(root,full,before,previous,fullcap,positive=True,compiled_prefix=oldbuild)
            now_report,build,rows=period(root,z,current,opt,6,newbuild);source_binding(build,cap,provider)
            now_report['controls']=controls(root,current,build,rows,cap,positive=True,compiled_prefix=newbuild)
            now_report['postimage']=postimage(root,current,full,build,before,rows,previous,newbuild,oldbuild)
            reports[label]=dict(full=before_report,current=now_report)
        for case in ('water','automatic'):
            for mode in (1,2):
                prefix=f'short-{case}-h{mode}';buildprefix=aliases[prefix]['actual_build_prefix'];report,build,rows=period(root,z,prefix,opt,35,buildprefix);source_binding(build,fullcap,provider)
                control=root/prefix/'controls-v1'
                if control.is_dir():
                    # The original controls directory is retained under its
                    # actual name. No archive or RESULT record is rewritten.
                    report['controls']=controls(root,prefix,build,rows,fullcap,compiled_prefix=buildprefix,control_name='controls-v1')
                reports[prefix]=report
        for prefix,days in [('output-subdaily',35),('output-perstep',5)]:
            reports[prefix],build,_=period(root,z,prefix,opt,days,aliases[prefix]['actual_build_prefix']);source_binding(build,fullcap,provider)
        reports['history-off']=nonselected(root,z,opt,path.parent,aliases)
    return reports


def ubuntu(path,opt):
    record=json.loads(path.with_suffix('.json').read_text());require(record['repacked'] is False and record['origin_job_conclusion']=='success','Original Ubuntu history artifact repacked or not terminal success')
    with extracted(path) as (root,z):
        cap=capsule(root);provider=json.loads((root/'provider-PREPARED.json').read_text());reports={}
        for label in ('water','cde'):
            report,build,rows=period(root,z,label,opt,1096);source_binding(build,cap,provider)
            report['controls']=controls(root,label,build,rows,cap);reports[label]=report
    return reports


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();reports=(windows if a.platform=='Windows' else ubuntu)(a.archive,a.optimization)
    with a.output.open('x') as stream:json.dump(dict(status='INDEPENDENT_ACTUAL_HISTORY_ARCHIVE_SOURCE_COMPILER_NATIVE_OBSERVATION_CONTROLS_PASS',reports=reports,model_executions=0,public_admission=False),stream,indent=2)
    print('INDEPENDENT_HISTORY_ARCHIVE_PASS',a.platform,a.optimization)
