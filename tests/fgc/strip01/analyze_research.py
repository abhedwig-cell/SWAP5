"""Rebuild diagnostic figure and summary from the persisted research panel."""
import argparse,json,re
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def main():
 p=argparse.ArgumentParser();p.add_argument('--results',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 fig,ax=plt.subplots(figsize=(7,4))
 for prefix,label in [('rain_','No physical elasticity'),('elastic_','Ss = 1e-5 /m')]:
  values=[]
  for suffix in ['1e4','1e3','1e2']:
   row=json.loads((a.results/(prefix+suffix+'.json')).read_text());log=(a.results/(prefix+suffix+'.log')).read_text()
   match=re.search(r'STRIP_OBSERVATION\s+(.+)',log);tokens=match.group(1).split();values.append((row['dt_day'],float(tokens[3])))
  x,y=zip(*values);ax.loglog(x,y,'o-',label=label)
 ax.axhline(1e-5,color='black',linestyle='--',label='Unchanged head budget')
 ax.set(xlabel='Requested window (day)',ylabel='Head bound at final rejected attempt (cm)',title='STRIP01 startup temporal rejection')
 ax.legend();ax.grid(alpha=.2);fig.tight_layout();fig.savefig(a.output/'startup_temporal.svg');plt.close(fig)
 r=json.loads((a.results/'coupled_short/coupled_result.json').read_text());rows=r['windows']
 summary=dict(claim='SHORT_SMOKE_ONLY_NOT_PHASE_C_QUALIFICATION',status=r['status'],accepted_windows=len(rows),duration_days=rows[-1]['day'],max_interface_residual_m3_day=max(x['interface_residual_m3_day'] for x in rows),max_whole_balance_residual_m3=max(abs(x['whole_balance_residual_m3']) for x in rows),rain_m3=sum(x['rain_m3'] for x in rows),drain_out_m3=sum(x['drain_out_m3'] for x in rows),swap_storage_change_m3=sum(x['delta_swap_storage_m3'] for x in rows),mf_storage_change_m3=sum(x['mf_delta_storage_m3'] for x in rows),far_cell_to_drain_proven=False,restart_tested=False,hupsel_tested=False)
 (a.output/'research_summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
