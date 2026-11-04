"""Additional fail-closed accuracy prerequisite, never a replacement for frozen gates."""
import math
from original_chronology_audit import csv_rows

def assess(coarse,fine,refined,bound,native_amount):
 assert math.isfinite(bound) and bound==5.371840000016327e-7
 assert math.isfinite(native_amount) and native_amount>=0
 levels=[csv_rows(raw) for raw in (coarse,fine,refined)]
 assert len(levels[0])==len(levels[1])==1097 and len(levels[2])==585
 for rows in levels:
  assert len({r['DATE'] for r in rows})==len(rows)
  assert all(math.isfinite(float(r['TREDWET'])) and float(r['TREDWET'])>=0 for r in rows)
 assert all(a['DATE']==b['DATE']==c['DATE'] for a,b,c in zip(*levels))
 assert all(r[584]['DATE']=='2003-08-07' for r in levels)
 changes=[max(abs(float(a['TREDWET'])-float(b['TREDWET'])) for a,b in zip(levels[i],levels[i+1])) for i in range(2)]
 amounts=[float(r[584]['TREDWET']) for r in levels]
 native_error=abs(native_amount-amounts[1])
 reference_eligible=all(x<=bound for x in changes)
 native_inside=native_error<=bound
 # Adding reference qualification cannot convert an existing native FAIL to
 # PASS. No extrapolated value is used as an oracle or an enlarged bound.
 return dict(reference_accuracy_qualified=reference_eligible,
  reference_status='REFERENCE_SELF_CONVERGENCE_PASSED' if reference_eligible else 'REFERENCE_UNDERRESOLVED',
  reference_step_caps_day=[.000625,.0003125,.00015625],reference_day584_oxygen_cm=amounts,
  successive_original_prefix_maximum_changes_cm=changes,unchanged_bound_cm=bound,
  retained_native_comparison_error_cm=native_error,retained_native_comparison_inside_bound=native_inside,
  scientific_admission_permitted=reference_eligible and native_inside,
  source_only_production_admission=False)

def refusal_controls(coarse,fine,refined,bound,native_amount):
 count=0
 trials=[(coarse,fine,refined,bound*2,native_amount),
         (coarse,fine,refined,bound,float('nan')),
         (coarse,fine,b'\n'.join(refined.splitlines()[:-1])+b'\n',bound,native_amount),
         (coarse,fine,refined.replace(b'2003-08-07',b'2003-08-08'),bound,native_amount),
         (coarse,fine,refined.replace(b'TREDWET',b'NO_SUCH'),bound,native_amount)]
 for args in trials:
  try:assess(*args)
  except (AssertionError,ValueError,KeyError):count+=1
  else:raise AssertionError('invalid reference prerequisite accepted')
 assert count==5
 # A perfect match to an underresolved reference must still fail admission.
 result=assess(coarse,fine,refined,bound,float(csv_rows(fine)[584]['TREDWET']))
 assert result['retained_native_comparison_inside_bound'] and not result['reference_accuracy_qualified']
 assert not result['scientific_admission_permitted']
 return count+1
