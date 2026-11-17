from pathlib import Path
import sys,importlib.util,json,subprocess,shutil,os,time,re
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-native09';W=Path('C:/Users/Veldh012/swap431-initial30-work')
sp=importlib.util.spec_from_file_location('native09',P/'native09.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);m.R=R;m.WORK=W
body=(P/'native09.py').read_text();body=body[body.index('def build(opt):'):body.index('def run(opt,')];body=body.replace("for name,dest in [","for name,dest in [('diag_state','diag19'),('calcgwl_probe','calcgwl'),('head_diag','headcalc'),('macrorate_node','macrorate'),('integral_canopy','integral'),",1);body=body.replace("('macropore_native','macropore'),","('macropore_native','macropore'),('probe_state','probe23'),('jac_update','jac24'),('ledger_state','ledger12'),",1);exec(body,m.__dict__)
def run(opt,mode,label=''):
 profile=mode+('_'+label if label else '')
 c=W/(opt+'-'+profile+'-FINAL-RENDER');c.mkdir(parents=True,exist_ok=True);assert not (c/'outcome.txt').exists()
 for x in json.loads((P/'CASE_IDENTITY.json').read_text()):
  src=Path('C:/Users/Veldh012/swap431-state02-work/phase/O2/V1/case')/x['path'];assert m.sha(src)==x['sha256'];(c/x['path']).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,c/x['path'])
 cal=R.parent/'swap431-macro-b1-sense23/data'/opt/'RESUME_IEEE/trial23_base.bin'
 assert m.sha(cal)=='aec5d4383614499853fe809018b53844d54d852a205a77f45c28ea28378f62c3'
 shutil.copy2(cal,c/'calibration_base.bin')
 if mode in ['TRIAL','DIRECT']:shutil.copy2(R.parent/'swap431-macro-b1-next18/data'/opt/'PREFIX/midnight.end',c/'own.end')
 s=(c/'swap.swp').read_text(encoding='cp1252');
 if mode in ['TRIAL','DIRECT']:s=re.sub(r'(?mi)^(\s*SWINCO\s*=\s*)2\b',r'\g<1>3',s,count=1)
 s=re.sub(r'(?mi)^\s*TEND\s*=.*$', ' TEND = 1998-01-03',s,count=1)
 if mode in ['TRIAL','DIRECT']:s+="\n INIFIL = 'own.end'\n SWINITYPE = 2\n SWENDTYPE = 2\n";(c/'swap.swp').write_text(s,encoding='cp1252')
 
 for key in ['SWBAL','SWBLC','SWBMA']:s=re.sub(r'(?mi)^(\s*'+key+r'\s*=\s*)0\b',r'\g<1>1',s,count=1)
 s=re.sub(r'(?mi)^\s*DATEFIX\s*=.*$', ' DATEFIX = 2 1',s,count=1)
 s=re.sub(r'(?mi)^(\s*SWYRVAR\s*=\s*)0\b',r'\g<1>1',s,count=1)
 s+='\n OUTDAT = 1998-01-02 1998-01-03\n'
 (c/'swap.swp').write_text(s,encoding='cp1252')
 env=os.environ.copy();env['DAY10_MODE']=mode;selected=json.loads((R/'SELECTION.json').read_text())[label];env['SELECT27_T']=format(selected['time'],'.17g');env['SELECT27_DT']=format(selected['dt'],'.17g');env['LEDGER12_REQUIRE']='1' if mode in ['TRIAL','DIRECT'] else '0';t=time.perf_counter()
 try:
  p=subprocess.run([str(W/'native'/opt/'native09.exe'),'./swap.swp'],cwd=c,env=env,capture_output=True,text=True,timeout=20);q=dict(returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
 except subprocess.TimeoutExpired:q=dict(censored=True,seconds=time.perf_counter()-t)
 m.save(R/(opt+'_'+profile+'_RUN.json'),q);d=R/'data'/opt/profile;d.mkdir(parents=True,exist_ok=True)
 for p in list(c.glob('*.txt'))+list(c.glob('*.end'))+list(c.glob('*.bin'))+list(c.glob('*.bma'))+list(c.glob('*.bal'))+list(c.glob('*.blc'))+list(c.glob('result_output.csv'))+[c/'swap.swp',c/'swap.err',c/'swap.wrn']:
  if p.exists():shutil.copy2(p,d/p.name)
 print(q)
if __name__=='__main__':
 action,opt=sys.argv[1:3]
 if action=='build':m.build(opt)
 else:run(opt,sys.argv[3],sys.argv[4] if len(sys.argv)>4 else '')
