#!/usr/bin/env python3
"""Exercise the real codec via qualified joint executables; native ABI scope."""
import hashlib,json,pathlib,struct,subprocess,sys,time,zlib
out=pathlib.Path(sys.argv[1]).resolve()
records=[]
for opt in ('O0','O2'):
    build=out/opt
    exe=build/'test_matrix_joint'
    raw=(build/'joint-restart.bin').read_bytes()
    n=struct.unpack('i',raw[152:156])[0]
    count=struct.unpack('i',raw[296:300])[0]
    start=300+8*count
    for label,offset,value in (
        ('negative_water',start,-0.1),
        ('nonfinite_concentration',start+8*n,float('nan')),
        ('negative_dissolved',start+16*n,-1.0),
        ('wrong_sorbed_equilibrium',start+24*n,100.0)):
        buf=bytearray(raw[:-4])
        buf[offset:offset+8]=struct.pack('d',value)
        data=bytes(buf)+struct.pack('I',zlib.crc32(buf)&0xffffffff)
        path=build/(label+'.bin')
        path.write_bytes(data)
        begin=time.perf_counter()
        result=subprocess.run([str(exe),'reject',str(path),str(build/'unused.bin')],capture_output=True,text=True)
        records.append({'optimization':opt,'case':label,'seconds':time.perf_counter()-begin,
            'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr,
            'executable_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
            'input_sha256':hashlib.sha256(data).hexdigest()})
        result.check_returncode()
        if 'MATRIX_JOINT_INVALID_FILE=PASS' not in result.stdout:
            raise RuntimeError('missing physical rejection marker: '+label)
receipt={'test_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'records':records}
(out/'physical-decoder-negatives.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('JOINT_RESTART_PHYSICAL_NEGATIVES_O0_O2=PASS')
