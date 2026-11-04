"""Independent accepted-step reconciliation; a retained scientific failure is never admission."""
import csv,io,json,math,re

def numbers(raw,width):
 rows=[list(map(float,l.split())) for l in raw.splitlines()]
 assert rows and all(len(r)==width and all(map(math.isfinite,r)) for r in rows)
 return rows

def physical(raw):
 pattern=rb'(?m)^\* Generated at: [^\n]*\n'
 assert len(re.findall(pattern,raw))==1
 return re.sub(pattern,b'* Generated at: ACTUAL_TIMESTAMP\n',raw)

def csv_rows(raw):
 return list(csv.DictReader(l for l in raw.decode().splitlines() if not l.startswith('*')))

def intervals(rows,original):
 result=[]
 for r in rows:
  if original:
   if r[0]!=584:continue
   a,b,p,o=r[1],r[1]+r[2],r[3],r[6]
   assert r[2]>0 and min(r[3:9])>=0
   assert abs(r[3]-math.fsum(r[4:9]))<=1e-12
  else:
   if not (r[0]>=583 and r[1]<=584):continue
   a,b,p,o=r[0]-583,r[1]-583,r[2],r[4]
   assert min(r[2:7])>=0 and abs(r[2]-math.fsum(r[3:7]))<=1e-12
  # Original QPROSUM sums up to34 positive nodal potentials; its literal
  # oxygen partition can exceed prescribed PTRA by one summation ulp. Keep
  # those raw values and use the ordinary gamma(n+2) rounding certificate.
  gamma=36*2.220446049250313e-16/(1-36*2.220446049250313e-16)
  assert b>a and p>=0 and o>=0 and o-p<=gamma*p
  result.append((a,b,p,o))
 assert result and result[0][0]==0 and abs(result[-1][1]-1)<=1e-12
 assert all(abs(x[1]-y[0])<=1e-12 for x,y in zip(result,result[1:]))
 assert abs(math.fsum(b-a for a,b,_,_ in result)-1)<=1e-12
 return result

def attribution(original,native):
 # Exactly constant rates on each real accepted interval. No interpolated state,
 # rejected trial, rate filtering or fitted alignment is used.
 i=j=0;potential=[];stress=[];delta=[];duration=[]
 while i<len(original) and j<len(native):
  a,b,p,o=original[i];c,d,q,z=native[j];dt=min(b,d)-max(a,c)
  if dt>0:
   f=o/p if p else 0;g=z/q if q else 0
   potential.append(dt*.5*(q-p)*(g+f));stress.append(dt*.5*(g-f)*(q+p))
   delta.append(dt*(z-o));duration.append(dt)
  if b<=d:i+=1
  else:j+=1
 assert abs(math.fsum(duration)-1)<=1e-12
 p=math.fsum(potential);s=math.fsum(stress);d=math.fsum(delta)
 assert abs(p+s-d)<=1e-15
 return dict(potential_contribution_cm=p,stress_fraction_contribution_cm=s,total_delta_cm=d)

def audit(files,native_raw):
 assert physical(files['original/observed/result_output.csv'])==physical(files['original/unobserved/result_output.csv'])
 assert files['original/observed/hupsel_profiles.csv']==files['original/unobserved/hupsel_profiles.csv']
 for name in ('original_accepted.dat','original_nodes.dat'):
  assert files['original/observed/'+name]==files['micro/case/'+name]
 assert physical(files['micro/case/result_output.csv'])==physical(files['original/unobserved/result_output.csv'])
 assert files['micro/case/hupsel_profiles.csv']==files['original/unobserved/hupsel_profiles.csv']
 rows=numbers(files['original/observed/original_accepted.dat'],15)
 original=intervals(rows,True);native=intervals(numbers(native_raw,9),False)
 assert len(original)==3206 and len(native)==4126
 amount=lambda r:math.fsum((b-a)*o for a,b,_,o in r)
 original_amount=math.fsum(r[2]*r[6] for r in rows if r[0]==584)
 assert abs(amount(original)-original_amount)<=1e-14
 daily=csv_rows(files['original/unobserved/result_output.csv']);assert len(daily)==1097
 assert abs(float(daily[584]['TREDWET'])-original_amount)<=5e-13
 nodes=numbers(files['original/observed/original_nodes.dat'],274)
 assert len(nodes)==len(original)
 accepted=[r for r in rows if r[0]==584]
 stream=io.BytesIO(files['micro/case/original_micro_inputs.dat'])
 for index,(r,node) in enumerate(zip(accepted,nodes)):
  frame=[list(map(float,next(stream).split())) for _ in range(34)]
  assert all(len(x)==24 and all(map(math.isfinite,x)) for x in frame)
  assert [int(x[2]) for x in frame]==list(range(1,35))
  assert all(x[0]==583+r[1] and x[1]==r[2] and x[3]==r[9] and x[4]==r[3] for x in frame)
  assert node[:2]==r[1:3]
  assert [x[17] for x in frame]==node[2:36]
  assert [x[19] for x in frame]==node[240:274]
  assert [x[21] for x in frame]==node[172:206]
  assert abs(math.fsum(x[21] for x in frame)-r[4])<=1e-12
 assert not stream.read().strip()
 decomp=attribution(original,native)
 assert abs(decomp['total_delta_cm']-(amount(native)-original_amount))<=1e-13
 # The bound is imported from the existing recovery/admission surface. It is
 # explicitly a retained failure, not enlarged to accommodate the observation.
 bound=5.371840000016327e-7
 assert abs(decomp['total_delta_cm'])>bound
 return dict(original_accepted_steps=len(original),native_accepted_steps=len(native),
  original_oxygen_cm=original_amount,native_oxygen_cm=amount(native),decomposition=decomp,
  unchanged_oxygen_bound_cm=bound,inside_unchanged_scientific_bound=False,
  actual_original_micro_inputs_bound=True,production_admission=False)

def refusal_controls(files,native):
 import copy
 count=0
 def reject(f,n=native):
  nonlocal count
  try:audit(f,n)
  except (AssertionError,ValueError,StopIteration):count+=1
  else:raise AssertionError('corrupted original evidence accepted')
 f=dict(files);f['original/observed/result_output.csv']=f['original/observed/result_output.csv'].replace(b'TREDWET',b'TREDWEX',1);reject(f)
 f=dict(files);name='micro/case/original_micro_inputs.dat';f[name]=b'NaN '+f[name].split(b' ',1)[1];reject(f)
 f=dict(files);name='original/observed/original_accepted.dat';lines=f[name].splitlines(keepends=True);lines.reverse();f[name]=b''.join(lines);f['micro/case/original_accepted.dat']=f[name];reject(f)
 lines=native.splitlines(keepends=True);reject(files,b''.join(lines[:-1]))
 f=dict(files);name='micro/case/original_nodes.dat';f[name]=f[name][1:];reject(f)
 assert count==5
 return count
