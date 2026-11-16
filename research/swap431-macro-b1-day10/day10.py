from pathlib import Path
import sys,importlib.util,json,subprocess,shutil,os,time,re
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-native09';W=Path('C:/Users/Veldh012/swap431-day10-work')
sp=importlib.util.spec_from_file_location('native09',P/'native09.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);m.R=R;m.WORK=W
def run(opt,mode):
 c=W/(opt+'-'+mode);c.mkdir(parents=True,exist_ok=True);assert not (c/'outcome.txt').exists()
 for x in json.loads((P/'CASE_IDENTITY.json').read_text()):
  src=Path('C:/Users/Veldh012/swap431-state02-work/phase/O2/V1/case')/x['path'];assert m.sha(src)==x['sha256'];shutil.copy2(src,c/x['path'])
 src=P/'data'/opt/'B_TRIAL/candidate.end' if mode=='CONTINUE' else R/'data'/opt/'CONTINUE/daycheckpoint.end'
 shutil.copy2(src,c/'own.end')
 s=(c/'swap.swp').read_text(encoding='cp1252');s=re.sub(r'(?mi)^(\s*SWINCO\s*=\s*)2\b',r'\g<1>3',s,count=1)
 s=re.sub(r'(?mi)^\s*TEND\s*=.*$', ' TEND = 1998-01-03',s,count=1)
 s+="\n INIFIL = 'own.end'\n SWINITYPE = 2\n SWENDTYPE = 2\n";(c/'swap.swp').write_text(s,encoding='cp1252')
 env=os.environ.copy();env['DAY10_MODE']=mode;t=time.perf_counter()
 try:
  p=subprocess.run([str(W/'native'/opt/'native09.exe'),'./swap.swp'],cwd=c,env=env,capture_output=True,text=True,timeout=20);q=dict(returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
 except subprocess.TimeoutExpired:q=dict(censored=True,seconds=time.perf_counter()-t)
 m.save(R/(opt+'_'+mode+'_RUN.json'),q);d=R/'data'/opt/mode;d.mkdir(parents=True,exist_ok=True)
 for p in list(c.glob('*.txt'))+list(c.glob('*.end'))+[c/'swap.swp',c/'swap.err',c/'swap.wrn']:
  if p.exists():shutil.copy2(p,d/p.name)
 print(q)
if __name__=='__main__':
 action,opt=sys.argv[1:3]
 if action=='build':m.build(opt)
 else:run(opt,sys.argv[3])
