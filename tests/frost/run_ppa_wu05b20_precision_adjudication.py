#!/usr/bin/env python3
"""Independent exact-input 80/100-digit geometry; production remains binary64."""
import argparse
from decimal import Decimal as D, localcontext
import gzip
import hashlib
import json
import math
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PLAN = 'integration/audits/PPA_WU05B20_PRECISION_PREREGISTRATION.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def integral(k,a,b):
    return sum((v*max(D(0),min(b,D(i+1))-max(a,D(i)))
                for i,v in enumerate(k)),D(0))


def inverse(k,start,amount):
    top = start
    for i,v in enumerate(k):
        bottom = D(i+1)
        if bottom <= top:
            continue
        capacity = v*(bottom-top)
        if amount <= capacity:
            return top+amount/v
        amount -= capacity
        top = bottom
    assert abs(amount) < D('1e-60')
    return D(8)


def partition(q,k,gw,spacing,aniso,inf):
    q,k,spacing = [[D.from_float(v) for v in xs] for xs in (q,k,spacing)]
    w = -min(D.from_float(gw),D(0));depth = D(8)-w
    kh = [v*D.from_float(aniso) for v in k]
    fac = ((depth/integral([D(1)/v for v in k],w,D(8)))/
           (integral(kh,w,D(8))/depth)).sqrt()
    spans = [D('.25')*s*fac for s in spacing]
    first = D(math.ceil(w))-w
    factors = [max(D('.5'),first/span) if inf and rate<D('-1e-10') else D(1)
               for rate,span in zip(q,spans)]
    ends = [min(D(8),w+f*span) for f,span in zip(factors,spans)]
    active = [i for i,v in enumerate(q) if abs(v)>D('1e-10')]
    # Explicit native ordinal semantics; geometric integrations are independent.
    for a in range(len(active)-1):
        for b in range(a+1,len(active)):
            if factors[active[a]]*spacing[active[a]] < factors[active[b]]*spacing[active[b]]:
                active[a],active[b] = active[b],active[a]
    cumulative = {i:sum((factors[j]*abs(q[j])*spacing[j] for j in active[n:]),D(0))
                  for n,i in enumerate(active)}
    targets = {}
    for n,i in enumerate(active):
        target = integral(kh,w,D(8)) if n==0 else (
            targets[active[n-1]]*cumulative[i]/cumulative[active[n-1]])
        targets[i] = min(target,integral(kh,w,ends[i]))
    out = [[D(0)]*8 for _ in q]
    for i in active:
        if inf and q[i]<D('-1e-10'):
            uns,sat = integral(kh,D(1),w),integral(kh,w,ends[i])
            total = uns+sat
            for node in range(8):
                a,b = max(D(1),D(node)),min(w,D(node+1))
                if b>a:
                    c,d = integral(kh,D(1),a),integral(kh,D(1),b)
                    out[i][node] = q[i]/total*(d*d-c*c)/uns
                a,b = max(w,D(node)),min(ends[i],D(node+1))
                if b>a:
                    c,d = integral(kh,b,ends[i]),integral(kh,a,ends[i])
                    out[i][node] += q[i]/total*(d*d-c*c)/sat
        else:
            end = inverse(kh,w,targets[i])
            for node in range(8):
                a,b = max(w,D(node)),min(end,D(node+1))
                if b>a:
                    out[i][node] = q[i]*integral(kh,a,b)/targets[i]
    return out


def sequence_sum(values):
    total = 0.
    for value in values:
        total += value
    return total


def geometric_result(case,precision):
    levels,inf,gw,frost,air,bottom = case[:6]
    levels,inf = int(levels),int(inf)
    raw,spacing,aniso = case[6:6+levels],case[9:9+levels],case[12]
    k = [1.,4.]*4
    rf = [0. if -(i+.5)>=frost else 1. for i in range(8)]
    rf[rf.count(0.)] = .5
    with localcontext() as context:
        context.prec = precision
        before = partition(raw,k,gw,spacing,aniso,inf)
        final_bottom = bottom
        if air < .01:
            blocked = [frost<z for z in (-3.,-4.7,-6.3)[:levels]]
            rates = [0. if b else q for q,b in zip(raw,blocked)]
            total = sequence_sum(rates)
            if abs(total)<1e-6:
                if blocked[-1]:
                    final_bottom = 0.
                else:
                    rates[-1] = bottom
            else:
                rates = [q*(1.+bottom/total) for q in rates]
            modified = [v*r+(1.-r)*1e-10 for v,r in zip(k,rf)]
            after = partition(rates,modified,min(gw,frost),spacing,aniso,inf)
        else:
            after = [[v*D.from_float(r) for v,r in zip(row,rf)] for row in before]
        return before,after,final_bottom


def main():
    ap = argparse.ArgumentParser();ap.add_argument('--evidence',required=True)
    args = ap.parse_args()
    plan = json.loads((ROOT/PLAN).read_text())
    prior_bytes = (ROOT/plan['sealed_prior_evidence']['path']).read_bytes()
    assert sha(prior_bytes) == plan['sealed_prior_evidence']['sha256']
    prior = json.loads(gzip.decompress(prior_bytes))
    for path,identity in prior['source_sha256'].items():
        assert sha((ROOT/path).read_bytes()) == identity,path
    build = Path(tempfile.mkdtemp(prefix='ppa-wu05b20-precision-'))
    overlay = ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03'
    manifest = json.loads((overlay/'manifest.json').read_text())
    candidate = build/'candidate.f90'
    subprocess.run(['python3',str(overlay/'apply.py'),str(ROOT/manifest['parent']['path']),str(candidate)],check=True)
    assert sha(candidate.read_bytes()) == prior['candidate_source_sha256']
    files = [ROOT/'tests/frost/test_ppa_wu05b20_multilevel_globals.f90',candidate,
             ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90',
             ROOT/'tests/frost/test_ppa_wu05b20_multilevel_owner.f90']
    receipts = {}
    for opt in (0,2):
        d=build/f'o{opt}';d.mkdir()
        command=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all',
                 '-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),
                 *map(str,files),'-o',str(d/'test')]
        subprocess.run(command,check=True,cwd=d)
        p=subprocess.run([str(d/'test')],input=prior['inputs'],text=True,capture_output=True,cwd=d)
        assert p.returncode==0 and p.stdout==prior['outputs']['candidate']
        receipts[f'o{opt}']=dict(exit_code=0,cases=9216,command=command,
            executable_sha256=sha((d/'test').read_bytes()),stdout_sha256=sha(p.stdout.encode()),
            stderr=p.stderr,sealed_prior_output_identity=True)
        print(f'B20_FRESH_CANDIDATE_O{opt}_9216_SEALED_OUTPUT_IDENTITY=PASS',flush=True)
    cases=[list(map(float,line.split()[1:])) for line in prior['inputs'].splitlines()]
    rows=prior['outputs']['candidate'].splitlines()
    maxima=dict(absolute_partition_error=0.,unit_rate_partition_error=0.,
                decimal_80_100_error=0.,scalar_error=0.,native_nodal_scalar_residual=0.)
    details=[];original_failed={x['case']for x in prior['precision_findings']['candidate']}
    for id,(case,line) in enumerate(zip(cases,rows),1):
        values=list(map(float,line.split()));n=int(case[0])
        native_before=[values[1+8*i:9+8*i]for i in range(n)]
        native_after=[values[28+8*i:36+8*i]for i in range(n)]
        actual_rates=values[25:25+n]
        before,after,bottom=geometric_result(case,80)
        before100,after100,_=geometric_result(case,100)
        with localcontext() as context:
            context.prec=110
            stability=max(abs(a-b) for x,y in zip(before+after,before100+after100)for a,b in zip(x,y))
            assert stability<D('1e-25'),(id,stability)
            error=max(abs(D.from_float(a)-b)for x,y in zip(native_before+native_after,before+after)for a,b in zip(x,y))
            norm=max(abs(D.from_float(a)-b)/max(abs(D.from_float(rate)),D('1e-10'))
                     for x,y,rate in zip(native_before+native_after,before+after,case[6:6+n]+actual_rates)
                     for a,b in zip(x,y))
            assert norm<D('2e-12'),(id,float(error),float(norm))
            scalar_error=max(abs(sum(row,D(0))-D.from_float(rate))for row,rate in zip(after,actual_rates))
            assert scalar_error<D('1e-14')and bottom==values[52],(id,scalar_error)
        closure=max(abs(math.fsum(row)-rate)for row,rate in zip(native_after,actual_rates))
        assert closure<1e-14,(id,closure)
        for key,value in [('absolute_partition_error',error),('unit_rate_partition_error',norm),
                          ('decimal_80_100_error',stability),('scalar_error',scalar_error),
                          ('native_nodal_scalar_residual',closure)]:
            maxima[key]=max(maxima[key],float(value))
        if id in original_failed:
            details.append(dict(case=id,unit_rate_error=float(norm),absolute_error=float(error)))
    assert len(details)==645
    record=dict(work_unit='PPA-WU05B20',phase='HIGH_PRECISION_GEOMETRIC_ADJUDICATION',
                qualified_reference_partition=True,runtime_admitted=False,
                aggregate_frost_migration_complete=False,source_tree=plan['source_tree'],
                prior_evidence=plan['sealed_prior_evidence'],cases=9216,decimal_digits=[80,100],
                criteria=plan['fixed_criteria'],maxima=maxima,receipts=receipts,
                all645_prior_screen_failures_resolved_without_source_or_tolerance_change=True,
                resolved_cases=details,
                source_sha256={str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes()),
                               PLAN:sha((ROOT/PLAN).read_bytes())},
                interpretation='The double oracle lost relative digits in a tiny depth round trip. Independent exact-input 80/100-digit geometric integration resolves the prior precision screens. Original evidence stays immutable; no production or reference arithmetic/tolerance changes. Mixed-sign transfer authority remains separate.')
    data=gzip.compress((json.dumps(record,sort_keys=True)+'\n').encode(),mtime=0)
    Path(args.evidence).write_bytes(data)
    print(json.dumps(dict(cases=9216,maxima=maxima,evidence_sha256=sha(data),bytes=len(data),build=str(build)),indent=2))


if __name__=='__main__':
    main()
