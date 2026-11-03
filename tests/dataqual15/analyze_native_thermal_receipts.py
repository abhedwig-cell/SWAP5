"""Independent native thermal-data audit; no inferred heat or advective receipt."""
import argparse
import json
import math
from pathlib import Path


def analyze(raw):
    intervals={}
    for line in raw.decode('utf-8').splitlines():
        r=line.split(',');assert len(r)==23 and r[0]=='THERMAL'
        values=list(map(float,r[1:]));assert all(math.isfinite(x) for x in values)
        intervals.setdefault((values[0],values[1]),[]).append(values)
    assert intervals
    cursor=0.;previous=None;max_capacity=max_local=max_column=0.
    legacy_storage=boundary=linear_extension_stock=root_water=0.
    domain_errors=0;overshoot=0.;independent=0
    for (t0,t1),rows in sorted(intervals.items()):
        assert t0==cursor and t1>t0 and [int(r[2]) for r in rows]==list(range(1,113))
        cursor=t1;change=profile_change=0.
        for i,r in enumerate(rows):
            _,_,node,a,b,w0,w1,dz,capacity,left,right,root,drain,source,macro,phi,fq,fc,fo,ind,solution,top=r
            assert dz>0 and phi>0 and solution==1 and ind in (0,1)
            if previous is not None:
                assert a==previous[i][4] and w0==previous[i][6],'actual native profile continuity'
            if i:assert rows[i-1][10]==left,'internal conductive faces disagree'
            solid=fq*2660*800+fc*2650*900+fo*1300*1920
            average=.5*(w0+w1)
            cp=(solid+average*1000*4180+max(0.,phi-average)*1.2*1010)*1e-6
            max_capacity=max(max_capacity,abs(cp-capacity));assert abs(cp-capacity)<2e-14
            local=dz*cp*(b-a);change+=local
            max_local=max(max_local,abs(local-left+right))
            # Explicit diagnostic extension of the linear law to RAW theta.
            # Invalid domains are counted, never clipped or physically qualified.
            cp0=(solid+w0*1000*4180+(phi-w0)*1.2*1010)*1e-6
            cp1=(solid+w1*1000*4180+(phi-w1)*1.2*1010)*1e-6
            profile_change+=dz*(cp1*b-cp0*a)
            if min(w0,w1)<0 or max(w0,w1)>phi:
                domain_errors+=1;overshoot=max(overshoot,-min(w0,w1),max(w0,w1)-phi)
            root_water+=(t1-t0)*root
        incoming=rows[0][9]-rows[-1][10]
        max_column=max(max_column,abs(change-incoming))
        legacy_storage+=change;boundary+=incoming;linear_extension_stock+=profile_change
        independent+=int(all(r[19]==1 for r in rows));previous=rows
    assert cursor==1.0
    assert max_local<1e-9 and max_column<1e-9
    return dict(status='ACTUAL_FIRST_DAY_THERMAL_DATA_INDEPENDENTLY_VERIFIED',intervals=len(intervals),node_rows=112*len(intervals),
        independent_conductive_boundary_intervals=independent,max_capacity_reconstruction_error_j_cm3_k=max_capacity,
        max_nodal_legacy_energy_error_j_cm2=max_local,max_column_legacy_energy_error_j_cm2=max_column,
        legacy_average_capacity_storage_change_j_cm2=legacy_storage,conductive_boundary_into_j_cm2=boundary,
        raw_theta_domain_error_rows=domain_errors,max_raw_theta_domain_error=overshoot,
        diagnostic_unclipped_theta_profile_stock_change_j_cm2=linear_extension_stock,
        diagnostic_profile_stock_minus_conduction_j_cm2=linear_extension_stock-boundary,
        native_root_rate_integral_cm=root_water,full_energy_balance_complete=False,
        diagnostic_scope='Raw matrix theta-profile linear-mixture extension; not whole matrix/macro physical stock qualification. No heat flux inferred from residual.',
        missing=['gas flow and external gas donor temperatures','external liquid donor temperatures and advective time quadrature',
                 'macropore sensible-energy partition/transport','atmospheric latent/radiation, vapor and phase-change ownership'])


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();r=analyze(a.input.read_bytes());a.output.write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(r,indent=2))


if __name__=='__main__':main()
