"""Select the registered thermal profile through the sealed original-input runner."""
import hashlib
from pathlib import Path
recipe=Path(__file__).with_name('run_original.py')
expected='9c422629e8b5547d1adaf698b37d67d7dec9e22ce9f25dfdc0df3f5896647d80'
raw=recipe.read_bytes();assert hashlib.sha256(raw).hexdigest()==expected
source=raw.decode();before="cmd=[str(exe),str(a.end),'retain-step','100000']+([str(origin)]if origin else[])";assert source.count(before)==1
source=source.replace(before,"assert json.loads((out/'application.binding').read_text())['grass_numerical_profile']=='thermal-control-1e-5C'\ncmd=[str(exe),str(a.end),'retain-step','100000',str(origin)if origin else'','thermal-control']")
namespace={'__name__':'__main__','__file__':str(recipe)}
exec(compile(source,str(recipe)+'[registered thermal profile]','exec'),namespace)
