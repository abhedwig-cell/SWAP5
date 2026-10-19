"""Rebuild standalone SWAP431 from the retained original archives and output correction."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,zipfile
root=Path(__file__).resolve().parent.parent
identity=json.loads((root/'native/build_identity_v02.json').read_text())
swap=root/'native/source_archives/SWAP.ZIP'
assert hashlib.sha256(swap.read_bytes()).hexdigest()==identity['original_source_zip_sha256']
build=root/'native/rebuild';build.mkdir(exist_ok=True)
with zipfile.ZipFile(swap) as z:z.extractall(build/'source')
with zipfile.ZipFile(root/'native/source_archives/TTUTIL.ZIP') as z:z.extractall(build/'ttutil')
shutil.copyfile(root/'native/source/swap_csv_output.f90',build/'source/SWAP/swap_csv_output.f90')
subprocess.run([sys.executable,str(root/'scripts/build_work.py'),str(build)],check=True)
print(build/'gnu/swap_gnu')
