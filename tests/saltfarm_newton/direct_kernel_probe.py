"""Private process/pipe replacement; reuses unchanged DailyHost and donor."""
import ctypes as c
import os,shutil
class Native:
 def __init__(self,library,model,transcript):
  self.dll_directory=os.add_dll_directory(str(__import__("pathlib").Path(shutil.which("gfortran")).parent)) if os.name=="nt" else None
  self.lib=c.CDLL(str(library));self.model=model;self.log=transcript;self.queue=[('DAILY_MODEL',[model])];self.handle=c.c_void_p();self.init=[];self.stage=0;self.done=False
  P=c.POINTER(c.c_double);I=c.POINTER(c.c_int)
  self.lib.dk_new.argtypes=[c.c_int,c.c_int,c.c_double,I,P,P,P,c.POINTER(c.c_void_p),I]
  self.lib.dk_request.argtypes=[c.c_void_p,c.c_int,c.c_int,P,I]
  self.lib.dk_apply.argtypes=[c.c_void_p,c.c_int,c.c_int,c.c_int,P,P,I]
  self.lib.dk_free.argtypes=[c.c_void_p]
 def poll(self):return 0 if self.done else None
 def wait(self,**kwargs):return 0
 def terminate(self):
  if not self.done:
   self.lib.dk_free(self.handle);self.handle=c.c_void_p();self.done=True
 def write(self,text):
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
  key,vals=self.queue.pop(0);assert key in prefixes;self.log.write(key+' '+' '.join(vals)+'\n');self.log.flush();return key,{key:vals}
def install(h,library):
 old=(h.start_process,h.send,h.receive)
 def start(stack,command,directory,name):
  if name!='kernel':return old[0](stack,command,directory,name)
  assert command[1]=='HYBRID_SALTFARM_WATER' and command[2]=='explicit-project'
  log=stack.enter_context((directory/'kernel.stdout').open('w'));obj=Native(library,command[1],log);stack.callback(obj.terminate);return obj,log
 def send(p,text):return p.write(text) if isinstance(p,Native) else old[1](p,text)
 def receive(p,log,prefixes):return p.receive(prefixes) if isinstance(p,Native) else old[2](p,log,prefixes)
 h.start_process,h.send,h.receive=start,send,receive
 return old
