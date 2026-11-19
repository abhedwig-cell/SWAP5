"""Instance-owned direct day executor; original donor remains a private process."""
import ctypes as c
import os,shutil
from pathlib import Path
import hashlib,json,subprocess
PROTOCOL="swap5-direct-day-kernel-1"
MODEL="HYBRID_SALTFARM_WATER"
APP=Path(__file__).resolve().parent
class NativeDayKernel:
 def __init__(self,library,model,transcript):
  self.dll_directory=os.add_dll_directory(str(__import__("pathlib").Path(shutil.which("gfortran")).parent)) if os.name=="nt" else None
  self.cancelled=False
  self.lib=c.CDLL(str(library));self.model=model;self.log=transcript;self.queue=[('DAILY_MODEL',[model])];self.handle=c.c_void_p();self.init=[];self.stage=0;self.done=False
  P=c.POINTER(c.c_double);I=c.POINTER(c.c_int)
  self.lib.dk_new.argtypes=[c.c_int,c.c_int,c.c_double,I,P,P,P,c.POINTER(c.c_void_p),I]
  self.lib.dk_request.argtypes=[c.c_void_p,c.c_int,c.c_int,P,I]
  self.lib.dk_apply.argtypes=[c.c_void_p,c.c_int,c.c_int,c.c_int,P,P,I]
  self.lib.dk_free.argtypes=[c.c_void_p]
 def poll(self):return 0 if self.done or self.cancelled else None
 def kill(self):
  # A watchdog must never free Fortran memory from another thread. The caller
  # kills its donor, unwinds, then terminate frees this context on its owner.
  self.cancelled=True
 def wait(self,**kwargs):return 0
 def terminate(self):
  if not self.done:
   self.lib.dk_free(self.handle);self.handle=c.c_void_p();self.done=True
 def write(self,text):
  if self.cancelled:raise TimeoutError("Direct day kernel cancelled")
  vals=text.split()
  if self.stage==0:self.ncol=int(vals[0]);self.stage=1;return
  if self.stage==1:self.nodes=int(vals[0]);self.epoch=float(vals[1]);self.stage=2;return
  if self.stage==2:
   self.init.append(list(map(float,vals)));self.stage=1
   if len(self.init)==self.ncol:
    ints=(c.c_int*self.ncol)(*(int(x[0]) for x in self.init));totals=(c.c_double*self.ncol)(*(x[1] for x in self.init));stocks=(c.c_double*(6*self.ncol))(*(v for x in self.init for v in x[2:8]));heads=(c.c_double*(self.nodes*self.ncol))(*(v for x in self.init for v in x[8:]));status=c.c_int();self.lib.dk_new(self.ncol,self.nodes,self.epoch,ints,totals,stocks,heads,c.byref(self.handle),c.byref(status));assert status.value==0;self.stage=3
   return
  if self.stage==3:
   col,day=map(int,vals)
   if col==0:self.terminate();return
   out=(c.c_double*2)();status=c.c_int();self.lib.dk_request(self.handle,col,day,out,c.byref(status));assert status.value==0
   self.column=col;self.day=day;self.queue.append(('DAILY_REQUEST',list(map(str,[col,day-1,*out]))));self.stage=4;return
  if self.stage==4:
   data=(c.c_double*len(vals))(*map(float,vals));out=(c.c_double*4)();status=c.c_int();self.lib.dk_apply(self.handle,self.column,self.day,len(vals),data,out,c.byref(status));assert status.value in (0,1),status.value
   key='DAILY_ACCEPTED' if status.value==1 else 'DAILY_REFUSED';self.queue.append((key,list(map(str,[self.column,self.day,int(out[0]),out[1],out[2]]))));self.stage=3
 def receive(self,prefixes):
  if self.cancelled:raise TimeoutError("Direct day kernel cancelled")
  key,vals=self.queue.pop(0);assert key in prefixes;self.log.write(key+' '+' '.join(vals)+'\n');self.log.flush();return key,{key:vals}

def selected(project):
 return project.model==MODEL and not project.macro and not project.input_directory

def library_path(bundle):
 return Path(bundle)/('direct_day_kernel.dll' if os.name=='nt' else 'direct_day_kernel.so')

def sha(path):
 return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def build(bundle,sources,adapter,flags,project):
 if not selected(project):return None
 library=library_path(bundle)
 command=['gfortran',*flags,'-shared',*(['-fPIC'] if os.name!='nt' else []),
          *map(str,sources),str(adapter),str(APP/'direct_day_kernel.f90'),'-o',str(library)]
 subprocess.run(command,cwd=bundle,check=True)
 return dict(protocol=PROTOCOL,model=MODEL,bridge_sha256=sha(APP/'direct_day_kernel.f90'),
             host_sha256=sha(Path(__file__)),library_sha256=sha(library),command=command)

def validate(bundle,identity,project):
 if not selected(project):
  if identity is not None:raise ValueError('Unselected direct day kernel')
  return
 if not identity or identity.get('protocol')!=PROTOCOL or identity.get('model')!=MODEL:
  raise ValueError('Missing or foreign direct day kernel; rebuild without rebinding')
 for key,path in [('bridge_sha256',APP/'direct_day_kernel.f90'),('host_sha256',Path(__file__)),
                  ('library_sha256',library_path(bundle))]:
  if identity.get(key)!=sha(path):raise ValueError('Direct day kernel source/build differs: '+key)

