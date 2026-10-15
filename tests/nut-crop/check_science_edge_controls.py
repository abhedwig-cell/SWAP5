"""Negative proof controls for supplementary native crop science."""
import copy,json
import verify_crop_supply_successor as v
import verify_science_edges as edges
primary=v.read_evidence();data=edges.read(v.ROOT)
edges.validate(v.ROOT,primary,data);passed=[]
for label,mutate in [
 ('unfinished_edges',lambda r:r.update(status='RUNNING')),
 ('wrong_edge_binding',lambda r:r.update(primary_result_sha256='0'*64)),
 ('missing_juvenile_proof',lambda r:r['runs']['O0'].update(stdout='')),
 ('edge_provider_drift',lambda r:r['runs']['O2']['artifacts_after'].update({'foreign.o':'0'*64})),
]:
 mutant=copy.deepcopy(data);r=json.loads(mutant['result.json']);mutate(r);mutant['result.json']=json.dumps(r).encode()
 try:edges.validate(v.ROOT,primary,mutant)
 except ValueError:passed.append(label);continue
 raise AssertionError('accepted negative '+label)
for label,mutate in [('missing_edge_native',lambda e:e.pop()),('unchecked_edges',lambda e:e[0]['command'].remove('-fcheck=all'))]:
 mutant=copy.deepcopy(data);e=json.loads(mutant['events.json']);mutate(e);mutant['events.json']=json.dumps(e).encode()
 try:edges.validate(v.ROOT,primary,mutant)
 except ValueError:passed.append(label);continue
 raise AssertionError('accepted negative '+label)
print(json.dumps(dict(status='PASS',negative_count=len(passed),controls=passed),indent=2))
