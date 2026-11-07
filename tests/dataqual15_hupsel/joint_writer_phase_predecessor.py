"""Scoped reuse of actual complete prior admission, never current peer physics."""
import io,json,zipfile
import joint_writer_phase_production as g
PATH='integration/dataqual15_hupsel/JOINT_WRITER_PR1604_PRESERVATION_20261106.zip'
def verify():
 raw=(g.ROOT/PATH).read_bytes();assert raw==g.raw('HEAD',PATH)
 with zipfile.ZipFile(io.BytesIO(raw))as z:
  assert len(z.namelist())==len(set(z.namelist()));files={p:z.read(p)for p in z.namelist()}
 r=json.loads(files['RESULT.json']);assert r['status']=='EXACT_DEPLOYED_WRITERS_AND_CURRENT_CODECS_WITH_IMMUTABLE_HISTORY_PASS'
 assert r['whole_scientific_admission']is False and r['history_qualifies_current_peer_physics']is False
 assert r['production_trees']=={a:g.blob(g.HISTORY,a)for a in('src','app','reference')}=={a:g.blob(r['head'],a)for a in('src','app','reference')}
 prior_scope=json.loads(g.raw(g.HISTORY,'integration/dataqual15_hupsel/JOINT_WRITER_PRODUCTION_SCOPE_20261106.json'))
 for path,digest in prior_scope['gate_sha256'].items():assert g.sha(g.raw(r['head'],path))==digest==g.sha(g.raw(g.HISTORY,path))
 assert g.raw(r['head'],'integration/dataqual15_hupsel/JOINT_WRITER_PRODUCTION_SCOPE_20261106.json')==g.raw(g.HISTORY,'integration/dataqual15_hupsel/JOINT_WRITER_PRODUCTION_SCOPE_20261106.json')
 expected={'exact-current-private-source-guard','entire-unmodified-admitted-native-history'}|{'current-private-'+p+'-'+o for p in('WINDOWS','POSIX')for o in('O0','O2')}
 assert len(r['events'])==6 and {e['label']for e in r['events']}==expected and all(e['returncode']==0 for e in r['events'])
 for e in r['events']:
  assert e['label']+'.stdout'in files and e['label']+'.stderr'in files
 assert 'native-history/RESULT.json'in files
 assert r['original_consumers']['original_runners']==3 and r['original_consumers']['pond_rollback_consumer_preserved']is True
 assert len(r['exact_before_diagnostics'])==16
 return dict(complete_previous_native_admission_executed=True,source_and_gate_postimages_exact=True,previous_source=g.HISTORY,current_peer_physics_qualified_by_history=False,whole_scientific_admission=False)
