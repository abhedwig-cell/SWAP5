"""Select explicit diagnostic sources through the sealed Grassgrowth builder.

The historical recipe remains sealed in the original evidence. The current
recipe explicitly includes native durable publication (WP0, 2026-11-02).
This adapter adds source-selection arguments to its hash-verified in-memory recipe; dependency ordering, compiler invocation,
source binding, original inputs and real native execution stay in that recipe.
No model formula, physical state or original input is replaced here.
"""
import hashlib,json
from pathlib import Path

RECIPE=Path(__file__).with_name('build_grass_startup.py')
HISTORICAL_RECIPE='4ab9bf58d9e05fd9577e4e00e8022ed06335846b1c69608c26e6a2609f484b75'
EXPECTED='4a97f6b541cfd5affe69410911678e021a0332cd8c5c50e745df420722fe53c3'
raw=RECIPE.read_bytes()
assert hashlib.sha256(raw).hexdigest()==EXPECTED,'sealed build recipe changed; reconcile adapter explicitly'
source=raw.decode()
def replace(before,after):
 global source
 assert source.count(before)==1,('diagnostic recipe anchor',before)
 source=source.replace(before,after)

replace("p.add_argument('--input-archive',type=Path,help='Optional already-built original TTUTIL archive; otherwise build from the pinned repository authority')","p.add_argument('--input-archive',type=Path,help='Optional already-built original TTUTIL archive; otherwise build from the pinned repository authority')\np.add_argument('--driver',type=Path,required=True)\np.add_argument('--provider-override',type=Path,action='append',default=[])")
replace("context=ROOT/'app/solute_column/link_context.f90';driver=ROOT/'app/grass_project/initial_interval.f90'", "context=ROOT/'app/solute_column/link_context.f90';driver=a.driver.resolve();assert driver.is_file()")
replace("ordered=[];seen=set();active=set()", r"""ordered=[];seen=set();active=set()
for override in a.provider_override:
 override=override.resolve();assert override.is_file()
 names=re.findall(r'^\s*module\s+(\w+)\s*$',override.read_text(),re.M|re.I)
 assert names,('override has no module',override)
 for name in names:
  key=name.lower();assert key in mapping,('override has no existing owner',key)
  mapping[key]=override""")
namespace={'__name__':'__main__','__file__':str(RECIPE)}
exec(compile(source,str(RECIPE)+'[diagnostic source selection]','exec'),namespace)
report_path=namespace['out']/'BUILD.json'
report=json.loads(report_path.read_text())
report['sealed_build_recipe_sha256']=EXPECTED
report['diagnostic_source_adapter_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
report_path.write_text(json.dumps(report,indent=2)+'\n',newline='\n')
