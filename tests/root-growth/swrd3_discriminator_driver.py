"""Expose the legal AERATECRIT=1 boundary as a short physical discriminator."""
from swrd3_cycle_driver import prepare as ordinary

def prepare(root,target,enabled=True):
 ordinary(root,target,enabled);s=target.read_text()
 for a,b in [('aeration_critical_factor=.4_real64','aeration_critical_factor=1._real64'),
             ('aggregates%deepest_root_oxygen_factor_integral<.4_real64','aggregates%deepest_root_oxygen_factor_integral<1._real64')]:
  assert s.count(a)==(2 if a.startswith('aggregates%')else 1),a;s=s.replace(a,b)
 # The same source gate uses strict '<'. This is a test parameter, not a
 # numerical tolerance or default crop calibration. Require actual suppression.
 if enabled:
  a="      print '(a)','SWRD3_ACTUAL_RICHARDS_ANAEROBIC_ROOT_DEATH=PASS'"
  b=a+"\n      write(*,'(a,es24.16)')'SWRD3_PROBE_ACCEPTED_OXYGEN=',aggregates%deepest_root_oxygen_factor_integral"
  assert s.count(a)==1;s=s.replace(a,b)
 target.write_text(s);return target
