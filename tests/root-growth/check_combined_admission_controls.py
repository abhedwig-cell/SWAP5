#!/usr/bin/env python3
"""Both scientific proofs are compulsory through every combined admission entry."""
import copy,json,sys
from unittest.mock import patch
import verify_swrd3_successor as swrd3
sys.path[:0]=[str(swrd3.ROOT/'tests/nut-calendar'),str(swrd3.ROOT/'tests/nut-senescence'),str(swrd3.ROOT/'tests/crop-co2'),str(swrd3.ROOT/'tests/nut-input')]
import verify_calendar_successor as calendar
import verify_senescence_successor as senescence
import verify_co2_successor as co2
import verify_input_successor as amendment_input
routes={'swrd3':swrd3.verify_qualification,'calendar':calendar.verify_qualification,'senescence':senescence.verify_qualification,'co2':co2.verify_qualification,'input':amendment_input.verify_qualification}
passed=[]
for name,route in routes.items():
 result=route()
 assert result['qualified'] and result['calendar_successor'] and result['swrd3_successor'] and result['input_successor']
 passed.append(name+':both-proof-positive')
 for label,owner in [('missing-swrd3',swrd3),('missing-calendar',calendar),('missing-input',amendment_input)]:
  target='verify_physical' if owner is swrd3 else 'read_evidence'
  with patch.object(owner,target,side_effect=ValueError('deliberately absent '+label)):
   try:route()
   except ValueError:passed.append(name+':'+label)
   else:raise AssertionError(name+' accepted '+label)
# A source reader supplied by a caller must retain its failure checks through
# the calendar/senescence delegation, including canonical ancestry and postimages.
for name,route in [('calendar',calendar.verify_source),('senescence',senescence.verify_source),('input',amendment_input.verify_source)]:
 def foreign(*args):
  value=swrd3.git(*args)
  return value+'\nA\tsrc/foreign.f90'if args[:2]==('diff','--name-status')else value
 try:route(git_reader=foreign)
 except ValueError:passed.append(name+':foreign-delegated-source')
 else:raise AssertionError(name+' accepted foreign source')
print(json.dumps({'status':'PASS','checks':len(passed),'controls':passed},indent=2))
