"""Actual generic original surface events: fresh builds, exact state and transactions."""
import argparse,contextlib,csv,dataclasses,json,math,re,shutil,subprocess,sys,time,zipfile,threading,traceback
from datetime import date,timedelta
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OWNED_OUTPUT=None
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
import irrigation_forcing as ir
from daily_coupling import CoupledDailyColumn,validate_bundle,SURFACE_IRRIGATION_FORCING
from prepare_saltfarm import prepare as saltfarm


def physical(row):
    return {k:v for k,v in row.items() if k not in ('column','revision','coupling','committed','candidate_only')}


def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}


def event(day,solute):
    return (2.0,1.0 if solute else 0.0,5.0,True) if day in (4,140,201,531,800,1100) else (0.0,0.0,0.0,False)


def set_value(path,name,value):
    text=path.read_text(encoding='cp1252')
    text,count=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)[^\s!]+',lambda m:m[1]+str(value),text)
    assert count==1,(path,name);path.write_text(text,encoding='cp1252')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--full-period',action='store_true');args=p.parse_args()
    global OWNED_OUTPUT
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);OWNED_OUTPUT=out;ref=out/'provider'
    reports=[];events=[];refusals=[]
    def save():
        (out/'PROFILES.json').write_text(json.dumps(reports,indent=2)+'\n')
        (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
        (out/'REFUSALS.json').write_text(json.dumps(refusals,indent=2)+'\n')
    def call(label,arguments,*,fail=False,absent=None):
        started=time.monotonic();cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),*map(str,arguments)]
        result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=300)
        (out/(label+'.log')).write_text(result.stdout+result.stderr)
        events.append(dict(label=label,command=cmd,returncode=result.returncode,seconds=time.monotonic()-started));save()
        assert (result.returncode!=0)==fail,(label,result.stdout,result.stderr)
        if absent is not None:assert not absent.exists()
        print(label,'REFUSED' if fail else 'PASS',flush=True)
    def reject(label,fn,absent=None):
        try:fn()
        except (ValueError,TypeError,RuntimeError) as error:
            if absent is not None:assert not absent.exists(),label
            refusals.append(dict(label=label,error=str(error)));save();return
        raise AssertionError(label+' accepted invalid input')
    call('prepare',['--no-macro-release','--prepare-sources','--reference-work',ref])
    cases=[]
    for key,solute in [('water-hupsel',False),('solute-salt',True)]:
        case=out/('input-'+key)
        if solute:saltfarm(case,2)
        else:shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',case)
        set_value(case/'swap.swp','SWIRFIX',1)
        if not solute:set_value(case/'swap.swp','SWSOLU',0)
        for crop in case.glob('*.crp'):
            set_value(crop,'SCHEDULE',0)
            if not solute:set_value(crop,'SWSALINITY',0)
        cases.append((key,e.load(case),True))
    cases += [('registered-hupsel',h.HUPSEL,False),('registered-salt',h.SALTFARM,False)]
    for key,project,generic in cases:
        for opt in ('O0','O2'):
            label=key+'-'+opt;base=out/(label+'-base');bundle=out/(label+'-extended')
            common=['--model',project.model,'--reference-work',ref]
            common += ['--experimental-project',project.input_directory,'--donor-opt',opt] if generic else ['--no-macro-release']
            call(label+'-build',common+['--kernel-opt',opt,'--build-only','--output',base])
            original=json.loads((base/'BUILD.json').read_text())
            ir.build_bundle(base,ref,bundle,project)
            meta,case=validate_bundle(bundle,ref,project)
            assert h.sha(h.executable(base,'day_kernel'))==h.sha(h.executable(bundle,'day_kernel'))
            assert meta['identity']['donor_objects']==original['identity']['donor_objects']
            assert h.sha(h.validate_restart_publisher(bundle,meta['identity']['restart_publisher']))==original['identity']['restart_publisher']['library_sha256']
            protocol=ir.project_protocol(project)
            # The old registered rendering remains byte-identical, checked
            # additionally by the source-preservation record.
            # Fresh base and extended binaries without an event file must
            # preserve the original path; fingerprints remain separate.
            nofile_base=out/(label+'-no-file-base');nofile_ext=out/(label+'-no-file-extended')
            for tag,built,target in [('base',base,nofile_base),('extended',bundle,nofile_ext)]:
                call(label+'-no-file-'+tag,common+['--build-bundle',built,'--output',target,'--days',6,'--checkpoint-at',4])
            read_rows=lambda root:[json.loads(line) for line in (root/'daily.jsonl').read_text().splitlines()]
            baseline=read_rows(nofile_base)
            assert list(map(physical,baseline))==list(map(physical,read_rows(nofile_ext)))
            assert payload(nofile_base/'accepted-column-1-day-4.zip')==payload(nofile_ext/'accepted-column-1-day-4.zip')
            manual=None;manual_rows=None
            if generic:
                # Independent original fixed-event table, with a distinct
                # fresh bound build. Never rebind the qualified base input.
                manual=out/(label+'-manual-input');shutil.copytree(case,manual)
                path=manual/'swap.swp';text=path.read_text(encoding='cp1252')
                entries=[]
                for day in (4,140,201,531,800,1100):
                    if day>project.last_day:continue
                    depth,conc,rate,_=event(day,project.solute)
                    stamp=date.fromisoformat(project.start_date)+timedelta(days=day-1)
                    entries.append(f' {stamp.isoformat()} {depth!r} {conc!r} 1 {rate!r}\n')
                text,count=re.subn(r'(?m)^([ \t]*IRDATE[ \t]+IRDEPTH[^\n]*\n)(?:[ \t]*\d{4}-\d{2}-\d{2}[^\n]*\n)+',
                                   lambda m:m[1]+''.join(entries),text)
                assert count==1;path.write_text(text,encoding='cp1252')
                manual_project=e.load(manual);manual_base=out/(label+'-manual-build');manual_run=out/(label+'-manual-control')
                manual_common=['--model',manual_project.model,'--experimental-project',manual,'--reference-work',ref,'--donor-opt',opt]
                call(label+'-manual-build',manual_common+['--kernel-opt',opt,'--build-only','--output',manual_base])
                call(label+'-manual-control',manual_common+['--build-bundle',manual_base,'--output',manual_run,'--days',6,'--checkpoint-at',4])
                manual_rows=read_rows(manual_run)
                for name,value in [('SWIRFIX',0)]:
                    control=case/'swap.swp';saved=control.read_bytes();target=out/(label+'-unsupported-'+name)
                    try:
                        set_value(control,name,value)
                        reject(label+'-unsupported-'+name,lambda:ir.build_bundle(base,ref,target,e.load(case)),absent=target)
                    finally:control.write_bytes(saved)
                if key=='water-hupsel':
                    control=case/'potato.crp';saved=control.read_bytes();target=out/(label+'-scheduled-future')
                    try:
                        set_value(control,'SCHEDULE',1)
                        reject(label+'-scheduled-future',lambda:ir.build_bundle(base,ref,target,e.load(case)),absent=target)
                    finally:control.write_bytes(saved)
                reserved=case/ir.INPUT;reserved.write_text('unexpected preexisting event')
                try:
                    target=out/(label+'-reserved-input')
                    call(label+'-reserved-input',common+['--build-only','--output',target],fail=True,absent=target)
                finally:reserved.unlink()
            last=project.last_day if args.full_period and generic and opt=='O2' else (532 if args.full_period and generic else 6)
            warmdir=out/(label+'-warm');warmdir.mkdir();coupleddir=out/(label+'-external')
            coupled=CoupledDailyColumn(bundle,ref,coupleddir,project,'surface-'+label,forcing_mode=SURFACE_IRRIGATION_FORCING)
            first=coupled.irrigation_forcing(*event(1,project.solute)[:3],'pretrial',enabled=False)
            for field,value in [('origin_day',3),('coupling_id','foreign'),('t0_day1900',0),('enabled',1),('depth_mm',float('nan')),('rate_mm_h',101.)]:
                reject(label+'-'+field,lambda f=dataclasses.replace(first,**{field:value}):coupled.prepare(irrigation=f))
            if not project.solute:
                reject(label+'-chemical-input',lambda:coupled.irrigation_forcing(2.,1.,5.,'invalid-chemical'))
            assert coupled.day==coupled.revision==0 and coupled.checkpoint is None and not list(coupleddir.glob('trial-*'))
            warmrows=[];coldrows=[];maxwater=0.;maxsolute=None if not project.solute else 0.;active=None;publisher=h.sha(h.validate_restart_publisher(bundle,meta['identity']['restart_publisher']))
            selected={1,2,3,4,5,6,140,200,201,365,530,531,532,last}
            with contextlib.ExitStack() as stack:
                warm_stream=stack.enter_context((out/(label+'-warm.jsonl')).open('w'))
                cold_stream=stack.enter_context((out/(label+'-external.jsonl')).open('w'))
                warm=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warmdir,
                    [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
                for day in range(1,last+1):
                    depth,conc,rate,enabled=event(day,project.solute)
                    # Registered Hupsel's admitted bounded interval has no
                    # scheduled crop yet; later registered horizons are not claimed.
                    line=protocol+' '+ ' '.join(map(str,[project.start_clock+day-1,int(enabled),depth,conc,rate]))+'\n'
                    (warm.columns[0].directory/ir.INPUT).write_text(line,encoding='ascii')
                    row=warm.step(1,checkpoint=day in selected or (args.full_period and opt=='O2' and generic))
                    assert row['committed'];warmrows.append(row);warm_stream.write(json.dumps(row)+'\n')
                    expected=0.1*depth
                    assert abs(row['external_flux_cm'][3]-expected)<1e-12,(label,day,'applied water')
                    if project.solute:assert abs(row['solute_ledger_mg_cm2'][3]-expected*conc)<1e-12,(label,day,'applied solute')
                    maxwater=max(maxwater,abs(row['independent_residual_cm']))
                    if project.solute:maxsolute=max(maxsolute,abs(row['solute_independent_residual_mg_cm2']))
                    assert maxwater<=1e-10 and (maxsolute is None or maxsolute<=1e-10)
                    exercise=day<=6 or (generic and (opt=='O2' and args.full_period or day in (531,532)))
                    if generic and opt=='O0' and day==531 and args.full_period:
                        coupled=CoupledDailyColumn(bundle,ref,out/(label+'-active-external'),project,'surface-'+label+'-active',
                            origin=warmdir/'accepted-column-1-day-530.zip',day=530,adopt_native=True,forcing_mode=SURFACE_IRRIGATION_FORCING)
                    if exercise:
                        old=coupled.checkpoint;oldhash=h.sha(old) if old else None
                        request=coupled.irrigation_forcing(depth,conc,rate,'explicit-'+str(day),enabled=enabled)
                        proposal=coupled.prepare(irrigation=request)
                        assert physical(proposal.budget)==physical(row),(label,day,'warm/cold physical')
                        candidate_payload=payload(coupled._candidate[3])
                        assert candidate_payload==payload(warmdir/f'accepted-column-1-day-{day}.zip'),(label,day,'warm/cold native')
                        if day in (4,531):
                            coupled.discard(proposal);assert coupled.checkpoint==old and (old is None or h.sha(old)==oldhash)
                            again=coupled.prepare(irrigation=request)
                            assert again.budget==proposal.budget and payload(coupled._candidate[3])==candidate_payload
                            reject(label+'-discarded-token-'+str(day),lambda:coupled.accept(proposal));proposal=again
                        if day==5:
                            recovered=CoupledDailyColumn(bundle,ref,out/(label+'-disk-recovered'),project,coupled.coupling_id,
                                origin=old,day=4,forcing_mode=SURFACE_IRRIGATION_FORCING)
                            retry=recovered.prepare(irrigation=request)
                            assert retry.budget==proposal.budget and payload(recovered._candidate[3])==candidate_payload
                            recovered.discard(retry)
                        accepted=coupled.accept(proposal)
                        reject(label+'-stale-request-'+str(day),lambda:coupled.prepare(irrigation=request)) if day in (4,531) else None
                        with zipfile.ZipFile(accepted) as z:
                            receipt=json.loads(z.read('checkpoint.json'))['receipt'];assert receipt['coupling']['forcing']['input']==request.document()
                        coldrows.append(receipt);cold_stream.write(json.dumps(receipt)+'\n')
                        # Preserve all accepted ZIPs and complete ledger rows;
                        # discard only redundant successful private trial copies.
                        if day not in selected:
                            for trial in coupled.output.glob('trial-*'):
                                assert trial.resolve().is_relative_to(out.resolve());shutil.rmtree(trial)
                    if day in (200,530) and generic:active=dict(day=day,native_sha256={n:__import__('hashlib').sha256(v).hexdigest() for n,v in payload(warmdir/f'accepted-column-1-day-{day}.zip').items()})
                    if day%100==0:print(label,'accepted',day,flush=True)
                warm.close()
            assert physical(warmrows[3])!=physical(baseline[3]),label+' positive event had no physical effect'
            assert payload(warmdir/'accepted-column-1-day-4.zip')!=payload(nofile_base/'accepted-column-1-day-4.zip')
            if manual_rows is not None:
                assert list(map(physical,warmrows[:6]))==list(map(physical,manual_rows)),label+' independent original-table physical control'
            # Different external owners use different physical/calendar origins.
            alpha=CoupledDailyColumn(bundle,ref,out/(label+'-isolated-cold'),project,'isolated-cold-'+label,forcing_mode=SURFACE_IRRIGATION_FORCING)
            beta=CoupledDailyColumn(bundle,ref,out/(label+'-isolated-warm'),project,'isolated-warm-'+label,
                origin=warmdir/'accepted-column-1-day-2.zip',day=2,adopt_native=True,forcing_mode=SURFACE_IRRIGATION_FORCING)
            for offset in range(3):
                for owner,day in ((alpha,offset+1),(beta,offset+3)):
                    depth,conc,rate,enabled=event(day,project.solute)
                    request=owner.irrigation_forcing(depth,conc,rate,'isolated',enabled=enabled)
                    candidate=owner.prepare(irrigation=request)
                    assert physical(candidate.budget)==physical(warmrows[day-1]);owner.accept(candidate)
            # Re-seal a valid ZIP with edited persisted forcing metadata. Native
            # payload bytes remain intact; lineage/physical domain must refuse.
            source=coupleddir/'accepted-column-1-day-4.zip';tampered=out/(label+'-tampered-forcing.zip')
            with zipfile.ZipFile(source) as z:members={n:z.read(n) for n in z.namelist()}
            manifest=json.loads(members['checkpoint.json'])
            manifest['receipt']['coupling']['forcing']['input']['concentration_mg_cm3']+=1.
            members['checkpoint.json']=json.dumps(manifest).encode()
            with zipfile.ZipFile(tampered,'w',compression=zipfile.ZIP_DEFLATED) as z:
                for name,body in members.items():z.writestr(name,body)
            refused=out/(label+'-rejected-persisted-forcing')
            reject(label+'-persisted-forcing',lambda:CoupledDailyColumn(bundle,ref,refused,project,'surface-'+label,
                origin=tampered,day=4,forcing_mode=SURFACE_IRRIGATION_FORCING))
            assert not list(refused.glob('accepted-*.zip'))
            if opt=='O2':
                def consume_bad(tag,line):
                    root=out/(label+'-consumer-'+tag);root.mkdir();private=root/'input';shutil.copytree(case,private)
                    (private/ir.INPUT).write_text(line+'\n');model=root/'model';model.mkdir()
                    with contextlib.ExitStack() as stack:
                        host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),private,model,
                            [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
                        try:host.step(1,checkpoint=True)
                        finally:
                            if host.usable:host.close()
                            else:
                                for proc in [host.host,*[col.worker for col in host.columns]]:
                                    if proc.poll() is None:proc.kill()
                for tag,line in [('foreign-protocol',f'FOREIGN {project.start_clock} 0 0 0 0'),
                                 ('stale-clock',f'{protocol} {project.start_clock+1} 0 0 0 0'),
                                 ('nonfinite',f'{protocol} {project.start_clock} 1 NaN 0 1')]:
                    reject(label+'-consumer-'+tag,lambda tag=tag,line=line:consume_bad(tag,line))
                    assert not list((out/(label+'-consumer-'+tag)).rglob('accepted-*.zip'))
                if not project.solute:
                    tag='chemical-water-only';line=f'{protocol} {project.start_clock} 1 2 1 5'
                    reject(label+'-consumer-'+tag,lambda:consume_bad(tag,line))
            if args.full_period and generic and opt=='O2':
                # Actual unchanged original executable, with the independently
                # specified event table and only valid CSV spelling/precision.
                original=out/(label+'-original-reference');shutil.copytree(manual,original)
                path=original/'swap.swp';text=path.read_text(encoding='cp1252')
                text,count=re.subn(r"(?mi)^([ \t]*INLIST_CSV[ \t]*=[ \t]*)'[^']*'",r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'",text);assert count==1
                text=re.sub(r'(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1',r'\g<1>0',text)
                text,count=re.subn(r'(?m)^([ \t]*NUM_DECIMALS[ \t]*=[ \t]*)[^\s!]+',r'\g<1>12',text);assert count<=1
                if count==0:text+='\nNUM_DECIMALS = 12\n'
                path.write_text(text,encoding='cp1252');donor=h.executable(ref/'build','swap_b0_gfortran')
                with (original/'stdout.log').open('wb') as log:
                    comparison=subprocess.run([str(donor),'./swap.swp'],cwd=original,stdout=log,stderr=subprocess.STDOUT,timeout=180)
                report=dict(original_executable_sha256=h.sha(donor),returncode=comparison.returncode,
                    swap_ok=(original/'swap.ok').exists(),error=(original/'swap.err').read_text(encoding='cp1252') if (original/'swap.err').exists() else '',
                    physical_input='Distinct derived original fixed-event table matches externally supplied water/chemical events',
                    output_only_changes=['valid CSV groups','SWMONTH0','NUM_DECIMALS12'],scientific_equivalence='NOT_QUALIFIED; inherited FAILs retained')
                def csv_rows(path):return list(csv.DictReader([line for line in path.read_text(encoding='cp1252').splitlines() if line.strip() and not line.startswith('*')]))
                left=csv_rows(next(original.glob('*_output.csv')));right=csv_rows(warmdir/'original/result_output.csv')
                report.update(original_output_rows=len(left),hybrid_output_rows=len(right),maximum_numeric_csv_differences={})
                if len(left)==len(right):
                    for field in left[0]:
                        try:report['maximum_numeric_csv_differences'][field]=max(abs(float(a[field])-float(b[field])) for a,b in zip(left,right,strict=True))
                        except (KeyError,ValueError,TypeError):pass
                (out/(label+'-COMPARISON.json')).write_text(json.dumps(report,indent=2)+'\n')
                assert report['swap_ok'] and not report['error'].strip() and comparison.returncode in (0,100)
            reports.append(dict(configuration=key,kernel_optimization=opt,generated_donor_optimization=opt if generic else 'O2',
                original_provider_optimization='O2',protocol=protocol,solute_active=project.solute,full_model_days=last,
                full_period=last==project.last_day,externally_accepted_days=len(coldrows),every_exercised_native_exact=True,
                maximum_water_residual_cm=maxwater,maximum_solute_residual_mg_cm2=maxsolute,
                original_kernel_reused=True,original_objects_reused=True,publisher_copied_and_verified=publisher,active_native=active,
                no_file_original_physical_and_native_preserved=True,manual_original_input_control_exact=generic,
                isolated_external_origins=True,persisted_forcing_attack_refused=True,
                scientific_equivalence='NOT_QUALIFIED'))
            save();print(label,'PASS',last,flush=True)
    result=dict(status='EXPERIMENTAL_GENERIC_SURFACE_FULL_PASS' if args.full_period else 'EXPERIMENTAL_GENERIC_SURFACE_SMOKE_PASS',
        source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles=reports,
        refusals=refusals,events=events,science='NOT_QUALIFIED; original FAILs and physical energy limits retained')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    started=[];expired=[];real_start=h.start_process
    def track(*args,**kwargs):
        proc,log=real_start(*args,**kwargs);started.append(proc);return proc,log
    def stop():
        expired.append(True)
        for proc in started:
            if proc.poll() is None:proc.kill()
    h.start_process=track
    timer=threading.Timer(1500,stop);timer.daemon=True;timer.start()
    try:main()
    except BaseException:
        if OWNED_OUTPUT is not None:
            (OWNED_OUTPUT/'FAILURE.json').write_text(json.dumps(dict(status='FAILED_NOT_QUALIFIED',
                censored=bool(expired),traceback=traceback.format_exc(),
                source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()),indent=2)+'\n')
        raise
    finally:
        timer.cancel();h.start_process=real_start
        for proc in started:
            if proc.poll() is None:proc.kill()

