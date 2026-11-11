"""Bounded Windows x64 primary-thread sampling of the unchanged Grass release.

No instrumentation or foreign checkpoint rebinding. Every suspended thread is
resumed in finally. Counts are exclusive sampled instruction pointers, not calls.
"""
import argparse
import bisect
from collections import Counter
import ctypes as c
from ctypes import wintypes as w
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import time


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle', type=Path, required=True)
    p.add_argument('--origin', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--nm', type=Path, required=True)
    a = p.parse_args()
    assert os.name == 'nt' and struct.calcsize('P') == 8
    sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
    b = json.loads((a.bundle/'BUILD.json').read_text())
    exe = a.bundle/b['executable']
    assert sha(exe) == b['executable_sha256']
    assert all(sha(Path(f)) == h for f,h in b['source_sha256'].items())
    assert b['grass_numerical_profile'] == 'thermal-subcycle4-1e-5C'
    a.output.mkdir()
    for f,h in b['original_inputs_sha256'].items():
        source = a.bundle/'original-interval'/f
        assert sha(source) == h
        shutil.copyfile(source,a.output/f)
    shutil.copyfile(a.bundle/'original-interval/application.binding',a.output/'application.binding')
    shutil.copyfile(a.origin,a.output/'restart-origin.bin')
    symbols_raw = subprocess.run([str(a.nm),'-n','--defined-only',str(exe)],
                                 check=True,capture_output=True).stdout
    (a.output/'symbols.txt').write_bytes(symbols_raw)
    symbols = []
    for line in symbols_raw.decode().splitlines():
        parts = line.split()
        if len(parts)==3 and parts[1] in ('T','t'):
            symbols.append((int(parts[0],16),parts[2]))
    symbols.sort()
    addresses = [s[0] for s in symbols]
    pe = exe.read_bytes()
    pe_start = struct.unpack_from('<I',pe,60)[0]
    assert struct.unpack_from('<H',pe,pe_start+24)[0] == 0x20b
    preferred = struct.unpack_from('<Q',pe,pe_start+24+24)[0]
    k = c.WinDLL('kernel32',use_last_error=True)
    def api(name,restype,*args):
        f=getattr(k,name);f.restype=restype;f.argtypes=list(args);return f
    snapshot=api('CreateToolhelp32Snapshot',w.HANDLE,w.DWORD,w.DWORD)
    close=api('CloseHandle',w.BOOL,w.HANDLE)
    class Thread(c.Structure):
        _fields_=[('size',w.DWORD),('usage',w.DWORD),('tid',w.DWORD),('pid',w.DWORD),
                  ('base',w.LONG),('delta',w.LONG),('flags',w.DWORD)]
    first=api('Thread32First',w.BOOL,w.HANDLE,c.POINTER(Thread))
    next_thread=api('Thread32Next',w.BOOL,w.HANDLE,c.POINTER(Thread))
    open_thread=api('OpenThread',w.HANDLE,w.DWORD,w.BOOL,w.DWORD)
    suspend=api('SuspendThread',w.DWORD,w.HANDLE)
    resume=api('ResumeThread',w.DWORD,w.HANDLE)
    context=api('GetThreadContext',w.BOOL,w.HANDLE,w.LPVOID)
    thread_times=api('GetThreadTimes',w.BOOL,w.HANDLE,*([c.POINTER(w.FILETIME)]*4))
    enum_modules=api('K32EnumProcessModules',w.BOOL,w.HANDLE,w.LPVOID,w.DWORD,c.POINTER(w.DWORD))
    module_name=api('K32GetModuleFileNameExW',w.DWORD,w.HANDLE,w.HMODULE,w.LPWSTR,w.DWORD)
    class Module(c.Structure):
        _fields_=[('base',w.LPVOID),('size',w.DWORD),('entry',w.LPVOID)]
    module_info=api('K32GetModuleInformation',w.BOOL,w.HANDLE,w.HMODULE,c.POINTER(Module),w.DWORD)
    def modules(process):
        handles=(w.HMODULE*1024)();needed=w.DWORD()
        if not enum_modules(process,handles,c.sizeof(handles),c.byref(needed)):
            raise c.WinError(c.get_last_error())
        result=[]
        for handle in handles[:needed.value//c.sizeof(w.HMODULE)]:
            name=c.create_unicode_buffer(32768);info=Module()
            if module_name(process,handle,name,len(name)) and module_info(process,handle,c.byref(info),c.sizeof(info)):
                result.append(dict(path=name.value,base=info.base,size=info.size))
        return result
    cmd=[str(exe.resolve()),'190','retain-step','100000',str(a.origin.resolve()),'thermal-control-4']
    env=os.environ.copy();env['OMP_NUM_THREADS']='1'
    report=dict(executable_sha256=sha(exe),origin_sha256=sha(a.origin),command=cmd,
                method='Windows x64 primary-thread exclusive RIP samples; nearest defined text symbol; no call-count or inclusive-time claim',
                interval_seconds=.007,hard_cap_seconds=120)
    (a.output/'LAUNCH.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
    counts=Counter();ips=Counter();thread=None;proc=None;error=None;censored=False
    start=time.monotonic()
    with (a.output/'stdout').open('wb') as so,(a.output/'stderr').open('wb') as se:
        try:
            proc=subprocess.Popen(cmd,cwd=a.output,stdout=so,stderr=se,env=env)
            time.sleep(.05)
            snap=snapshot(4,0);entry=Thread();entry.size=c.sizeof(entry);targets=[]
            try:
                ok=first(snap,c.byref(entry))
                while ok:
                    if entry.pid==proc.pid:
                        handle=open_thread(0x004a,False,entry.tid)
                        if handle:
                            ts=[w.FILETIME() for _ in range(4)]
                            if thread_times(handle,*[c.byref(x) for x in ts]):
                                targets.append(((ts[0].dwHighDateTime<<32)|ts[0].dwLowDateTime,entry.tid,handle))
                            else:close(handle)
                    ok=next_thread(snap,c.byref(entry))
            finally:close(snap)
            assert targets,'No sampleable primary thread'
            targets.sort();_,tid,thread=targets[0]
            for _,_,handle in targets[1:]:close(handle)
            report.update(pid=proc.pid,primary_tid=tid,initial_thread_count=len(targets))
            loaded=modules(int(proc._handle));report['modules']=loaded
            image=next(m for m in loaded if Path(m['path']).resolve()==exe.resolve())
            buffer=c.create_string_buffer(1232+15);aligned=(c.addressof(buffer)+15)&~15
            # Native winnt.h AMD64 CONTEXT: flags at48, Rip at248, aligned16.
            while proc.poll() is None:
                if time.monotonic()-start>120:
                    proc.kill();censored=True;break
                old=suspend(thread)
                if old==0xffffffff:
                    if proc.poll() is not None:break
                    raise c.WinError(c.get_last_error())
                try:
                    assert old==0,'Thread was already suspended'
                    c.c_uint32.from_address(aligned+48).value=0x100001
                    if not context(thread,aligned):raise c.WinError(c.get_last_error())
                    rip=c.c_uint64.from_address(aligned+248).value
                finally:
                    if resume(thread)==0xffffffff:raise c.WinError(c.get_last_error())
                ips[rip]+=1
                if image['base']<=rip<image['base']+image['size']:
                    address=rip-image['base']+preferred;i=bisect.bisect_right(addresses,address)-1
                    name=symbols[i][1] if i>=0 else 'UNMAPPED_MAIN_IMAGE'
                else:
                    owner=next((Path(m['path']).name for m in loaded if m['base']<=rip<m['base']+m['size']),'UNMAPPED_EXTERNAL')
                    name='EXTERNAL:'+owner
                counts[name]+=1
                time.sleep(.007)
            proc.wait(timeout=5)
        except Exception as e:
            error=repr(e)
            if proc is not None and proc.poll() is None:proc.kill();proc.wait()
        finally:
            if thread:close(thread)
    report.update(status='SAMPLED' if error is None and not censored and proc.returncode==0 else 'FAILED_OR_CENSORED',
                  error=error,censored=censored,returncode=proc.returncode if proc else None,
                  wall_seconds=time.monotonic()-start,samples=sum(counts.values()),
                  exclusive_counts=counts.most_common(),instruction_pointer_counts={hex(k):v for k,v in ips.items()})
    (a.output/'PROFILE.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('modules','instruction_pointer_counts')}))
    if report['status']!='SAMPLED':raise SystemExit(1)


if __name__=='__main__':main()
