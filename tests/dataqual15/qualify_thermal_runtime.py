"""Reuse the real current-runtime O0/O2 build closure; add the changed thermal contract."""
from pathlib import Path
import hashlib,json
recipe=Path(__file__).with_name('qualify_runtime.py');source=recipe.read_text()
needle="providers={}"
assert source.count(needle)==1
source=source.replace(needle,"programs.append(ROOT/'tests/dataqual15/thermal_temporal_driver.f90')\n"+needle)
source=source.replace("CURRENT_REFERENCE_GROUNDWATER_DEFAULT_AND_OXYGEN_PASS","SPRINT03_CURRENT_RUNTIME_AND_THERMAL_TEMPORAL_CONTRACT_PASS")
namespace={'__name__':'__main__','__file__':str(recipe)}
exec(compile(source,str(recipe)+'[thermal contract addition]','exec'),namespace)
path=namespace['out']/'RESULT.json';record=json.loads(path.read_text())
record['recipe_sha256']=hashlib.sha256(recipe.read_bytes()).hexdigest()
record['adapter_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
path.write_text(json.dumps(record,indent=2)+'\n',newline='\n')
