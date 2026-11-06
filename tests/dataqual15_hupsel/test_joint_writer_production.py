"""Malformed exact production-admission records must fail closed."""
import copy,json
import joint_writer_production as g

def main():
 r=g.guard();cases={}
 def change(label,fn):
  bad=copy.deepcopy(r);fn(bad);cases[label]=bad
 change('pending-execution',lambda d:d.update(phase='EXECUTION_PENDING'))
 change('unknown-scope',lambda d:d.update(scope='ALL_NATIVE_WRITERS'))
 change('scientific-promotion',lambda d:d.update(whole_scientific_admission=True))
 change('writer-expansion',lambda d:d.update(scope='UNBOUNDED_NATIVE_PUBLICATION'))
 change('peer-source-expansion',lambda d:d.update(peer_source_change=True))
 change('portable-abi',lambda d:d.update(binary_abi='PORTABLE'))
 change('unicode-path-admission',lambda d:d.update(windows_path_scope='ALL_PATHS'))
 change('history-as-current-physics',lambda d:d.update(predecessor_scope='CURRENT_PHYSICS'))
 change('boolean-schema',lambda d:d.update(schema=True))
 change('wrong-baseline',lambda d:d.update(current_baseline='0'*40))
 change('wrong-history',lambda d:d.update(native_history='0'*40))
 change('unknown-field',lambda d:d.update(admit_unknown=True))
 change('missing-deployed-source',lambda d:d['production_delta'].pop(g.SOURCES['age']))
 change('wrong-postimage',lambda d:d['postimage_sha256'].update(age='0'*64))
 change('missing-runtime-gate',lambda d:d['gate_sha256'].pop('tests/dataqual15_hupsel/joint_writer_production_runtime.py'))
 change('changed-runtime-gate',lambda d:d['gate_sha256'].update({'tests/dataqual15_hupsel/joint_writer_production_runtime.py':'0'*64}))
 change('missing-reference',lambda d:d['frozen_blobs'].pop(next(iter(d['frozen_blobs']))))
 change('changed-reference',lambda d:d['frozen_blobs'].update({next(iter(d['frozen_blobs'])):'0'*40}))
 change('missing-execution',lambda d:d['execution_sha256'].pop(next(iter(d['execution_sha256']))))
 change('changed-execution',lambda d:d['execution_sha256'].update({next(iter(d['execution_sha256'])):'0'*64}))
 change('missing-current-reference',lambda d:d['frozen_blobs'].pop('integration/dataqual15_hupsel/JOINT_LIMITER_WRITER_WINDOWS_O0_20261106.json'))
 change('changed-current-reference',lambda d:d['frozen_blobs'].update({'integration/dataqual15_hupsel/JOINT_LIMITER_WRITER_WINDOWS_O0_20261106.json':'0'*40}))
 for label,bad in cases.items():
  try:g.validate_record(bad)
  except(AssertionError,KeyError,ValueError,TypeError):pass
  else:raise AssertionError('malformed admission accepted: '+label)
 print(json.dumps(dict(status='EXACT_THREE_WRITER_SOURCE_AND_22_SCOPE_REFUSALS_PASS',scope_refusals=len(cases),whole_scientific_admission=False),sort_keys=True))
if __name__=='__main__':main()
