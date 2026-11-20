"""Independently verify full-period coverage from preserved actual segments."""
import argparse
from datetime import date,timedelta
import hashlib
import json
from pathlib import Path
import zipfile

from implicit_snow_forensics import audit as short_audit,native,scalar,original,clock,snow
from ordinary_pond_evidence import read,digest,rows,physical,require


def audit(root):
    root=Path(root);q=read(root/'RESULT.json')
    require(q['status']=='ACTUAL_IMPLICIT_SNOW_SEGMENTED_FULL_EXACT_OVERLAP_NATIVE_OUTPUT_PASS','Actual segmented period incomplete')
    source=Path(q['actual_censored_producer']);old=read(source)
    require(digest(source)==q['actual_censored_producer_sha256'] and old['status']=='FAILED_OR_CENSORED' and
        old['error']=="TimeoutError('Model wall cap 600s')",'Original censored producer changed/relabelled')
    short=Path(old['actual_short_receipt']);require(digest(short)==old['actual_short_receipt_sha256'],'Actual successful short dependency changed')
    short_audit(short.parent)
    buildpath=Path(q['build_root']);build=read(buildpath/'BUILD.json');selected=build['identity']['original_output']
    require(q['actual_BUILD_sha256']==digest(buildpath/'BUILD.json')==q['continuation']['build_sha256'] and
        q['build_root']==old['build_root'] and q['input_root']==old['input_root'],'Actual segmented compiler/input identity differs')
    swp=(Path(q['input_root'])/'swap.swp').read_text(encoding='cp1252')
    selectors={k:scalar(swp,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWKMEAN','NPRINTDAY')}
    require(selectors['SWKIMPL']==selectors['SWSNOW']==selectors['SWSOLU']==1,'Wrong actual segmented physical domain')
    first=source.parent/'trajectory';second=root/'continuation';a=rows(first);b=rows(second);cut=q['source_prefix_days']
    require(cut==q['cold_continuation_start']==635 and len(a)==q['censored_accepted_days'] and
        635<len(a)<1096 and len(b)==1096-cut and b[0]['day']==cut+1 and b[-1]['day']==1096,
        'Actual segmented coverage denominator differs')
    checkpoint=first/f'accepted-column-1-day-{cut}.zip'
    require(digest(checkpoint)==q['actual_origin_checkpoint_sha256'],'Actual original segment origin changed')
    overlap=len(a)-cut
    require(physical(a[cut:])==physical(b[:overlap]) and overlap==q['continuation']['exact_physical_overlap_days'],
            'Actual cold continuation physical overlap differs')
    whole=a[:cut]+b;water=original.water(whole);clock.ledger(whole,1096)
    def stream(path,data):
        original.water(data);clock.ledger(data,len(data))
        original.original_observations((path/'original/donor.stdout').read_bytes(),data,build['project']['start_date'])
        class Files:
            def read(self,name):return (path/name).read_bytes()
        clock.daily(Files(),'',data,build['project']['nodes']);snow.soil(path,len(data))
    stream(first,a);stream(second,b)
    def outputs(path):return {f.name:original.output_records(f.read_bytes(),f.name) for f in path.glob('result_output.*') if f.suffix in ('.csv','.bin')}
    before,after=outputs(first/'original'),outputs(second/'original')
    upper=str(date.fromisoformat(build['project']['start_date'])+timedelta(days=len(a)))+' 00:00:00'
    def stamp(row):return row[:19].decode('ascii').strip() if isinstance(row,bytes) else row.split(',')[0].strip()
    cropped={name:[data[0],*(row for row in data[1:] if stamp(row)<=upper)] for name,data in after.items()}
    overlap_output=original.output_continuation(before,cropped,selected,cut,len(a),build['project']['start_date'])
    def checkpoints(path,data,expected):
        byday={r['day']:r for r in data};found=set();witnesses={}
        epoch=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
        for line in (path/'original/donor.stdout').read_text().splitlines():
            if line.startswith('HYBRID_SNOW_ROOT_NATIVE '):
                values=list(map(float,line.split()[1:]));require(len(values)==3 and original.finite(values),'Actual segmented root witness invalid')
                witnesses.setdefault(values[0],[]).append(tuple(values[1:]))
        for f in path.glob('accepted-column-1-day-*.zip'):
            day=int(f.stem.rsplit('-',1)[1]);require(day in byday,'Segment checkpoint outside actual accepted days')
            with zipfile.ZipFile(f) as z:
                require(set(z.namelist())=={'checkpoint.json','macro.bin','result.end'},'Foreign actual segmented checkpoint inventory')
                meta=json.loads(z.read('checkpoint.json'))
                require(meta['binding']==build['binding'] and meta['receipt']==byday[day] and set(meta['files'])=={'macro.bin','result.end'},'Actual segmented native binding differs')
                for name,sha in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==sha,'Actual segmented native bytes changed')
                rates=native(z.read('macro.bin'),byday[day],build,selected,selectors)
                require(rates in witnesses.get(epoch+day,[]),'Actual segmented root values differ from original witness')
                original.sequential_records(z.read('result.end'))
            found.add(day)
        require(found==expected,'Actual segment native denominator differs')
    windows=[(2,4),(7,9),(30,34),(163,165),(199,201),(364,367),(530,532),(633,635),(1094,1096)]
    require([(r['start'],r['end']) for r in q['cold']]==windows,'Actual segmented cold denominator differs')
    checkpoints(first,a,{d for pair in windows for d in pair if d<=len(a)})
    checkpoints(second,b,{1094,1096})
    for item in q['cold']:
        low,high=item['start'],item['end'];cold=root/f'own-{low}';data=rows(cold)
        require(physical(data)==physical(whole[low:high]),'Actual segmented cold physical postimage differs')
        stream(cold,data);checkpoints(cold,data,{high})
        parent=first if high<=cut else second
        with zipfile.ZipFile(parent/f'accepted-column-1-day-{high}.zip') as x,zipfile.ZipFile(cold/f'accepted-column-1-day-{high}.zip') as y:
            require(all(x.read(n)==y.read(n) for n in ('macro.bin','result.end')),'Actual segmented cold complete native differs')
        require(original.output_continuation(outputs(parent/'original'),outputs(cold/'original'),selected,low,high,build['project']['start_date'])==item['exact_original_output'],
            'Actual segmented cold original user records differ')
    return dict(status='INDEPENDENT_SEGMENTED_IMPLICIT_SNOW_FULL_NATIVE_OUTPUT_PASS',unique_qualified_days=1096,
        original_censored_accepted_days=len(a),actual_continuation_days=len(b),exact_physical_overlap_days=overlap,
        exact_original_output_overlap=overlap_output,actual_cold_windows=9,water=water,
        original_censored_producer_preserved=True,producer_relabelled=False,new_continuous_full_claim=False,
        whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=audit(a.root)
    with a.output.open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
    print(q['status'],q['exact_physical_overlap_days'])
