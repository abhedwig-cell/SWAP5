"""Reproduce bounded STRIP01 qualification and scientific figures from raw evidence."""
import argparse,json
from pathlib import Path
import numpy as np
import flopy
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 def read(name,file='coupled_result.json'):return json.loads((a.evidence/name/file).read_text())
 s=read('strip01-steady-transfer-final');n=read('strip01-steady-transfer-disconnected');d1=read('strip01-clean-day005');d2=read('strip01-clean-day0025')
 assert s['status']==d1['status']==d2['status']=='COUPLED_SHORT_RESEARCH_PASS'
 assert not any(s[k] for k in ['depth_budget_rate','newton_budget','mf_budget_allocate'])
 assert n['failure']=='PRE_PUBLICATION_EXCHANGE_MISMATCH' and not n['windows']
 assert n['rejected_origin_unchanged'] and n['rejected_flux_replay_identical']
 folder=a.evidence/'strip01-steady-transfer-final';grb=flopy.mf6.utils.MfGrdFile(folder/'GWF_1.dis.grb');budget=flopy.utils.CellBudgetFile(folder/'strip.cbc',precision='double')
 face_errors=[];flows=[]
 for t in budget.get_times():
  ja=budget.get_data(text='FLOW-JA-FACE',totim=t)[0].ravel();left=[]
  for i in range(1,50):
   entries=range(grb.ia[i]+1,grb.ia[i+1]);k=next(k for k in entries if grb.ja[k]==i-1);left.append(-ja[k])
  flows.append(left);face_errors.append(float(np.max(abs(np.array(left)-np.arange(49,0,-1)*.001))))
 assert max(face_errors)<1e-10,face_errors
 assert set(grb.ja[grb.ia[49]+1:grb.ia[50]])=={48}
 def metrics(d):
  w=d['windows'];return dict(windows=len(w),days=w[-1]['day'],max_balance_residual_m3=max(abs(r['whole_balance_residual_m3']) for r in w),rain_m3=sum(r['rain_m3'] for r in w),drain_m3=sum(r['drain_out_m3'] for r in w),swap_storage_change_m3=sum(r['delta_swap_storage_m3'] for r in w),mf_storage_change_m3=sum(r['mf_delta_storage_m3'] for r in w))
 h1=np.array(d1['terminal_profiles']['pressure_cm']);h2=np.array(d2['terminal_profiles']['pressure_cm']);diff=float(np.max(abs(h1-h2)));assert diff<1e-5
 panels={}
 for name in ['strip01-refinement-results','strip01-refinement-repaired','strip01-refinement-allocated']:
  rows=read(name,'summary.json')['rows'];panels[name]=dict(complete=sum(r['complete'] for r in rows),total=len(rows),max_completed_mass_residual_cm=max(r['stats'][3] for r in rows if r['complete']))
  assert all(r['origin_unchanged'] and not r['temporal_acceptance_claim'] for r in rows)
 assert [panels[n]['complete'] for n in panels]==[18,33,43]
 rows=read('strip01-refinement-allocated','summary.json')['rows']
 diagnostic=next(r for r in rows if r['elastic_per_cm']==1e-7 and r['dt_day']==.001 and r['head_m']==-5.05 and r['subdivisions']==16)
 assert diagnostic['reported_gwl_m']==-5 and abs(diagnostic['pressure_zero_gwl_m']+5.006532803573434)<1e-10
 for d in [d1,d2]:assert max(r['mf_dense_oracle_error_m'] for r in d['outer_attempts'])<=1e-9
 fig,ax=plt.subplots(figsize=(7,4))
 for head in [-5,-5.000001,-5.05]:
  rs=[r for r in rows if r['head_m']==head and r['elastic_per_cm']==1e-7 and r['subdivisions']==1 and 'head_difference_to_n16_cm' in r];ax.loglog([r['dt_day'] for r in rs],[max(r['head_difference_to_n16_cm'],1e-16) for r in rs],'o-',label=f'Interface {head:.6f} m')
 ax.axhline(1e-5,color='black',ls='--',label='Temporal budget');ax.set(xlabel='Total interval (day)',ylabel='Pressure difference N=1 vs N=16 (cm)',title='Independent diagnostic; successful solve does not certify time accuracy');ax.legend();fig.tight_layout();fig.savefig(a.output/'refinement.png',dpi=160);plt.close(fig)
 w=s['windows'][-1];head=np.array(w['head_m']);gwl=np.array(w['swap_gwl_m']);x=np.arange(50)+.5
 derived=[];z=-.1-.2*np.arange(30)
 for h in s['terminal_profiles']['pressure_cm']:
  h=np.array(h);j=np.flatnonzero(h>=0)[0];assert j>0;derived.append(z[j-1]-h[j-1]*(z[j]-z[j-1])/(h[j]-h[j-1]))
 assert max(abs(np.array(derived)-gwl))<1e-10
 fig,axes=plt.subplots(3,1,figsize=(8,9));axes[0].plot(x,head,label='MODFLOW head');axes[0].plot(x,gwl,'--',label='SWAP pressure-zero GWL');axes[0].set(ylabel='Elevation (m)',title='50 m stationary coupled strip, R=1 mm/day');axes[0].legend();axes[1].plot(x,1000*(gwl-head));axes[1].set(ylabel='GWL minus head (mm)');axes[2].plot(np.arange(1,50),flows[-1],label='Native leftward face flow');axes[2].plot(x,w['q_m_day'],label='Native SWAP bottom exchange');axes[2].set(xlabel='Distance from left boundary (m)',ylabel='Flow (m³/day)');axes[2].legend();fig.tight_layout();fig.savefig(a.output/'steady_transfer.png',dpi=160);plt.close(fig)
 fig,axes=plt.subplots(1,2,figsize=(9,4));z=-.1-.2*np.arange(30);axes[0].plot(1e8*(h1-h2)[0],z);axes[0].set(xlabel='Pressure difference between schedules (10⁻⁸ cm)',ylabel='Depth elevation (m)');
 for d,label in [(d1,'0.005 d'),(d2,'0.0025 d')]:axes[1].plot([w['day'] for w in d['windows']],[w['whole_balance_residual_m3'] for w in d['windows']],label=label)
 axes[1].set(xlabel='Time (day)',ylabel='Window mass residual (m³)');axes[1].legend();fig.tight_layout();fig.savefig(a.output/'dry_day_consistency.png',dpi=160);plt.close(fig)
 result=dict(state='AB_QUALIFIED_C_STATIONARY_ROUTE_AND_BOUNDED_DRY_DAY',canonical_admission=False,whole_unit_complete=False,steady_transfer=metrics(s),max_native_lateral_face_error_m3_day=max(face_errors),gwl_minus_head_m=[float(min(gwl-head)),float(max(gwl-head))],disconnect_negative=dict(failure=n['failure'],accepted_windows=0,origin_unchanged=True,replay_identical=True),dry_day005=metrics(d1),dry_day0025=metrics(d2),max_window_schedule_pressure_difference_cm=diff,panels=panels,raw_reference_gwl_diagnostic=dict(reported_gwl_m=diagnostic['reported_gwl_m'],pressure_zero_gwl_m=diagnostic['pressure_zero_gwl_m'],temporally_admitted=False),hupsel_qualified=False,restart_qualified=False)
 (a.output/'refinement_summary.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
