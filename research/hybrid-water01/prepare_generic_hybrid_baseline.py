"""Actual frozen canonical Andelst controls on the same compiler/runner."""
import argparse
import json
from pathlib import Path
import sys
import time

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',type=Path,required=True)
p.add_argument('--reference',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
sys.path.insert(0,str(a.source_root.resolve()/'app/hybrid_water'))
import daily_host as host
build=a.output/'build';build.mkdir();start=time.monotonic()
profile=dict(budget_retry=True,shared_pond_transfer=True,refresh_macro_final=True)
donor,kernel,case,inputs,identity=host.build(a.reference.resolve(),build,runtime_checkpoint=True,**profile)
binding=host.checkpoint_identity(inputs,identity,**profile)
(build/'BUILD.json').write_text(json.dumps(dict(inputs=inputs,identity=identity,binding=binding),indent=2)+'\n')
for name,cut in [('cut',2),('terminal',4)]:
    out=a.output/name;out.mkdir()
    result=host.run(donor,kernel,case,out,4,runtime=True,publish_day=cut,checkpoint_binding=binding)
    assert result['first_refusal'] is None
origin=a.output/'verified-origin'
receipt=host.verify_checkpoint(a.output/'cut/accepted-column-1-day-2.zip',2,binding,origin)
out=a.output/'resumed';out.mkdir()
result=host.run(donor,kernel,case,out,4,checkpoint_day=2,origin=origin,origin_receipt=receipt,
                runtime=True,publish_day=4,checkpoint_binding=binding)
assert result['first_refusal'] is None
(a.output/'RESULT.json').write_text(json.dumps({'status':'ACTUAL_FROZEN_CANONICAL_ANDELST_CONTROLS_PASS',
    'seconds':time.monotonic()-start,'build':identity},indent=2)+'\n')
print('ACTUAL_FROZEN_CANONICAL_ANDELST_CONTROLS_PASS')
