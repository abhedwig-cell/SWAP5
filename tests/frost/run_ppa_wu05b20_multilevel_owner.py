#!/usr/bin/env python3
"""Full native multilevel source evidence, independent integral oracle, no kernel mutation."""
import argparse
import gzip
import hashlib
import itertools
import json
import math
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PLAN = 'integration/audits/PPA_WU05B20_PREREGISTRATION.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def integral(k, a, b):
    return sum(v * max(0., min(b, i+1.) - max(a, float(i)))
               for i, v in enumerate(k))


def literal_sum(values):
    # Python3.12 sum(float) is compensated; the native FrozenBounds scalar
    # loop is a left-to-right binary64 reduction. Near cancellation matters.
    total = 0.
    for value in values:
        total += value
    return total


def inverse_integral(k, start, amount):
    """Independent exact layerwise inverse, not the original compartment loops."""
    top = start
    for i, v in enumerate(k):
        bottom = i+1.
        if bottom <= top:
            continue
        capacity = v * (bottom-top)
        if amount <= capacity:
            return top + amount/v
        amount -= capacity
        top = bottom
    assert abs(amount) < 1e-12
    return 8.


def partition(q, k, gw, spacing, aniso, inf, original):
    """Joint discharge-layer target integrals, followed by cell overlap integrals."""
    w = -min(gw, 0.)
    hor = [v*aniso for v in k]
    depth = 8.-w
    fac = math.sqrt((depth/integral([1./v for v in k], w, 8.)) /
                    (integral(hor, w, 8.)/depth))
    first = math.ceil(w)-w
    f = [max(.5, first/(.25*s*fac)) if inf and v < -1e-10 else 1.
         for v, s in zip(q, spacing)]
    ends = [min(8., w+.25*s*fac*z) for s, z in zip(spacing, f)]
    active = [i for i, v in enumerate(q) if abs(v) > 1e-10]
    # Stable descending order is part of this bounded source comparison.
    active.sort(key=lambda i: f[i]*spacing[i], reverse=True)
    cumulative = {i: sum(f[j]*abs(q[j])*spacing[j] for j in active[n:])
                  for n, i in enumerate(active)}
    target = {}
    for n, i in enumerate(active):
        proposed = integral(hor, w, 8.) if n == 0 else (
            target[active[n-1]]*cumulative[i]/cumulative[active[n-1]])
        target[i] = min(proposed, integral(hor, w, ends[i]))
    out = [[0.]*8 for _ in q]
    for i in active:
        if inf and q[i] < -1e-10:
            uns = integral(hor, 1., w)
            sat = integral(hor, w, ends[i])
            total = uns+sat
            for node in range(8):
                a, b = max(1., float(node)), min(w, node+1.)
                if b > a and uns > (1e-8 if original else 0.):
                    c, d = integral(hor, 1., a), integral(hor, 1., b)
                    out[i][node] = q[i]/total*(d*d-c*c)/uns
                a, b = max(w, float(node)), min(ends[i], node+1.)
                if b > a:
                    c, d = integral(hor, b, ends[i]), integral(hor, a, ends[i])
                    out[i][node] += q[i]/total*(d*d-c*c)/sat
        else:
            end = inverse_integral(hor, w, target[i])
            for node in range(8):
                a, b = max(w, float(node)), min(end, node+1.)
                if b > a:
                    out[i][node] = q[i]*integral(hor, a, b)/target[i]
    return out


def matrix():
    rates = {2: [(0.,0.,0.), (.01,.02,0.), (-.01,-.02,0.),
                 (.01,-.004,0.), (.01,-.01,0.), (.01,-.0099995,0.),
                 (.01,-.0099985,0.), (0.,.02,0.)],
             3: [(0.,0.,0.), (.01,.02,.03), (-.01,-.02,-.03),
                 (.01,-.004,.02), (.01,.02,-.03), (.01,.02,-.0299995),
                 (.01,.02,-.0299985), (0.,.02,-.02)]}
    for levels in (2,3):
        for inf, gw, frost, air, bottom, spacing, aniso, raw in itertools.product(
                (0,1), (-2.25,-3.25), (-2.5,-4.5,-6.5), (.001,.02),
                (-.002,0.,.002), ((20.,40.,60.),(60.,20.,40.),
                                (20.,20.,20.),(6.,10.,14.)), (.5,2.), rates[levels]):
            yield [levels,inf,gw,frost,air,bottom,*raw,*spacing,aniso]


def same_compartment_infiltration(q, k, gw, spacing, aniso, inf):
    if not inf:
        return False
    w = -min(gw,0.); depth = 8.-w
    hor = [v*aniso for v in k]
    fac = math.sqrt((depth/integral([1./v for v in k],w,8.)) /
                    (integral(hor,w,8.)/depth))
    for rate, space in zip(q,spacing):
        if rate >= -1e-10:
            continue
        span = .25*space*fac
        end = min(8.,w+span*max(.5,(math.ceil(w)-w)/span))
        if math.ceil(w) == math.ceil(end):
            return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--evidence', required=True)
    args = ap.parse_args()
    plan = json.loads((ROOT/PLAN).read_text())
    for path, identity in plan['immutable_sources'].items():
        assert sha((ROOT/path).read_bytes()) == identity, path
    assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip() == plan['baseline_source']
    assert not subprocess.check_output(['git','diff','--name-only',plan['baseline'],'--','src'],cwd=ROOT,text=True).strip()
    cases = list(matrix())
    inputs = ''.join(str(i)+' '+' '.join(format(v,'.17g') for v in c)+'\n'
                     for i,c in enumerate(cases,1))
    build = Path(tempfile.mkdtemp(prefix='ppa-wu05b20-owner-'))
    (build/'cases.txt').write_text(inputs)
    common = ['tests/frost/test_ppa_wu05b20_multilevel_globals.f90',
              'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90',
              'tests/frost/test_ppa_wu05b20_multilevel_owner.f90']
    sources = {'original':'reference/swap-4.3.1/b1_11_frost_source/SWAP/divdra.f90',
               'corrected':'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02/divdra.f90'}
    correction = ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03'
    candidate = build/'candidate.f90'
    subprocess.run(['python3',str(correction/'apply.py'),str(ROOT/sources['corrected']),
                    str(candidate)],check=True)
    sources['candidate'] = str(candidate)
    receipts, outputs, failures = {}, {}, {}
    for variant, source in sources.items():
        for opt in (0,2):
            d = build/variant/f'o{opt}'
            d.mkdir(parents=True)
            files = [common[0],source,*common[1:]]
            command = ['gfortran','-std=f2008','-ffree-line-length-none',
                       '-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}',
                       '-J',str(d),'-I',str(d),*[str(ROOT/f) for f in files],'-o',str(d/'test')]
            subprocess.run(command,check=True,cwd=d)
            key = f'{variant}/o{opt}'
            remaining = inputs.splitlines(); complete = []; negative = []
            attempts = []
            while remaining:
                p = subprocess.run([str(d/'test')],input='\n'.join(remaining)+'\n',
                                   text=True,capture_output=True,cwd=d)
                rows = p.stdout.splitlines()
                assert [int(r.split()[0]) for r in rows] == [int(r.split()[0]) for r in remaining[:len(rows)]]
                complete.extend(rows)
                attempts.append(dict(exit_code=p.returncode,complete_rows=len(rows),
                                     stdout_sha256=sha(p.stdout.encode()),stderr=p.stderr))
                if p.returncode == 0:
                    assert len(rows) == len(remaining)
                    remaining = []
                else:
                    assert len(rows) < len(remaining)
                    negative.append(dict(case=int(remaining[len(rows)].split()[0]),
                                         input=remaining[len(rows)],exit_code=p.returncode,stderr=p.stderr))
                    remaining = remaining[len(rows)+1:]
            stdout = '\n'.join(complete)+'\n'
            (d/'output.txt').write_text(stdout)
            receipts[key] = dict(command=command,attempts=attempts,
                executable_sha256=sha((d/'test').read_bytes()),stdout_sha256=sha(stdout.encode()),
                completed_cases=len(complete),negative_cases=len(negative))
            failures[key] = negative
            outputs[key] = stdout
            assert len(complete)+len(negative) == len(cases)
            if variant == 'candidate':
                assert not negative,(key,negative[:1])
            print(f'B20_{variant.upper()}_O{opt}_CENSUS_COMPLETE positive={len(complete)} negative={len(negative)}',flush=True)
        assert outputs[f'{variant}/o0'] == outputs[f'{variant}/o2']
        assert [f['case'] for f in failures[f'{variant}/o0']] == [f['case'] for f in failures[f'{variant}/o2']]
    maxima = dict(partition_error=0.,candidate_partition_error=0.,candidate_unit_rate_partition_error=0.,
                  corrected_nodal_scalar_residual=0.,scalar_error=0.,
                  independent_single_level_superposition_error=0.,cancellation_net_departure=0.)
    witnesses = {}
    precision_findings = {variant:[] for variant in sources}
    affected_cases = set()
    candidate_rows = {int(line.split()[0]):line for line in outputs['candidate/o0'].splitlines()}
    unchanged_controls = 0
    for variant in sources:
        rows = outputs[f'{variant}/o0'].splitlines()
        assert len(rows)+len(failures[f'{variant}/o0']) == len(cases)
        for line in rows:
            values = list(map(float,line.split()))
            id = int(values[0]); case = cases[id-1]
            assert len(values) == 53 and values[0] == id
            levels,inf,gw,frost,air,bottom = case[:6]
            raw,spacing,aniso = case[6:9],case[9:12],case[12]
            q = raw[:levels]; s = spacing[:levels]
            before = [values[1+8*i:9+8*i] for i in range(levels)]
            final_scalar = values[25:25+levels]
            after = [values[28+8*i:36+8*i] for i in range(levels)]
            final_bottom = values[52]
            k = [1.,4.]*4
            expected_before = partition(q,k,gw,s,aniso,inf,variant=='original')
            affected = same_compartment_infiltration(q,k,gw,s,aniso,inf)
            rf = [0. if -(i+.5)>=frost else 1. for i in range(8)]
            rf[rf.count(0.)] = .5
            expected_bottom = bottom
            retained = q.copy()
            if air < .01:
                blocked = [frost < z for z in (-3.,-4.7,-6.3)[:levels]]
                retained = [0. if b else v for v,b in zip(q,blocked)]
                total = literal_sum(retained)
                expected_scalar = retained.copy()
                deepest = levels-1
                if abs(total) < 1e-6:
                    if blocked[deepest]:
                        expected_bottom = 0.
                    else:
                        expected_scalar[deepest] = bottom
                else:
                    expected_scalar = [v*(1.+bottom/total) for v in retained]
                modified = [v*r+(1.-r)*1e-10 for v,r in zip(k,rf)]
                expected_after = partition(expected_scalar,modified,min(gw,frost),s,aniso,inf,variant=='original')
                affected = affected or same_compartment_infiltration(expected_scalar,modified,min(gw,frost),s,aniso,inf)
            else:
                expected_after = [[v*r for v,r in zip(row,rf)] for row in expected_before]
                scalar_basis = expected_before if variant == 'candidate' else before
                expected_scalar = [literal_sum(v*r for v,r in zip(row,rf)) for row in scalar_basis]
            error = max(abs(a-b) for ar,br in zip(before+after,expected_before+expected_after)
                        for a,b in zip(ar,br))
            maxima['partition_error'] = max(maxima['partition_error'],error)
            if affected:
                affected_cases.add(id)
            normalized_error = max(abs(a-b)/max(abs(rate),1e-10)
                for ar,br,rate in zip(before+after,expected_before+expected_after,q+expected_scalar)
                for a,b in zip(ar,br))
            # The partition is linear in each supplied signed rate. Compare its
            # dimensionless unit-rate weights, also when near-cancellation
            # amplifies the actual rate beyond the original single-level probes.
            if variant == 'candidate':
                maxima['candidate_partition_error'] = max(maxima['candidate_partition_error'],error)
                maxima['candidate_unit_rate_partition_error'] = max(maxima['candidate_unit_rate_partition_error'],normalized_error)
                if normalized_error >= 2e-12:
                    precision_findings[variant].append(dict(case=id,absolute_error=error,unit_rate_error=normalized_error))
            elif not affected:
                if normalized_error >= 2e-12:
                    precision_findings[variant].append(dict(case=id,absolute_error=error,unit_rate_error=normalized_error))
            if variant == 'corrected' and not affected:
                assert line == candidate_rows[id],('unaffected control changed',id)
                unchanged_controls += 1
            scalar_error = max(abs(a-b) for a,b in zip(final_scalar,expected_scalar))
            maxima['scalar_error'] = max(maxima['scalar_error'],scalar_error)
            assert scalar_error < 1e-14 and final_bottom == expected_bottom,(variant,id,case,scalar_error,final_bottom,expected_bottom)
            if variant == 'candidate':
                residual = max(abs(sum(row)-v) for row,v in zip(after,final_scalar))
                maxima['corrected_nodal_scalar_residual'] = max(maxima['corrected_nodal_scalar_residual'],residual)
                assert residual < 1e-14,(id,case,residual)
                independent = [partition([v],k,gw,[sp],aniso,inf,False)[0] for v,sp in zip(q,s)]
                difference = max(abs(a-b) for ar,br in zip(before,independent) for a,b in zip(ar,br))
                maxima['independent_single_level_superposition_error'] = max(maxima['independent_single_level_superposition_error'],difference)
                if difference > 1e-5 and 'joint_distribution' not in witnesses:
                    witnesses['joint_distribution'] = dict(case=id,input=case,native_before=before,independent_before=independent,max_nodal_difference=difference)
                if air < .01 and abs(sum(retained)) < 1e-6 and not blocked[-1]:
                    departure = (final_bottom-sum(final_scalar))-(-sum(retained))
                    maxima['cancellation_net_departure'] = max(maxima['cancellation_net_departure'],abs(departure))
                    if abs(sum(retained)) < 1e-14 and abs(departure) > 1e-5 and 'exact_cancellation' not in witnesses:
                        witnesses['exact_cancellation'] = dict(case=id,input=case,retained_raw=retained,final_scalar=final_scalar,final_nodal=after,final_bottom=final_bottom,net_bottom_minus_nodal=final_bottom-sum(map(sum,after)),net_departure=departure)
                    if 1e-14 < abs(sum(retained)) < 1e-6 and abs(departure) > 1e-5 and 'below_threshold' not in witnesses:
                        witnesses['below_threshold'] = dict(case=id,input=case,retained_raw=retained,final_scalar=final_scalar,final_bottom=final_bottom,net_departure=departure)
                if air < .01 and 1e-6 < abs(sum(retained)) < 2e-6 and not blocked[-1] and 'above_threshold' not in witnesses:
                    witnesses['above_threshold'] = dict(case=id,input=case,retained_raw=retained,final_scalar=final_scalar,final_bottom=final_bottom,net_departure=(final_bottom-sum(final_scalar))+sum(retained))
    assert set(witnesses) == {'joint_distribution','exact_cancellation','below_threshold','above_threshold'}
    supplements = {}
    one_level = '1 1 1 -2.25 -2.5 .001 -.002 0 0 0 20 40 60 .5\n'
    for variant in sources:
        for opt in (0,2):
            key = f'{variant}/o{opt}'
            p = subprocess.run([str(build/variant/f'o{opt}/test')],input=one_level,
                               text=True,capture_output=True)
            supplements['single_level/'+key] = dict(exit_code=p.returncode,input=one_level,
                                                    stdout=p.stdout,stderr=p.stderr)
            assert (p.returncode == 0) == (variant == 'candidate')
            if variant == 'candidate':
                row = list(map(float,p.stdout.split()))
                expected = partition([-.002],[v*r+(1.-r)*1e-10 for v,r in
                    zip([1.,4.]*4,[0.,0.,0.,.5,1.,1.,1.,1.])],-2.5,[20.],.5,1,False)[0]
                assert max(abs(a-b) for a,b in zip(row[28:36],expected)) < 1e-14
    # Inherit no preexisting source outputs by assertion alone: execute the
    # complete immutable B17 single-level matrix again with its actual driver.
    prior_status = json.loads((ROOT/'integration/audits/PPA_WU05B17_REF_STATUS.json').read_text())
    prior_data = (ROOT/prior_status['evidence']['path']).read_bytes()
    assert sha(prior_data) == prior_status['evidence']['sha256']
    prior = json.loads(gzip.decompress(prior_data))
    prior_input = prior['manifest']['actual/cases.txt']['content']
    prior_output = prior['manifest']['actual/corrected/o0/output.txt']['content']
    for opt in (0,2):
        d = build/'single-level-preservation'/f'o{opt}';d.mkdir(parents=True)
        files = [ROOT/'tests/frost/test_ppa_wu05b16_divdra_globals.f90',candidate,
                 ROOT/common[1],ROOT/'tests/frost/test_ppa_wu05b16_divdra_owner.f90']
        command = ['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all',
                   '-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),
                   *map(str,files),'-o',str(d/'test')]
        subprocess.run(command,check=True,cwd=d)
        p = subprocess.run([str(d/'test')],input=prior_input,text=True,capture_output=True,cwd=d)
        assert p.returncode == 0 and p.stdout == prior_output
        supplements[f'B17_4536/o{opt}'] = dict(exit_code=0,cases=4536,command=command,
            executable_sha256=sha((d/'test').read_bytes()),stdout_sha256=sha(p.stdout.encode()),
            input_sha256=sha(prior_input.encode()),immutable_output_identity=True,stderr=p.stderr)
    occupied = build/'occupied.f90';occupied.write_bytes(b'occupied')
    bad = build/'bad.f90';bad.write_bytes((ROOT/sources['corrected']).read_bytes()+b'! wrong')
    for source,target in [(bad,build/'should-not-exist.f90'),
                          (ROOT/sources['corrected'],ROOT/sources['corrected']),
                          (ROOT/sources['corrected'],occupied)]:
        p = subprocess.run(['python3',str(correction/'apply.py'),str(source),str(target)],
                           text=True,capture_output=True)
        assert p.returncode != 0
    assert occupied.read_bytes() == b'occupied' and not (build/'should-not-exist.f90').exists()
    sources_to_seal = list(dict.fromkeys([PLAN,*list(sources.values())[:2],*common,
        str(Path(__file__).relative_to(ROOT)),str((correction/'apply.py').relative_to(ROOT)),
        str((correction/'manifest.json').relative_to(ROOT)),
        'tests/frost/test_ppa_wu05b16_divdra_globals.f90',
        'tests/frost/test_ppa_wu05b16_divdra_owner.f90',
        'integration/audits/PPA_WU05B20_CORRECTION_PREREGISTRATION.json']))
    record = dict(work_unit='PPA-WU05B20',status='MULTILEVEL_REFERENCE_PROBE_COMPLETE_RUNTIME_OWNER_DECISION_REQUIRED',
                  baseline=plan['baseline'],production_source_tree=plan['baseline_source'],production_mutation=False,
                  runtime_admitted=False,aggregate_frost_migration_complete=False,cases_per_variant_optimization=len(cases),
                  complete_source_case_attempts=6*len(cases),O0_O2_byte_identity=True,
                  independent_oracle_passed=not precision_findings['candidate'],
                  independent_comparison_unit_rate_criterion=2e-12,
                  precision_findings=precision_findings,
                  source_sha256={f:sha((ROOT/f).read_bytes()) for f in sources_to_seal},
                  input_sha256=sha(inputs.encode()),inputs=inputs,receipts=receipts,
                  outputs={variant:outputs[f'{variant}/o0'] for variant in sources},failures=failures,
                  candidate_source=candidate.read_text(),candidate_source_sha256=sha(candidate.read_bytes()),
                  supplements=supplements,hash_and_overwrite_guards_passed=True,
                  maxima=maxima,witnesses=witnesses,affected_same_compartment_cases=len(affected_cases),
                  byte_exact_unaffected_B17_controls=unchanged_controls,
                  interpretation='Nodal/scalar closure is not lost in corrected reference. Mixed-sign near-zero aggregate triggers deepest-level replacement, retaining other levels and changing the net bottom-minus-drainage proposal. Whether that is intended physical transfer or a legacy defect is not established by code parity; a new runtime mass/flux interpretation requires owner decision.')
    evidence = Path(args.evidence)
    evidence.write_bytes(gzip.compress((json.dumps(record,sort_keys=True)+'\n').encode(),mtime=0))
    print(json.dumps(dict(status=record['status'],cases=len(cases),maxima=maxima,
                         evidence_sha256=sha(evidence.read_bytes()),evidence_bytes=evidence.stat().st_size,
                         build=str(build),witnesses=witnesses),indent=2),flush=True)


if __name__ == '__main__':
    main()
