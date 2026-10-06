#!/usr/bin/env python3
"""Test-only alternative signed transfer; never imports into production or promotes B1."""
import argparse
from decimal import Decimal as D, localcontext
import gzip
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
from run_ppa_wu05b20_precision_adjudication import partition, sequence_sum

ROOT = Path(__file__).resolve().parents[2]
PLAN = 'integration/audits/PPA_WU05B20_NET_TRANSFER_PROPOSAL_PLAN.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def proposal_source(original):
    declaration = b'      real(8)           :: volair,ksatcp(macp),qdratot\r\n'
    beginning = b'            if (abs(qdratot) < 1.0d-6) then\r\n'
    end = b'            if (swdivd == 1)'
    assert original.count(declaration) == original.count(beginning) == 1
    a = original.index(beginning);b = original.index(end,a)
    old = original[a:b]
    prefix = ('            if (minval(qdrain(1:nrlevs)) < -1.0d-10 .AND. &\r\n'
              '                maxval(qdrain(1:nrlevs)) > 1.0d-10) then\r\n'
              '               qdrabs = sum(abs(qdrain(1:nrlevs)))\r\n'
              '               do level = 1,nrlevs\r\n'
              '                  qdrain(level) = qdrain(level) + qbot * abs(qdrain(level)) / qdrabs\r\n'
              '               end do\r\n'
              '            else\r\n').encode()
    candidate = original[:a]+prefix+old+b'            end if\r\n\r\n'+original[b:]
    candidate = candidate.replace(declaration,declaration.replace(b'qdratot',b'qdratot,qdrabs'))
    return candidate,dict(old_branch_sha256=sha(old),retained_old_branch=old.decode(),
                          new_prefix=prefix.decode(),scratch_candidate_sha256=sha(candidate))


def independent(case,precision):
    n,inf,gw,frost,air,bottom = case[:6];n,inf=int(n),int(inf)
    raw,spacing,aniso = case[6:6+n],case[9:9+n],case[12]
    rf = [0. if -(i+.5)>=frost else 1. for i in range(8)];rf[rf.count(0.)]=.5
    retained = raw.copy();altered=False
    with localcontext() as context:
        context.prec=precision
        before=partition(raw,[1.,4.]*4,gw,spacing,aniso,inf)
        final_bottom=bottom
        if air<.01:
            blocked=[frost<z for z in (-3.,-4.7,-6.3)[:n]]
            retained=[0. if b else v for v,b in zip(raw,blocked)]
            rates=retained.copy()
            if min(rates)<-1e-10 and max(rates)>1e-10:
                altered=True;absolute=sequence_sum(abs(v)for v in rates)
                rates=[v+bottom*abs(v)/absolute for v in rates]
            else:
                total=sequence_sum(rates)
                if abs(total)<1e-6:
                    if blocked[-1]:final_bottom=0.
                    else:rates[-1]=bottom
                else:rates=[v*(1.+bottom/total)for v in rates]
            k=[v*r+(1.-r)*1e-10 for v,r in zip([1.,4.]*4,rf)]
            after=partition(rates,k,min(gw,frost),spacing,aniso,inf)
        else:
            after=[[v*D.from_float(r)for v,r in zip(row,rf)]for row in before]
            rates=None
    return before,after,final_bottom,altered,retained,rates


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--evidence',required=True);args=ap.parse_args()
    prior_path=ROOT/'docs/audits/evidence/PPA_WU05B20_MULTILEVEL_REFERENCE_REPLAY.json.gz'
    data=prior_path.read_bytes();assert sha(data)=='b9722a11a7684247b90cd34e3c38e27337fbd7a9d36e43888f9893ec8bd6b368'
    prior=json.loads(gzip.decompress(data))
    precision_path=ROOT/'docs/audits/evidence/PPA_WU05B20_PRECISION_ADJUDICATION.json.gz'
    precise_data=precision_path.read_bytes();assert sha(precise_data)=='ce69b00c117acd6892a1f19aa9a2b75a03eb14e36c71e5a6e714d5b6e34d5e38'
    precision=json.loads(gzip.decompress(precise_data))
    for path,identity in {**prior['source_sha256'],**precision['source_sha256']}.items():
        assert sha((ROOT/path).read_bytes())==identity,path
    original_path=ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90'
    original=original_path.read_bytes();assert sha(original)=='edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf'
    scratch_source,patch_record=proposal_source(original)
    build=Path(tempfile.mkdtemp(prefix='ppa-wu05b20-net-proposal-'))
    frozen=build/'proposal.f90';frozen.write_bytes(scratch_source)
    divdra=build/'divdra03.f90'
    overlay=ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03'
    subprocess.run(['python3',str(overlay/'apply.py'),str(ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02/divdra.f90'),str(divdra)],check=True)
    outputs={};receipts={}
    for opt in(0,2):
        d=build/f'o{opt}';d.mkdir()
        files=[ROOT/'tests/frost/test_ppa_wu05b20_multilevel_globals.f90',divdra,frozen,
               ROOT/'tests/frost/test_ppa_wu05b20_multilevel_owner.f90']
        command=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all',
                 '-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),
                 *map(str,files),'-o',str(d/'test')]
        subprocess.run(command,check=True,cwd=d)
        p=subprocess.run([str(d/'test')],input=prior['inputs'],text=True,capture_output=True,cwd=d)
        assert p.returncode==0
        outputs[f'o{opt}']=p.stdout
        receipts[f'o{opt}']=dict(exit_code=0,cases=9216,command=command,stdout_sha256=sha(p.stdout.encode()),
                                stderr=p.stderr,executable_sha256=sha((d/'test').read_bytes()))
        print(f'B20_TEST_ONLY_TRANSFER_PROPOSAL_O{opt}_9216=PASS',flush=True)
    assert outputs['o0']==outputs['o2']
    cases=[list(map(float,line.split()[1:]))for line in prior['inputs'].splitlines()]
    rows=outputs['o0'].splitlines();original_rows=prior['outputs']['candidate'].splitlines()
    assert len(rows)==9216
    counts=dict(altered_cases=0,byte_exact_unaltered_controls=0)
    maxima=dict(unit_rate_geometry_error=0.,decimal_80_100_error=0.,nodal_scalar_residual=0.,
                altered_signed_net_error=0.,scalar_law_error=0.)
    witnesses={}
    for id,(case,line,old_line)in enumerate(zip(cases,rows,original_rows),1):
        v=list(map(float,line.split()));n=int(case[0]);rates=v[25:25+n]
        before=[v[1+8*i:9+8*i]for i in range(n)]
        after=[v[28+8*i:36+8*i]for i in range(n)]
        b,a,bottom,altered,retained,expected_rates=independent(case,80)
        b100,a100,*_=independent(case,100)
        with localcontext()as context:
            context.prec=110
            stability=max(abs(x-y)for row,expected in zip(b+a,b100+a100)for x,y in zip(row,expected))
            error=max(abs(D.from_float(x)-y)/max(abs(D.from_float(rate)),D('1e-10'))
                for row,expected,rate in zip(before+after,b+a,case[6:6+n]+rates)for x,y in zip(row,expected))
            assert stability<D('1e-25')and error<D('2e-12'),(id,stability,error)
            scalar_error=max(abs(sum(row,D(0))-D.from_float(rate))for row,rate in zip(a,rates))
            assert scalar_error<D('1e-14')and bottom==v[52]
            net_error=D(0)
            if altered:
                # Independent physical signed-net identity, not source arithmetic.
                net_error=abs(D.from_float(bottom)-sum((D.from_float(x)for row in after for x in row),D(0))+
                              sum(map(D.from_float,retained),D(0)))
                assert net_error<D('1e-14'),(id,net_error)
        closure=max(abs(math.fsum(row)-rate)for row,rate in zip(after,rates))
        assert closure<1e-14
        for key,value in [('unit_rate_geometry_error',error),('decimal_80_100_error',stability),
                          ('nodal_scalar_residual',closure),('altered_signed_net_error',net_error),
                          ('scalar_law_error',scalar_error)]:
            maxima[key]=max(maxima[key],float(value))
        if altered:
            counts['altered_cases']+=1
            assert line!=old_line or case[5]==0.
        else:
            counts['byte_exact_unaltered_controls']+=1
            assert line==old_line,(id,'unaffected source difference')
        if id in(5,6,7):
            witnesses[str(id)]=dict(input=case,original_final_rates=list(map(float,old_line.split()))[25:25+n],
                                   proposed_final_rates=rates,bottom=bottom,
                                   net_bottom_minus_nodal=bottom-math.fsum(x for row in after for x in row),
                                   raw_survivor_net=math.fsum(retained))
    preservation={}
    prior_status=json.loads((ROOT/'integration/audits/PPA_WU05B17_REF_STATUS.json').read_text())
    corpus_data=(ROOT/prior_status['evidence']['path']).read_bytes();assert sha(corpus_data)==prior_status['evidence']['sha256']
    corpus=json.loads(gzip.decompress(corpus_data));inputs=corpus['manifest']['actual/cases.txt']['content']
    expected=corpus['manifest']['actual/corrected/o0/output.txt']['content']
    for opt in(0,2):
        d=build/'B17-preservation'/f'o{opt}';d.mkdir(parents=True)
        files=[ROOT/'tests/frost/test_ppa_wu05b16_divdra_globals.f90',divdra,frozen,
               ROOT/'tests/frost/test_ppa_wu05b16_divdra_owner.f90']
        command=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all',
                 '-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),
                 *map(str,files),'-o',str(d/'test')]
        subprocess.run(command,check=True,cwd=d)
        p=subprocess.run([str(d/'test')],input=inputs,text=True,capture_output=True,cwd=d)
        assert p.returncode==0 and p.stdout==expected
        preservation[f'o{opt}']=dict(cases=4536,exit_code=0,command=command,
            stdout_sha256=sha(p.stdout.encode()),executable_sha256=sha((d/'test').read_bytes()),
            immutable_B17_output_identity=True)
    assert sha(original_path.read_bytes())==sha(original)
    record=dict(work_unit='PPA-WU05B20',proposal='FROST-MULTILEVEL-NET01',
                status='TEST_ONLY_POLICY_PROPOSAL_COMPLETE_OWNER_DECISION_REQUIRED',
                cases=9216,counts=counts,maxima=maxima,witnesses=witnesses,O0_O2_identity=True,
                receipts=receipts,preservation=preservation,output=outputs['o0'],patch=patch_record,
                parent_evidence_sha256=sha(data),precision_evidence_sha256=sha(precise_data),
                source_sha256={PLAN:sha((ROOT/PLAN).read_bytes()),
                               str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes())},
                production_modified=False,reference_authority_modified=False,
                admitted=False,runtime_admitted=False,aggregate_frost_migration_complete=False,
                interpretation='Concrete scratch-only full-source alternative. Mixed-sign bottom transfer is distributed by absolute retained-rate weights, preserving the raw net proposal and avoiding signed-total amplification. Unaltered source branches remain exact. This is an owner-reviewable policy difference, not a B1 correction or runtime qualification.')
    output_data=gzip.compress((json.dumps(record,sort_keys=True)+'\n').encode(),mtime=0)
    Path(args.evidence).write_bytes(output_data)
    print(json.dumps(dict(cases=9216,counts=counts,maxima=maxima,witnesses=witnesses,
                         evidence_sha256=sha(output_data),bytes=len(output_data),build=str(build)),indent=2))


if __name__=='__main__':main()
