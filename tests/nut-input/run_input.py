#!/usr/bin/env python3
"""Bounded real four-provider reader; independently generated Gregorian fixtures."""
from pathlib import Path
import datetime,hashlib,json,os,random,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_INPUT_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
events=[]
def run(args,cwd,category):
 start=time.perf_counter();p=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True);i=len(events)
 row=dict(command=list(map(str,args)),category=category,returncode=p.returncode,seconds=time.perf_counter()-start)
 for stream in ['stdout','stderr']:
  b=getattr(p,stream);name=f'{i:04d}.{stream}';(OUT/name).write_bytes(b)
  row[stream+'_file']=name;row[stream+'_sha256']=sha(b)
 events.append(row);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert p.returncode==0,p.stderr.decode()+p.stdout.decode()
 return p.stdout.decode()
header='MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac'
material="1 'Cattle, manure ! sample' 3.16 .5 .02 .01 .02\n2 \"Mineral two\" .99 .2 .03 .02 .03"
eh='smedate iMat Dosagekgha VolatFraction'
base=header+'\n'+material+'\n'+eh+'\n1900-01-01 1 100. .1\n01-JAN-1900 2 200. .2\n1900-01-02 1 300. .3\n'
fixtures={'literal':(base,2,'literal'),'empty':(header+'\n'+material+'\n'+eh+'\n',0,'valid'),
 'comma':(base.replace('MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac','MatNum,MatName,AppAge,OrgMatFrac,OrgNFrac,NH4NFrac,NO3NFrac').replace('smedate iMat Dosagekgha VolatFraction','smedate,iMat,Dosagekgha,VolatFraction'),2,'literal'),
 'comments':('* column-one comment\n\n'+base.replace('\n',' ! trailing\n'),2,'literal')}
bad={
 'trailing_field':base+'garbage\n','missing_header':material+'\n'+eh,
 'partial_header':base.replace('NH4NFrac NO3NFrac','NH4NFrac'),
 'wrong_event_name':base.replace('iMat','MatNum'),'duplicate_material':base.replace('2 "Mineral','1 "Mineral'),
 'unknown_position':base.replace('1900-01-01 1','1900-01-01 3'),
 'zero_position':base.replace('1900-01-01 1','1900-01-01 0'),
 'sparse_ids':base.replace("1 'Cattle","7 'Cattle"),
 'quoted_index':base.replace('1900-01-01 1',"1900-01-01 '1'"),
 'missing_field':base.replace('1 100. .1','1 100.'),
 'empty_comma':base.replace('1 100. .1','1,,100.,.1'),
 'trailing_comma':base.replace('1 100. .1','1,100.,.1,'),
 'extra_field':base.replace('1 100. .1','1 100. .1 0'),
 'unsupported_scalar':base+'X=1\n','unsupported_repeat':base.replace('100.','2*100.'),
 'list_terminator':base.replace('100.','/'),'nan':base.replace('100.','NaN'),
 'infinity':base.replace('100.','Infinity'),'overflow':base.replace('100.','1.e999'),
 'overflow_mantissa':base.replace('100.','99999999999999999999999999999999999999999.'),
 'missing_exponent':base.replace('100.','1.e+'),'multiple_decimal':base.replace('100.','1..0'),
 'negative_dose':base.replace('100.','-1.'),'dose_bound':base.replace('100.','500001.'),
 'negative_volat':base.replace('100. .1','100. -.1'),
 'volat_bound':base.replace('100. .1','100. 1.01'),
 'age_bound':base.replace('3.16','100.1'),'fraction_bound':base.replace('3.16 .5','3.16 1.01'),
 'fraction_negative':base.replace('3.16 .5','3.16 -.1'),
 'bad_month':base.replace('1900-01-01','1900-13-01'),
 'bad_leap':base.replace('1900-01-01','1900-02-29'),
 'time_of_day':base.replace('1900-01-01','1900-01-01_12:00'),
 'past_origin':base.replace('1900-01-01','1899-12-31'),
 'unsorted':base+'1900-01-01 1 100. .1\n',
 'unterminated_name':base.replace("sample'","sample"),
 'long_name':base.replace('Cattle, manure ! sample','A'*26),
 'escaped_quote':base.replace("Cattle, manure ! sample","Cattle''manure"),
 'tabs_in_name':base.replace('Cattle, manure ! sample','Cattle\tmanure'),
 'duplicate_header':base+'\n'+eh+'\n','no_event_header':header+'\n'+material,
 'too_many_lines':base+'\n'*4096,'too_long_record':base+'!'+'x'*2048+'\n',
 'batch_capacity':header+'\n'+material+'\n'+eh+'\n'+('1900-01-01 1 1. 0.\n'*65),
 'material_capacity':header+'\n'+'\n'.join(f"{i} 'M' 1. .5 .02 0. 0."for i in range(1,22))+'\n'+eh,
 'event_capacity':header+'\n'+material+'\n'+eh+'\n'+'\n'.join(f'{(datetime.date(1900,1,1)+datetime.timedelta(days=i)).isoformat()} 1 1. 0.'for i in range(1001))}
fixtures.update({k:(v,-1,'invalid')for k,v in bad.items()})
# Exact capacity edges are legal, independently of the invalid cases above.
fixtures['batch64']=(header+'\n'+material+'\n'+eh+'\n'+('1900-01-01 1 1. 0.\n'*64),64,'valid')
fixtures['events1000']=(bad['event_capacity'].rsplit('\n',1)[0]+'\n',1,'valid')
fixtures['materials20']=(bad['material_capacity'].replace("21 'M' 1. .5 .02 0. 0.\n",''),0,'valid')
fixtures['exponent']=(base.replace('100.','1.0000000000000000D+002'),2,'literal')
for name,(text,_,_)in fixtures.items():(OUT/(name+'.snm')).write_text(text)
start=datetime.date(1900,1,1);end=datetime.date(9999,12,31);rng=random.Random(20261015)
days=[start,end]+[datetime.date(y,m,d)for y in [1900,1999,2000,2004,2100,2400,9999]for m,d in [(1,1),(2,28),(3,1),(12,31)]]
days += [start+datetime.timedelta(days=rng.randrange((end-start).days+1))for _ in range(1500)]
dates=[]
months=['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec']
for day in days:
 for text in [day.isoformat(),f'{day.day:02d}-{months[day.month-1]}-{day.year:04d}']:
  dates.append(f'{text} {(day-start).days}')
for text in ['1900-02-29','2100-02-29','2000-02-30','2001-04-31','1899-12-31','0000-01-01','2000-00-01','2000-01-00','2000-13-01','2000-01-32','01-foo-2000','1-jan-2000','2000/01/01','2000-01-01_00:00','1900-+1-01']:
 dates.append(text+' -1')
(OUT/'dates.txt').write_text('\n'.join(dates)+'\n')
providers=[ROOT/('src/process/'+n+'.f90')for n in ['mod_soil_n_pool_state','mod_b111_soil_n_addition','mod_soil_n_amendment_calendar','mod_soil_n_amendment_input']]
driver=ROOT/'tests/nut-input/test_input.f90';inputs={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in providers+[driver,Path(__file__)]}
r=dict(execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),compiler=run(['gfortran','--version'],OUT,'compiler').splitlines()[0],input_sha256=inputs,runs={},fixture_count=len(fixtures),invalid_count=len(bad),date_cases=len(dates),fixture_sha256={p.name:sha(p.read_bytes())for p in OUT.iterdir()if p.suffix in ['.snm','.txt']})
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objs=[]
 for i,p in enumerate(providers):
  obj=b/f'{i}.o';objs.append(obj);run(['gfortran',*flags,'-c',p,'-o',obj],b,'compile')
 obj=b/'driver.o';run(['gfortran',*flags,'-c',driver,'-o',obj],b,'driver_compile');exe=b/'test_input';run(['gfortran',*flags,*objs,obj,'-o',exe],b,'link')
 r['runs'][opt]={'dates':run([exe,'dates',OUT/'dates.txt'],b,'native'),'fixtures':{}}
 for name,(_,expected,mode)in fixtures.items():
  r['runs'][opt]['fixtures'][name]=run([exe,mode,OUT/(name+'.snm'),'1900-01-01',str(expected)],b,'native')
 r['runs'][opt]['fixtures']['missing_file']=run([exe,'invalid','does-not-exist.snm','1900-01-01','-1'],b,'native')
 r['runs'][opt]['fixtures']['invalid_origin']=run([exe,'invalid',OUT/'literal.snm','1900-02-29','-1'],b,'native')
assert r['runs']['O0']==r['runs']['O2']
r.update(status='PASS',production_providers=4,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items()if k not in ['runs','input_sha256']},indent=2))
