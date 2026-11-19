"""Actual retained evidence mutations; no model or physics substitute."""
import argparse
import copy
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile
from extended_forensics import inventory,observed,checkpoint,rows,geometry

def main():
    p=argparse.ArgumentParser();p.add_argument('evidence',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    root=a.evidence/'trajectory';data=rows(root/'daily.jsonl');build=json.loads((root/'BUILD.json').read_text());raw=(root/'original/donor.stdout').read_bytes()
    dz=geometry((a.evidence/'input/swap.swp').read_text(encoding='cp1252'))
    refusals=[]
    def refuse(name,callback):
        try:callback()
        except ValueError as e:refusals.append(dict(name=name,refusal=str(e)));return
        raise AssertionError('Accepted forged '+name)
    for key,delta in [('secondary_exchange_cm',.001),('primary_exchange_cm',.001),('stock_end_cm',.001),('prescribed_stage_reaction_cm',.001),('supply_cm',.001)]:
        bad=copy.deepcopy(data);bad[0]['surfacewater'][key]+=delta
        refuse('receipt-'+key,lambda:inventory(bad))
    bad=copy.deepcopy(data);bad[1]['stock_start_cm'][0]+=.001
    refuse('soil-stock-continuity',lambda:inventory(bad))
    # Forge the raw original cumulative level counter independently of its
    # unchanged per-trial wider sum and public accepted receipt.
    lines=raw.decode().splitlines()
    for label,index in [('original-level-counter',14),('accepted-step-count',2),('original-secondary-flux',6)]:
        changed=lines[:]
        at=next(i for i,line in enumerate(changed) if line.startswith('HYBRID_EXTENDED_DRAIN_FLUX '))
        tokens=changed[at].split();tokens[index]=str(float(tokens[index])+1)
        changed[at]=' '.join(tokens)
        refuse('raw-'+label,lambda:observed(('\n'.join(changed)+'\n').encode(),data,build))
    path=next(root.glob('accepted-column-1-day-*.zip'));day=int(path.stem.rsplit('-',1)[1]);row=data[day-1]
    with zipfile.ZipFile(path) as z:members={name:z.read(name) for name in z.namelist()}
    original=members['macro.bin'];size=struct.unpack_from('<i',original,len(original)-4)[0];at=len(original)-size
    for label,offset,fmt,value in [('canopy',28,'d',row['stock_end_cm'][3]+1.),('domain',at+8,'i',25),('clock',at+64,'d',0.),('adjustments',at+80,'i',-1),('stock',at+104,'d',-1.),('duplicate',at+88+(size-92)//2,'d',1.),('trailer',len(original)-4,'i',size+4)]:
        bad=bytearray(original);struct.pack_into('<'+fmt,bad,offset,value)
        forged=dict(members);forged['macro.bin']=bytes(bad);meta=json.loads(forged['checkpoint.json']);meta['files']['macro.bin']=hashlib.sha256(bad).hexdigest();forged['checkpoint.json']=json.dumps(meta).encode()
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as z:
            for name,body in forged.items():z.writestr(name,body)
        refuse('native-rehashed-'+label,lambda:checkpoint(stream.getvalue(),build,row,dz))
    with a.output.open('x',encoding='utf8') as f:json.dump(dict(status='ACTUAL_EVIDENCE_MUTANTS_REFUSED',count=len(refusals),refusals=refusals),f,indent=2)
    print('ACTUAL_EVIDENCE_MUTANTS_REFUSED',len(refusals))

if __name__=='__main__':main()
