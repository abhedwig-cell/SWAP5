"""Independently inspect actual malicious policy/source fixtures and refusals."""
import hashlib
from pathlib import Path

from ordinary_pond_evidence import read, require, digest


def audit(path):
    path=Path(path);q=read(path/'RESULT.json')
    require(q['status']=='ACTUAL_ORDINARY_SOURCE_AND_POLICY_REFUSALS_BEFORE_WORKER_PASS' and
            q['model_executions']==q['compilations']==0 and q['original_BUILD_unchanged'] is True,
            'Incomplete actual ordinary refusal campaign')
    top_fields={'top-deadband','top-missing-chain','top-inexact-root','top-unrelated'}
    head_fields={'head-double-chain','head-wrong-form','head-unrelated'}
    fields=[]
    for r in q['refusals']:
        name=r['field'];fields.append(name);folder=path/name;meta=read(folder/'BUILD.json')
        require(r['actual']==r['expected'] and r['before_worker'] is r['no_publication'] is True,
                'Actual refusal diagnostic/scope differs')
        require(not list(folder.rglob('donor.stdout')) and not list(folder.rglob('accepted-*.zip')),
                'Malicious fixture started a worker or published')
        if name.startswith('policy-'):
            key=name[len('policy-'):]
            require(meta['identity']['ordinary_implicit_pond_switch'][key]=='foreign' and
                    meta['binding']['build']['ordinary_implicit_pond_switch'][key]=='foreign' and
                    r['actual']=='Foreign ordinary implicit positive-pond reference policy',
                    'Malicious policy was not actually materialized')
        else:
            require(name in top_fields|head_fields,'Unexpected actual source attack')
            source='boundtop.f90' if name in top_fields else 'headcalc.f90'
            actual=digest(folder/source)
            require(all(i['donor_generated'][source]==actual for i in (meta['identity'],meta['binding']['build'])),
                    'Source attack did not also forge its mutable hash inventory')
            raw=(folder/source).read_text(encoding='cp1252')
            if name=='top-deadband':require('if (h0 <= 1.0d-6) then' in raw,'Missing actual deadband attack')
            if name=='top-missing-chain':require('real(8) function ordinary_implicit_top_jacobian' not in raw,'Missing removed chain attack')
            if name=='top-inexact-root':require('do iteration=1,64' in raw,'Missing actual root attack')
            if name=='head-double-chain':require('dFdhM(1)=dFdhM(1)+kmean(1)/disnod(1)*2d0' in raw,'Missing double chain attack')
            if name.endswith('unrelated'):require('actual foreign original' in raw,'Missing foreign complete source attack')
    require(len(fields)==len(set(fields))==q['actual_refusals']==20 and
            top_fields|head_fields<=set(fields),'Actual ordinary refusal denominator differs')
    return dict(status='INDEPENDENT_ACTUAL_ORDINARY_SOURCE_POLICY_REFUSALS_PASS',actual_refusals=20,
                actual_malicious_sources=7,actual_forged_policy_fields=13,model_executions=0)
