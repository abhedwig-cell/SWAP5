"""Read-only physical-contract audit of eight transactionally restored provider probes."""
from pathlib import Path
import json,hashlib,math,csv
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-node41';W=Path('C:/Users/Veldh012/swap431-contract42-work/native')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# No numerical provider or solver statement has been replaced.
s=(R/'macrorate_node.f90').read_text();i=s.index('      entry contract42_cache_io(');e=s.index('      entry jac37_invalidate()',i);assert s[:i]+s[e:]==(P/'macrorate_node.f90').read_text()
s=(R/'guard41_observer.f90').read_text().replace('\nif(iter_index==10) call contract42_probe()','');assert s==(P/'guard41_observer.f90').read_text()
for p in P.glob('*.f90'):
 if p.name not in ['macrorate_node.f90','guard41_observer.f90']:assert p.read_bytes()==(R/p.name).read_bytes()
res=[];pairs=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';old=P/'data'/opt/'TRAJ'
 for p in old.glob('*.txt'):
  if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
  assert p.read_bytes()==(d/p.name).read_bytes(),p.name
 assert [x[:-1] for x in rows(d/'attempt_trace.txt')]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
 assert len(rows(d/'attempt_trace.txt'))==357 and len(rows(d/'step_budget.txt'))==356
 pts=rows(d/'probe42_points.txt');dom=rows(d/'probe42_domains.txt');rest=rows(d/'probe42_restore.txt')
 assert len(pts)==8 and all(len(x)==42 for x in pts) and len(dom)==40 and all(len(x)==44 for x in dom)
 assert len(rest)==9 and all(x[1:]==[20347880,3247712,1,1,1] for x in rest)
 assert (d/'probe42_base.bin').read_bytes()==(d/'probe42_restored.bin').read_bytes()
 assert (d/'probe42_cache_base.bin').read_bytes()==(d/'probe42_cache_restored.bin').read_bytes()
 assert pts[0][1:]==pts[-1][1:] and all(x[1:]==y[1:] for x,y in zip(dom[:5],dom[-5:]))
 for x in pts:
  assert x[3]<0 and x[11]-x[10]>1e-8 and x[12]>0 and x[15]==1
  assert all(v==0 for v in x[27:]) # No saturated alternative or incoming node47 flux.
  assert abs(math.fsum(x[17:22])-math.fsum(x[22:27]))<1e-15
 for x in dom:
  assert x[9]==x[17]==1 # All in/out factors unchanged and unlimited at every probe.
  if x[1]!=4:continue
  point=pts[int(x[0])-1];h=point[3];theta=point[10];thetas=point[11];K=point[12];dz=point[14]
  hm,delta,rec,sf,qd,uf=x[27:33];pp,dipo,shape,parl,alpha,thetar=x[33:39]
  rec_calc=shape*8*pp*dz*K/dipo**2
  sf_calc=parl+(1-parl)*(1-(max(0,thetas-theta)/(thetas-thetar))**alpha)
  expected=point[15]*rec_calc*max(0,hm-h)*sf_calc
  assert hm>dz/2 and x[26]==42 and pp>0 and dipo>0 and 0<sf<=1
  assert abs(rec-rec_calc)<1e-16 and abs(sf-sf_calc)<1e-15 and abs(qd-expected)<1e-15
  assert 0<uf<=1 and qd>.0565
  if point[6]==48:assert abs(point[25]-qd)<1e-15 and abs(x[42]/point[16]-qd)<1e-15
  else:assert point[6]==47 and point[25]==0 and x[42]==0
 for lev,eps in enumerate([1e-4,1e-6,1e-8]):
  left,right=pts[1+2*lev:3+2*lev];dl=dom[(int(left[0])-1)*5+3];dr=dom[(int(right[0])-1)*5+3]
  assert left[2]==left[5]==-60-eps and right[2]==right[5]==-60+eps
  assert left[6:9]==[48,48,48] and right[6:9]==[47,47,-1] and right[9]==999
  assert left[25]>.0565 and right[25]==0 and dr[32]>=1-eps/2-1e-14
  assert abs(dl[31]-dr[31])<2e-6*(eps/1e-4)
  pair=dict(optimization=opt,GWL_offset_cm=eps,h47_below=left[3],h47_above=right[3],actual_D4_UNSAT_rate_below=left[25],actual_D4_UNSAT_rate_above=right[25],actual_rate_gap=left[25]-right[25],documented_Darcy_candidate_above=dr[31],remaining_geometric_unsaturated_fraction_above=dr[32],geometrically_weighted_candidate_above=dr[31]*dr[32],matrix_head_above=right[3],matrix_moisture_deficit_above=right[11]-right[10],macro_pressure_above=dr[27],saturated_alternative_above=math.fsum(right[27:32]))
  pairs.append(pair)
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==h for name,h in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 res.append(dict(optimization=opt,seconds=run['seconds'],same_original357_all_numerical_outputs_preserved=True,actual_extra_MACRORATE1_calls=8,SENSE23_selected_bytes=20347880,numerical_observer_cache_bytes=3247712,selected_byte_and_recognized_IEEE_flag_restores=9,probe_base_repetition_exact=True,smallest_offset_cm=1e-8,D4_rate_gap_at_smallest_offset=pts[5][25]-pts[6][25],D4_documented_Darcy_candidate_at_zero_side=dom[6*5+3][31],geometric_unsaturated_fraction_at_zero_side=dom[6*5+3][32],physical_solver_guard_or_budget_changes=False))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
for name in ['probe42_base.bin','probe42_restored.bin','probe42_cache_base.bin','probe42_cache_restored.bin']:assert (R/'data/O0/TRAJ'/name).read_bytes()==(R/'data/O2/TRAJ'/name).read_bytes()
with (R/'PAIRED_LIMITS.csv').open('w',newline='',encoding='utf-8') as fp:
 w=csv.DictWriter(fp,fieldnames=list(pairs[0]));w.writeheader();w.writerows(pairs)
q=dict(work_unit='SWAP431-MACRO-B1-CONTRACT42',decision='BOUNDED_DOCUMENTED_DARCY_CONTRACT_DISCREPANCY_CONFIRMED_NO_CORRECTION_IMPLEMENTED',source_checkpoint='07b5d3686',model_routes=2,external_hard_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,physical_adjudication='Whole-cell ABSORPTION cutoff is intentional code behavior, but its zero Darcy rate for this still-unsaturated water-contacted cell is inconsistent with documented unsaturated-contact/Darcy law. Historical author intent and all other configurations unclaimed.',primary_authority='Kroes etal2017 SWAP4 WER2780 pp100/106 eq6.32/6.57; preserved currentmax/factor/stock rules',smallest_probe_geometry_is_not_exact_tie=True,saturation_or_stock_or_flow_reduction_does_not_explain_zero=True,new_correction_or_convergence_fix_implemented=False,full_period_BAL_new_restart_or_canonical_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=res)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
