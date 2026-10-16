#!/usr/bin/env python3
"""Positive fresh process and corrupt continuation controls on the existing codec."""
import argparse,json,struct,subprocess,time
from pathlib import Path
a=argparse.ArgumentParser();a.add_argument('--exe',required=True);a.add_argument('--artifact',required=True);a.add_argument('--output',required=True);args=a.parse_args()
out=Path(args.output);out.mkdir(parents=True,exist_ok=False);exe=str(Path(args.exe).resolve());source=Path(args.artifact).read_text();records=[]
def run(name,text,reject):
 p=out/(name+'.restart');p.write_text(text)
 t=time.monotonic();r=subprocess.run([exe,'--reject' if reject else '--read',str(p.resolve())],capture_output=True,text=True)
 (out/(name+'.stdout')).write_text(r.stdout);(out/(name+'.stderr')).write_text(r.stderr)
 ok=r.returncode==0 and ('CLASSIC_CORRUPT_CODEC_REJECTED' if reject else 'CLASSIC_FRESH_PROCESS_DEAD_BITS') in r.stdout
 records.append({'name':name,'exit':r.returncode,'seconds':time.monotonic()-t,'pass':ok})
 return r
r=run('nonzero_fresh',source,False)
values=dict(line.split(maxsplit=1) for line in source.splitlines() if ' ' in line)
expected=' '.join(f'{int(values[k])&((1<<64)-1):016X}' for k in ['dead_root_bits','dead_stem_bits','dead_leaf_bits'])
assert expected in r.stdout,'fresh process did not retain exact counters'
run('unknown_codec',source.replace('codec 2\n','codec 99\n',1),True)
run('truncated_counter',source.replace('dead_leaf_bits '+values['dead_leaf_bits']+'\n','',1),True)
neg=struct.unpack('q',struct.pack('d',-1.0))[0]
nan=struct.unpack('q',struct.pack('d',float('nan')))[0]
run('negative_counter',source.replace('dead_root_bits '+values['dead_root_bits'],'dead_root_bits '+str(neg),1),True)
run('nonfinite_counter',source.replace('dead_leaf_bits '+values['dead_leaf_bits'],'dead_leaf_bits '+str(nan),1),True)
run('missing_biomass',source.replace('biomass_present 1\n','biomass_present 0\n',1),True)
legacy='\n'.join(line for line in source.replace('codec 2\n','codec 1\n',1).splitlines() if not line.startswith(('dead_root_bits ','dead_stem_bits ','dead_leaf_bits ')))+'\n'
r=run('legacy_v1',legacy,False)
assert '0000000000000000 0000000000000000 0000000000000000' in r.stdout,'legacy default representation changed'
result={'controls':records,'all_pass':all(r['pass'] for r in records),'scope':'Existing classic qualification codec2 preserves nonzero gross diagnostics across fresh process; corrupt data rejects; v1 explicitly restores admitted zero-counter representation, not unrecorded historical mortality.'}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));raise SystemExit(0 if result['all_pass'] else 1)
