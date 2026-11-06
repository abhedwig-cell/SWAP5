"""Original physical input/initialization under explicitly corrected sharp-entry graph."""
from pathlib import Path
import hashlib,json,sys
bundle=Path(sys.argv[sys.argv.index('--bundle')+1]).resolve()
meta=json.loads((bundle/'BUILD.json').read_text())
model=meta['contact_model']
assert model in ('ANDELST_SHARP_ENTRY_GRAPH_V1','ANDELST_JOINT_ENTRY_PERCHED_ACTION_GRAPH_V2')
assert all(hashlib.sha256(Path(n).read_bytes()).hexdigest()==h for n,h in meta['source_sha256'].items())
recipe=Path(__file__).with_name('continue_original_andelst.py');source=recipe.read_text()
source=source.replace('command=command,original_sharp_entry=True,','command=command,original_sharp_entry=True,corrected_entry_graph=True,historical_original_equivalence=False,')
source=source.replace('full_original_complete=','full_corrected_complete=')
source=source.replace("record['numerical_controls_observed']=",f"record['full_original_complete']=False\n record['contact_model']={model!r}\n record['numerical_controls_observed']=")
exec(compile(source,str(recipe)+'[corrected graph claim ceiling]','exec'),{'__name__':'__main__','__file__':str(recipe)})
