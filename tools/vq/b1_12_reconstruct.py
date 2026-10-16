#!/usr/bin/env python3
"""Reconstruct B1.12 from canonical B0, or the immutable qualified B1.11 authority."""
from pathlib import Path
import argparse,base64,hashlib,importlib.util,io,json,tarfile
ROOT=Path(__file__).resolve().parents[2]
AUTHORITY=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
AUTHORITY_SHA256='18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c'
def helper():
 p=ROOT/'reference/swap-4.3.1/patches/SWAP-019/apply_and_verify.py'
 s=importlib.util.spec_from_file_location('swap019_apply',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def from_authority(output_dir,authority=AUTHORITY):
 h=helper();raw=base64.b64decode(Path(authority).read_bytes(),validate=False)
 h.require(h.sha(raw)==AUTHORITY_SHA256,'immutable B1.11 archive identity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=[m for m in t.getmembers()if m.isfile()and m.name.startswith('SWAP/')]
  h.require(len(members)==63 and len({m.name for m in members})==63,'authority member count')
  h.require(all(len(Path(m.name).parts)==2 for m in members),'unsafe authority member')
  data={Path(m.name).name:t.extractfile(m).read()for m in members}
 h.require(h.sha(h.manifest(data))==h.PREDECESSOR_MANIFEST,'qualified predecessor identity')
 output_dir=Path(output_dir);output_dir.mkdir(parents=True,exist_ok=False)
 for n,b in data.items():(output_dir/n).write_bytes(b)
 return finish(output_dir,'IMMUTABLE_QUALIFIED_B111_ARCHIVE')
def finish(output_dir,route):
 h=helper();targets=h.apply_tree(output_dir)
 return {'snapshot':'B1.12','qualified_reconstruction':True,'route':route,'predecessor':'B1.11','patch':'SWAP-019','targets':targets,'source_tree':{'member_count':63,'bytes':1886750,'manifest_sha256':h.SOURCE_MANIFEST},'B0_full_archive_replay_this_run':route=='CANONICAL_B0_ORDERED_CHAIN'}
def reconstruct(archive,output_dir):
 try:from .b1_11_reconstruct import reconstruct as prior
 except ImportError:from b1_11_reconstruct import reconstruct as prior
 result=prior(Path(archive),Path(output_dir))
 helper().require(result['qualified_reconstruction'] and result['source_tree']['manifest_sha256']==helper().PREDECESSOR_MANIFEST,'B1.11 reconstruction rejected')
 return finish(Path(output_dir),'CANONICAL_B0_ORDERED_CHAIN')
def main():
 p=argparse.ArgumentParser();g=p.add_mutually_exclusive_group(required=True);g.add_argument('--archive',type=Path);g.add_argument('--qualified-b111-authority',action='store_true');p.add_argument('--output-dir',type=Path,required=True);a=p.parse_args()
 print(json.dumps(reconstruct(a.archive,a.output_dir)if a.archive else from_authority(a.output_dir),indent=2))
if __name__=='__main__':main()
