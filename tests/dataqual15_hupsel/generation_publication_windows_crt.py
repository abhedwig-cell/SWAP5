"""Isolate the existing-target Windows CRT rename failure without altering assertions."""
import argparse,ctypes,json,os
from pathlib import Path
import generation_publication_policy as policy

def main():
 p=argparse.ArgumentParser();p.add_argument('--models',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='nt';policy.guard();a.output.mkdir(parents=True)
 old=(a.models/'incumbent/csv/O0/model.endpoint.csv').read_bytes();new=(a.models/'candidate/csv/O0/model.endpoint.csv').read_bytes()
 crt=ctypes.CDLL('ucrtbase',use_errno=True);rename=crt.rename;rename.argtypes=[ctypes.c_char_p,ctypes.c_char_p];rename.restype=ctypes.c_int;reports=[]
 for exists in (False,True):
  folder=a.output/('existing' if exists else 'absent');folder.mkdir();target=folder/'target.csv';pending=folder/'pending.csv';pending.write_bytes(new)
  if exists:target.write_bytes(old)
  ctypes.set_errno(0);code=rename(os.fsencode(pending),os.fsencode(target));error=ctypes.get_errno()
  assert (code!=0 and error==17 and target.read_bytes()==old and pending.read_bytes()==new) if exists else (code==0 and target.read_bytes()==new and not pending.exists())
  reports.append(dict(existing_target=exists,returncode=code,errno=error,target_sha256=policy.sha(target.read_bytes()),pending_exists=pending.exists()))
 (a.output/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_WINDOWS_CRT_EXISTING_TARGET_EEXIST_ISOLATED',reports=reports,old_sha256=policy.sha(old),new_sha256=policy.sha(new),original_public_failure_retained=True,identical_complete_csv_bytes=old==new,production_admission=False),indent=2)+'\n');print('ACTUAL_WINDOWS_CRT_EXISTING_TARGET_EEXIST_ISOLATED')
if __name__=='__main__':main()
