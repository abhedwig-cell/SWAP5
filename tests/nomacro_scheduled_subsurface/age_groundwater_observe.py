"""Independent actual original AGE user records versus daily probes/native CML."""
import argparse,csv,json,math,struct,zipfile
from datetime import date,timedelta
from pathlib import Path
from original_output_files import records
from age_perstep_runtime import calendar


def observe(full,data,project):
    names=('result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv')
    values={name:[next(csv.reader([line])) for line in records(full/'original'/name)] for name in names}
    days={name:[int(row[2]) for row in rows] for name,rows in values.items()};expected=days[names[0]]
    assert all(actual==expected for actual in days.values()) and expected==sorted(set(expected)) and all(1<=i<=len(data) for i in expected),days
    first=date.fromisoformat(project.start_date);rounded=lambda v:float(format(v,'.3E'));native=[]
    for index,day in enumerate(expected):
        for rows in values.values():assert date.fromisoformat(rows[index][0].strip())==first+timedelta(days=day-1)
        a,w,d=[values[name][index] for name in (names[1],names[3],names[2])];eff=data[day-1]['age_effluent']
        assert list(map(float,a[4:]))==list(map(rounded,eff[16:])),('actual mean AGE',day)
        assert list(map(float,w[3:]))==list(map(rounded,eff[:8])),('actual export water',day)
        assert list(map(float,d[3:]))==list(map(rounded,eff[3:8])),('actual drainage export',day)
        profile=list(map(float,values[names[0]][index][3:]));assert len(profile)==project.nodes and all(math.isfinite(v) and v>=0 for v in profile)
        path=full/f'accepted-column-1-day-{day}.zip'
        if path.exists():
            with zipfile.ZipFile(path) as z:raw=z.read('macro.bin')
            pos,_,nr=calendar(raw,project.nodes);start=pos+160+16*nr;cml=struct.unpack_from('<'+str(project.nodes)+'d',raw,start+16*project.nodes)
            assert profile==list(map(rounded,cml)),('actual native CML/user profile',day);native.append(day)
    if first+timedelta(days=len(data)-1)==date.fromisoformat(project.end_date):assert expected and expected[-1]==len(data) and len(data) in native
    return dict(actual_global_days=days,actual_means_and_volumes_exact=True,profile_nodes=project.nodes,all_profiles_finite_nonnegative=True,actual_native_cml_comparison_days=native,full_tend_record_required=True)


def main():
    p=argparse.ArgumentParser();p.add_argument('--matrix-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    import age_groundwater_runtime as c
    matrix=json.loads((a.matrix_root/'RESULT.json').read_text(encoding='utf8'));q=dict(status='RUNNING',cases={})
    for key,item in matrix['cases'].items():
        project=c.m.e.load(Path(item['input_root']),original_output=True);entries={}
        for kind in ('short','full'):
            if kind not in item:continue
            full=Path(item[kind+'_root'])/'trajectory';entries[kind]=observe(full,c.m.rows(full),project)
        q['cases'][key]=entries
    q['status']='ACTUAL_AGE_GROUNDWATER_USER_AGE_EXPORT_AND_NATIVE_CML_RECORDS_PASS';a.output.write_text(json.dumps(q,indent=2)+'\n',encoding='utf8');print(q['status'])


if __name__=='__main__':main()
