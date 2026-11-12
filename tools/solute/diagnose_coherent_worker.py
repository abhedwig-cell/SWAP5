"""Read-only full original/daily/coherent corrected physics and iteration discriminator.

Not a new reference: same configured inputs, original source or already accepted
corrections. Counter and nodal observers preserve the existing CSV control.
"""
import argparse,json,shutil,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
for name in ('bundle','reference','full','original_case','output'):p.add_argument('--'+name.replace('_','-'),type=Path,required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();bundle=a.bundle.resolve();reference=a.reference.resolve();meta=json.loads((bundle/'BUILD.json').read_text())
rows=[json.loads(s) for s in (a.full/'daily.jsonl').read_text().splitlines()];last=rows[-1]['day'];flags=meta['identity']['donor_flags']
records=lambda q:[s for s in q.read_text().splitlines() if s.strip() and not s.startswith('*')]
all_modes={}
for mode in ('original','corrected-daily','corrected-coherent'):
 out=a.output/mode;out.mkdir();corrected=mode!='original'
 selected=reference/'build/swap-selected'
 main=(bundle/'swap_main.f90' if mode=='corrected-daily' else selected/'swap_main.f90').read_text(encoding='cp1252')
 main=main.replace('implicit none','use variables, only: itnumb\nimplicit none\ninteger :: rc1_j',1)
 main=main.replace('   call IterTime(3)',"   write(*,'(a,*(1x,i0))') 'RC1_FINAL_HIST', itnumb(:,1)\n   call IterTime(3)")
 (out/'swap_main.f90').write_text(main,encoding='cp1252')
 if mode=='corrected-coherent':
  swap=(bundle/'swap.f90').read_text(encoding='cp1252')
  anchor='use MOD_swap_base,       only: pathwork,';assert swap.count(anchor)==1
  swap=swap.replace(anchor,'use hybrid_day_window, only: budget_enabled, budget_start, budget_retries\n'+anchor)
  anchor='      if (flDayStart) then';assert swap.count(anchor)==1
  swap=swap.replace(anchor,anchor+'\n         budget_enabled=.true.\n         budget_start=t1900\n         budget_total=0d0\n         budget_retries=0')
  (out/'swap.f90').write_text(swap,encoding='cp1252')
 csv=(bundle/'swap_csv_output.f90' if corrected else selected/'swap_csv_output.f90').read_text(encoding='cp1252')
 anchor='   subroutine set_values_scalar()';assert csv.count(anchor)==1
 csv=csv.replace(anchor,anchor+'\n   use variables, only: rc1_h=>h,rc1_qbot=>qbot,itnumb\n   use MOD_SoilTemperature, only: rc1_tsoil=>tsoil')
 anchor='   dstor_1    = wasrdm1 - iwasrdm1beg';assert csv.count(anchor)==1
 observer="""   write(*,'(a,*(1x,es25.17e3))') 'RC1_HEAD', gwl,rc1_qbot,rc1_h(1:numnod)
   write(*,'(a,*(1x,es25.17e3))') 'RC1_HEAT', rc1_tsoil(1:numnod)
   write(*,'(a,*(1x,i0))') 'RC1_HIST', itnumb(:,1)
"""
 if not corrected:
  observer+="""   write(*,'(a,12(1x,es25.17e3))') 'HYBRID_STOCK_FLUX', &
      volact,pond,ssnow,sicact,0d0,0d0,ivolbeg,ipondbeg,issnowbeg,isicbeg,0d0,0d0
   write(*,'(a,16(1x,es25.17e3))') 'HYBRID_EXTERNAL_FLUX', &
      igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup,iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,0d0,iqbdo
   write(*,'(a,9(1x,es25.17e3))') 'HYBRID_SOLUTE_LEDGER', &
      sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev
   write(*,'(a,6(1x,es25.17e3))') 'HYBRID_UPTAKE', iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs
"""
 csv=csv.replace(anchor,observer+anchor);(out/'swap_csv_output.f90').write_text(csv,encoding='cp1252')
 sources=(['swap'] if mode=='corrected-coherent' else [])+['swap_csv_output','swap_main']
 for name in sources:
  cmd=['gfortran',*flags,'-I',str(out),'-I',str(bundle if corrected else reference/'build/swap-obj'),'-I',str(reference/'build/swap-obj'),'-I',str(reference/'build/ttutil-obj'),'-c',name+'.f90']
  c=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=60);(out/(name+'-compile.log')).write_text(c.stdout+c.stderr);assert c.returncode==0,c.stderr
 objects=[]
 for orig in sorted((reference/'build/swap-obj').glob('*.o')):
  local=out/orig.name;candidate=bundle/orig.name
  objects.append(str(local if local.exists() else candidate if corrected and candidate.exists() else orig))
 exe=out/('coherent.exe' if __import__('os').name=='nt' else 'coherent')
 link=subprocess.run(['gfortran','-o',str(exe),*objects,*([str(bundle/'hybrid_step_budget.o')] if corrected else []),str(reference/'build/ttutil-obj/libttutil.a')],capture_output=True,text=True,timeout=60);assert link.returncode==0,link.stderr
 case=out/'case';case.mkdir()
 for name in meta['inputs']:
  (case/name).parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(a.full/'original'/name,case/name)
 payload=(''.join(f'{d} -1\n' for d in range(1,last+1))+'0 -1\n').encode() if mode=='corrected-daily' else None
 started=time.perf_counter()
 with (out/'stdout').open('wb') as stdout,(out/'stderr').open('wb') as stderr:
  run=subprocess.run([str(exe),'./swap.swp'],cwd=case,input=payload,stdout=stdout,stderr=stderr,timeout=60)
 assert run.returncode==100,(mode,(out/'stderr').read_text())
 control=a.full if corrected else a.original_case
 expected=control/'original/result_output.csv' if corrected else control/'result_output.csv'
 exact_csv=records(case/'result_output.csv')==records(expected)
 assert exact_csv or mode=='corrected-coherent','Read-only observer changed existing physics'
 frames={key:[] for key in ('HEAD','HEAT','HIST','STOCK_FLUX','EXTERNAL_FLUX','SOLUTE_LEDGER','UPTAKE')}
 for s in (out/'stdout').read_text(encoding='cp1252').splitlines():
  for key in frames:
   tag=('RC1_' if key in ('HEAD','HEAT','HIST') else 'HYBRID_')+key
   if s.startswith(tag+' '):frames[key].append(list(map(float,s.split()[1:])))
 assert all(len(v)==last+1 for v in frames.values()),[(k,len(v)) for k,v in frames.items()]
 final_hist=frames['HIST'][-1];item=dict(mode=mode,observer_wall_seconds=time.perf_counter()-started,exact_existing_csv=exact_csv,
  converged_solve_count=sum(final_hist),iterations_in_converged_solves=sum((i+1)*v for i,v in enumerate(final_hist)),
  cost_note='Includes substantial observer output; use counts, not this wall time as the ordinary application benchmark.')
 if mode=='corrected-daily':
  for i,r in enumerate(rows,1):
   assert frames['HEAD'][i][2:]==r['pressure_head_cm']
   assert frames['STOCK_FLUX'][i][:6]==r['stock_end_cm'] and frames['EXTERNAL_FLUX'][i]==r['external_flux_cm']
 (out/'FRAMES.json').write_text(json.dumps(frames)+'\n');all_modes[mode]=dict(summary=item,frames=frames);print(json.dumps(item),flush=True)
baseline=all_modes['corrected-daily']['frames'];coherent=all_modes['corrected-coherent']['frames']
summary={m:d['summary'] for m,d in all_modes.items()}
summary['causal_disposition']=dict(corrected_coherent_exact_all_frames=baseline==coherent,
  first_nonzero_original_difference={})
for key,values in all_modes['original']['frames'].items():
 if key=='HIST':continue
 for day,(old,new) in enumerate(zip(values,baseline[key],strict=True)):
  if old!=new:
   summary['causal_disposition']['first_nonzero_original_difference'][key]=dict(day=day,max_absolute=max(abs(x-y) for x,y in zip(old,new)));break
(a.output/'RESULT.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
