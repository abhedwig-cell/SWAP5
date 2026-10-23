"""Observe the original chemical rejection with freshly composed HIST providers."""
import hashlib,json,os,resource,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BUILD=Path('/tmp/perf01-owner-current-rejection-probe');BUILD.mkdir()
HIST=Path('/tmp/perf01-owner-current-singular-hist')
es=json.loads((HIST/'events.json').read_text())
link=next(e['command']for e in es if e['category']=='link')
original=ROOT/'tests/nut-crop/test_b112_retained_joint.f90'
needle="  call require(result%status==JOINT_CHEMICAL_REJECTED,'reaction rejects after actual crop preparation')"
text=original.read_text();assert text.count(needle)==1
text=text.replace(needle,"  print *,'PROBE_STATUS',result%status,result%joint%joint%chemical%status,result%joint%joint%chemical%soil%process%status,result%joint%joint%chemical%soil%process%exchange%status\n"+needle)
driver=BUILD/'diagnostic.f90';driver.write_text(text)
flags=link[1:next(i for i,x in enumerate(link)if x.endswith('.o'))]
objects=[x for x in link if x.endswith('.o')][:-1]
events=[];resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
for cmd in [[os.environ['FC'],*flags,'-c',str(driver),'-o',str(BUILD/'driver.o')],[os.environ['FC'],*flags,*objects,str(BUILD/'driver.o'),'-o',str(BUILD/'probe')],[str(BUILD/'probe'),'write',str(BUILD/'state'),str(BUILD/'endpoint')]]:
 start=time.monotonic();r=subprocess.run(cmd,cwd=BUILD,capture_output=True,timeout=180);n=str(len(events))
 for s in ['stdout','stderr']:(BUILD/(n+'.'+s)).write_bytes(getattr(r,s))
 events.append(dict(command=cmd,seconds=time.monotonic()-start,returncode=r.returncode,stdout=n+'.stdout',stderr=n+'.stderr'))
 (BUILD/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stderr.decode()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(BUILD/'inputs.json').write_text(json.dumps({str(p):sha(p)for p in [original,driver,*map(Path,objects)]},indent=2)+'\n')
assert any(line.split()==[b'PROBE_STATUS',b'3',b'3',b'6',b'1']for line in r.stdout.splitlines())
print('CURRENT_ORIGINAL_CHEMICAL_REJECTION_REACHED_PASS')
