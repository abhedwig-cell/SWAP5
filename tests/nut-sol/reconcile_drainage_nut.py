"""Reuse the established HIST replay with its narrower one-provider drift."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[2]
recipe=ROOT/'integration/audits/reconcile_boesten_nut.py'
source=recipe.read_bytes()
assert hashlib.sha256(source).hexdigest()=='5a6c8f2758877f5dd30f8e8aea349586332e8da00b2b98f93ce97ab9e7b183a8'
old="assert drift=={'src/runtime/mod_fmr_serialized_reference_backend.f90','src/runtime/mod_fmr_process_hydraulic_view_binding.f90'},drift"
new="assert drift=={'src/runtime/mod_fmr_serialized_reference_backend.f90'},drift"
text=source.decode();assert text.count(old)==1
# No assertions, physical drivers, reuse seals or compile flags are removed.
# The current admitted NUT cache already contains the prior Boesten view change.
exec(compile(text.replace(old,new),str(recipe),'exec'),dict(__file__=str(recipe),__name__='drainage_current_hist'))
