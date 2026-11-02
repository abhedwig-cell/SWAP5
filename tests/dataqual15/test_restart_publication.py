"""Native publication and I/O failure controls, independent of the model codec."""
import argparse, ctypes, hashlib, json, os, random, shutil, subprocess, sys, threading, time, zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    compiler=shutil.which('gcc');assert compiler,'gcc required for native platform adapter'
    source=ROOT/'app/support/restart_publish.c';events=[]
    for opt in ['O0','O2']:
        folder=out/opt;folder.mkdir()
        library=folder/('publish.dll' if os.name=='nt' else 'publish.so')
        command=[compiler,'-'+opt,'-std=c11','-Wall','-Wextra','-Werror','-shared',
                 *([] if os.name=='nt' else ['-fPIC']),'-DSWAP5_RESTART_TESTING',str(source),'-o',str(library)]
        begin=time.monotonic();cp=subprocess.run(command,capture_output=True)
        (folder/'compile.stdout').write_bytes(cp.stdout);(folder/'compile.stderr').write_bytes(cp.stderr)
        assert cp.returncode==0,cp.stderr.decode(errors='replace')
        native=ctypes.CDLL(str(library))
        publish=native.swap5_restart_publish;publish.argtypes=[ctypes.c_char_p,ctypes.c_char_p];publish.restype=ctypes.c_int
        inject=native.swap5_restart_publish_test;inject.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];inject.restype=ctypes.c_int
        crc=native.swap5_restart_crc32;crc.argtypes=[ctypes.c_void_p,ctypes.c_size_t];crc.restype=ctypes.c_uint32
        rng=random.Random(431)
        crc_vectors=[b'',b'123456789',bytes(range(256))]+[rng.randbytes(n)for n in [1,2,7,8,9,31,32,33,255,256,257,65535,65536,223790]]
        for payload in crc_vectors:
            buffer=ctypes.create_string_buffer(payload)
            assert crc(buffer,len(payload))==zlib.crc32(payload)
        nested=folder/'nested directory';nested.mkdir()
        target=nested/'checkpoint.bin';pending=Path(str(target)+'.pending')
        paths=(str(pending).encode('utf8'),str(target).encode('utf8'))
        old=b'old CRC-validated generation';new=b'new complete generation'
        # Both first publication and replacement execute the real native APIs.
        pending.write_bytes(old);assert publish(*paths)==0 and target.read_bytes()==old and not pending.exists()
        pending.write_bytes(new);assert publish(*paths)==0 and target.read_bytes()==new and not pending.exists()
        # A separate process observes disk contents, not a live model object.
        observed=subprocess.check_output([sys.executable,'-c',
            'from pathlib import Path;import hashlib,sys;print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())',str(target)],text=True).strip()
        assert observed==sha(target)
        stages=[]
        for stage in [2,3,4,5]:
            target.write_bytes(old);pending.write_bytes(new)
            assert inject(*paths,stage)==stage
            assert target.read_bytes()==old and pending.read_bytes()==new
            stages.append(stage)
        if os.name!='nt':
            assert inject(*paths,6)==6 and target.read_bytes()==new and not pending.exists()
            stages.append(6) # Post-rename directory failure is NOT durable success.
        target.write_bytes(old)
        if pending.exists():pending.unlink()
        assert publish(*paths)==2 and target.read_bytes()==old
        assert publish(None,paths[1])==1
        assert publish(paths[1],paths[1])==1 and target.read_bytes()==old
        pending.write_bytes(new)
        assert publish(paths[0],str(folder/'other.bin').encode())==1 and pending.exists()
        # Windows sharing violations must fail without deleting the old file.
        if os.name=='nt':
            kernel=ctypes.WinDLL('kernel32',use_last_error=True)
            kernel.CreateFileW.argtypes=[ctypes.c_wchar_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p]
            kernel.CreateFileW.restype=ctypes.c_void_p
            kernel.CloseHandle.argtypes=[ctypes.c_void_p];kernel.CloseHandle.restype=ctypes.c_int
            handle=kernel.CreateFileW(str(target),0x80000000,1,None,3,0,None)
            assert handle!=ctypes.c_void_p(-1).value
            try:assert publish(*paths)==5 and target.read_bytes()==old and pending.read_bytes()==new
            finally:assert kernel.CloseHandle(handle)
            # A short polling reader can block MoveFileEx despite sharing flags.
            # It observes the old generation; publication waits for it to close.
            handle=kernel.CreateFileW(str(target),0x80000000,1|2|4,None,3,0,None)
            assert handle!=ctypes.c_void_p(-1).value
            closed=[];timer=None
            try:
                buffer=ctypes.create_string_buffer(len(old));count=ctypes.c_uint32()
                kernel.ReadFile.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_uint32,ctypes.c_void_p,ctypes.c_void_p]
                assert kernel.ReadFile(handle,buffer,len(old),ctypes.byref(count),None)
                assert buffer.raw[:count.value]==old
                timer=threading.Timer(.03,lambda:closed.append(kernel.CloseHandle(handle)))
                timer.start()
                assert publish(*paths)==0 and target.read_bytes()==new
            finally:
                if timer:timer.join();assert closed==[1]
                else:assert kernel.CloseHandle(handle)
        unicode_target=nested/'checkpoint-\u00e9.bin';unicode_pending=Path(str(unicode_target)+'.pending')
        unicode_pending.write_bytes(new)
        assert publish(str(unicode_pending).encode('utf8'),str(unicode_target).encode('utf8'))==0
        assert unicode_target.read_bytes()==new
        events.append(dict(optimization=opt,seconds=time.monotonic()-begin,command=command,
                           library_sha256=sha(library),crc_vectors=len(crc_vectors),fault_stages=stages,status='PASS'))
    result=dict(status='NATIVE_RESTART_PUBLICATION_PASS',platform=os.name,
                source_sha256={source.relative_to(ROOT).as_posix():sha(source)},
                compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],events=events,
                scope='Native flush/replace, actual sharing failure, sibling paths, Unicode and injected failure stages; not a power-loss or whole-project qualification')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()
