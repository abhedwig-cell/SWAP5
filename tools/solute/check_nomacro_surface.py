"""Actual generic original surface events: fresh builds, exact state and transactions."""
import argparse,contextlib,dataclasses,json,math,re,shutil,subprocess,sys,time,zipfile
from datetime import date,timedelta
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
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
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=out/'provider'
    reports=[];events=[];refusals=[]
    def save():
        (out/'PROFILES.json').write_text(json.dumps(reports,indent=2)+'\n')
        (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
        (out/'REFUSALS.json').write_text(json.dumps(refusals,indent=2)+'\n')
    def call(label,arguments):
        started=time.monotonic();cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),*map(str,arguments)]
        result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=300)
        (out/(label+'.log')).write_text(result.stdout+result.stderr)
        events.append(dict(label=label,command=cmd,returncode=result.returncode,seconds=time.monotonic()-started));save()
        assert result.returncode==0,(label,result.stdout,result.stderr);print(label,'PASS',flush=True)
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
                warm=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warmdir,
                    [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
                for day in range(1,last+1):
                    depth,conc,rate,enabled=event(day,project.solute)
                    # Registered Hupsel's admitted bounded interval has no
                    # scheduled crop yet; later registered horizons are not claimed.
                    line=protocol+' '+ ' '.join(map(str,[project.start_clock+day-1,int(enabled),depth,conc,rate]))+'\n'
                    (warm.columns[0].directory/ir.INPUT).write_text(line,encoding='ascii')
                    row=warm.step(1,checkpoint=day in selected or (args.full_period and opt=='O2' and generic))
                    assert row['committed'];warmrows.append(row)
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
                        coldrows.append(receipt)
                        # Preserve all accepted ZIPs and complete ledger rows;
                        # discard only redundant successful private trial copies.
                        if day not in selected:
                            for trial in coupled.output.glob('trial-*'):
                                assert trial.resolve().is_relative_to(out.resolve());shutil.rmtree(trial)
                    if day in (200,530) and generic:active=dict(day=day,native_sha256={n:__import__('hashlib').sha256(v).hexdigest() for n,v in payload(warmdir/f'accepted-column-1-day-{day}.zip').items()})
                    if day%100==0:print(label,'accepted',day,flush=True)
                warm.close()
            (out/(label+'-warm.jsonl')).write_text(''.join(json.dumps(r)+'\n' for r in warmrows))
            (out/(label+'-external.jsonl')).write_text(''.join(json.dumps(r)+'\n' for r in coldrows))
            reports.append(dict(configuration=key,kernel_optimization=opt,generated_donor_optimization=opt if generic else 'O2',
                original_provider_optimization='O2',protocol=protocol,solute_active=project.solute,full_model_days=last,
                full_period=last==project.last_day,externally_accepted_days=len(coldrows),every_exercised_native_exact=True,
                maximum_water_residual_cm=maxwater,maximum_solute_residual_mg_cm2=maxsolute,
                original_kernel_reused=True,original_objects_reused=True,publisher_copied_and_verified=publisher,active_native=active,
                scientific_equivalence='NOT_QUALIFIED'))
            save();print(label,'PASS',last,flush=True)
    result=dict(status='EXPERIMENTAL_GENERIC_SURFACE_FULL_PASS' if args.full_period else 'EXPERIMENTAL_GENERIC_SURFACE_SMOKE_PASS',
        source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles=reports,
        refusals=refusals,events=events,science='NOT_QUALIFIED; original FAILs and physical energy limits retained')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':main()
