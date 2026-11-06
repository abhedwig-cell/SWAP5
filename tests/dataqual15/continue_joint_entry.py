"""Original physical input/initialization under explicitly corrected sharp-entry graph."""
from pathlib import Path
recipe=Path(__file__).with_name('continue_original_andelst.py');source=recipe.read_text()
source=source.replace('command=command,original_sharp_entry=True,','command=command,original_sharp_entry=True,corrected_entry_graph=True,historical_original_equivalence=False,')
source=source.replace('full_original_complete=','full_corrected_complete=')
source=source.replace("record['numerical_controls_observed']=","record['full_original_complete']=False\n record['contact_model']='ANDELST_SHARP_ENTRY_GRAPH_V1'\n record['numerical_controls_observed']=")
exec(compile(source,str(recipe)+'[corrected graph claim ceiling]','exec'),{'__name__':'__main__','__file__':str(recipe)})
