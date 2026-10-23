"""Execute the existing HIST assertions with only changed HeadCalc recompiled."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
recipe=ROOT/'integration/audits/reconcile_boesten_nut.py'
text=recipe.read_text()
old="assert drift=={'src/runtime/mod_fmr_serialized_reference_backend.f90','src/runtime/mod_fmr_process_hydraulic_view_binding.f90'},drift"
assert text.count(old)==1
text=text.replace(old,"assert drift=={'src/legacy/b1_10_port/headcalc.f90'},drift")
exec(compile(text,str(recipe),'exec'),dict(__file__=str(recipe),__name__='saturated_picard_current_hist'))
