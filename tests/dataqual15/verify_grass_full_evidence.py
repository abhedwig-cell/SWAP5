"""Verify the terminal original1827-day capsule, preserving the old521 receipt."""
import argparse,json
from pathlib import Path
from grass_full_capsule import SPEC,read_json,output_paths,verify
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--spec',type=Path,default=SPEC);p.add_argument('--capsule',type=Path);p.add_argument('--manifest',type=Path);p.add_argument('--output',type=Path);a=p.parse_args()
 result=verify(*output_paths(read_json(a.spec),a.capsule,a.manifest))
 if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items()if k not in ['B0_harvest_at_checkpoints','B1_harvest_at_checkpoints','nodal_profiles']},indent=2))
