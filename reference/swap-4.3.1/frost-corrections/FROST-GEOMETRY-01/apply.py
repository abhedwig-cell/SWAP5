import hashlib,json,pathlib,sys
folder=pathlib.Path(__file__).resolve().parent
manifest=json.loads((folder/'manifest.json').read_text())
source=pathlib.Path(sys.argv[1]).resolve();out=pathlib.Path(sys.argv[2]).resolve()
if source==out:raise SystemExit('original overwrite forbidden')
if hashlib.sha256(source.read_bytes()).hexdigest()!=manifest['base_sha256']:raise SystemExit('wrong exact base')
target=(folder/'frozencond.f90').read_bytes()
if hashlib.sha256(target).hexdigest()!=manifest['target_sha256']:raise SystemExit('wrong exact target')
if out.exists() and out.read_bytes()!=target:raise SystemExit('conflicting output')
out.write_bytes(target)
print('FROST_GEOMETRY_01_EXACT_APPLICATOR=PASS')
