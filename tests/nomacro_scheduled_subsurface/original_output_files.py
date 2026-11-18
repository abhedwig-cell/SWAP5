"""Exact actual warm/cold user output; no reconstructed physical oracle."""
import csv
from datetime import date,timedelta
import re
import struct


def records(path):
    if path.suffix=='.csv':
        return [line.strip() for line in path.read_text(encoding='cp1252').splitlines() if re.match(r'\d{4}-\d{2}-\d{2}',line)]
    raw=path.read_bytes()
    labels=[raw.find(label) for label in (b'DATE                    ',b'DATETIME                ')]
    labels=[x for x in labels if x>=0];assert len(labels)==1,labels
    first=next(re.finditer(rb'\d{4}-\d{2}-\d{2}',raw[labels[0]:])).start()+labels[0]
    assert (first-labels[0])%24==0
    ncolumns=(first-labels[0])//24-1;size=19+4*ncolumns
    assert ncolumns>0 and (len(raw)-first)%size==0
    result=[raw[pos:pos+size] for pos in range(first,len(raw),size)]
    for record in result:
        assert re.match(rb'\d{4}-\d{2}-\d{2}',record)
        assert len(struct.unpack('<'+'f'*ncolumns,record[19:]))==ncolumns
    return result


def compare(full,cold,selected,start,end,start_date):
    names={p.name for p in full.glob('*.csv')}|{p.name for p in full.glob('*_output.bin')}
    assert names==({p.name for p in cold.glob('*.csv')}|{p.name for p in cold.glob('*_output.bin')})
    first=date.fromisoformat(start_date);lo=str(first+timedelta(days=start));hi=str(first+timedelta(days=end))
    report={}
    for name in sorted(names):
        # SWCSV2's separate initialization table describes that run's initial
        # state. It is not a continuation event and is inventoried separately.
        if name not in ('result_output.csv','result_output.bin') and not name.lower().startswith('result.age'):continue
        warm=records(full/name);actual=records(cold/name)
        if name.startswith('result.age'):
            def day(line):return int(next(csv.reader([line]))[2])
            expected=[line for line in warm if start<day(line)<=end]
        else:
            stamp=lambda row:row[:19].decode('ascii').strip() if isinstance(row,bytes) else row.split(',')[0].strip()
            low=lo+' 00:00:00' if selected['flprintdt'] or selected['nprintday']>1 else lo
            high=hi+' 00:00:00' if selected['flprintdt'] or selected['nprintday']>1 else hi
            expected=[row for row in warm[1:] if (low<stamp(row)<=high if selected['flprintdt'] or selected['nprintday']>1 else low<=stamp(row)<high)]
            assert actual,'Missing actual original initialization row'
            actual=actual[1:]
        assert actual==expected,(name,len(actual),len(expected),next(((a,b) for a,b in zip(actual,expected) if a!=b),None))
        report[name]=dict(exact=True,continuation_records=len(expected),kind='original_REAL4_binary' if name.endswith('.bin') else 'original_ASCII')
    return report
