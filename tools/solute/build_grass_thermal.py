"""Build the explicit registered thermal profile through the sealed native recipe.

Creates a fresh numerical-profile application binding before its first native
step. Never changes an existing checkpoint, its binding, or a CRC.
"""
import hashlib,json
from pathlib import Path
RECIPE=Path(__file__).with_name('build_grass_startup.py')
EXPECTED='4ab9bf58d9e05fd9577e4e00e8022ed06335846b1c69608c26e6a2609f484b75'
raw=RECIPE.read_bytes();assert hashlib.sha256(raw).hexdigest()==EXPECTED
source=raw.decode()
def replace(before,after):
 global source
 assert source.count(before)==1,('sealed thermal recipe anchor',before)
 source=source.replace(before,after)
replace("default='ordinary'","default='retained'")
replace("a=p.parse_args();out=", "a=p.parse_args();assert a.policy=='retained','thermal profile is qualified with retained proposal policy';out=")
replace('dict(executable_sha256=sha(exe),compiler=report[',"dict(grass_numerical_profile='thermal-control-1e-5C',executable_sha256=sha(exe),compiler=report[")
replace("[exe,str(a.end)]+(['retain-step']if a.policy=='retained'else[])","[exe,str(a.end),'retain-step','100000','','thermal-control']")
namespace={'__name__':'__main__','__file__':str(RECIPE)}
exec(compile(source,str(RECIPE)+'[registered thermal profile]','exec'),namespace)
path=namespace['out']/'BUILD.json';record=json.loads(path.read_text())
record.update(sealed_recipe_sha256=EXPECTED,thermal_profile_adapter_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),thermal_profile='thermal-control-1e-5C')
path.write_text(json.dumps(record,indent=2)+'\n',newline='\n')
