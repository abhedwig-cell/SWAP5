"""Materialize one original SaltFarm workbook scenario without changing physics.

The distribution supplies a literal SWP template and a single irrigation table.
This adapter expands that table and flattens the original input folders, retaining
all source/member hashes. It does not claim byte identity with an unavailable R run.
"""
from datetime import date,timedelta
import hashlib
import json
from pathlib import Path
import re
import shutil
from xml.etree import ElementTree as E
import zipfile

ROOT=Path(__file__).resolve().parents[2]
NS={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def workbook_rows(path,sheet):
    with zipfile.ZipFile(path) as z:
        strings=[''.join(x.itertext()) for x in E.fromstring(z.read('xl/sharedStrings.xml'))]
        rows=[]
        for row in E.fromstring(z.read(f'xl/worksheets/sheet{sheet}.xml')).findall('m:sheetData/m:row',NS):
            values=[]
            for cell in row:
                value=cell.find('m:v',NS)
                text=value.text if value is not None else ''
                values.append(strings[int(text)].strip() if cell.get('t')=='s' else text)
            rows.append(values)
        headers=rows[0]
        return [dict(zip(headers,row)) for row in rows[1:]]


def prepare(output,run_id=1):
    output=Path(output)
    source=ROOT/'reference/swap-4.3.1/projects/4.salinitystress'
    manifest=json.loads((source.parent/'MANIFEST.json').read_text())
    for name,row in manifest['members'].items():
        if name.startswith('4.salinitystress/'):
            p=source.parent/name
            if sha(p)!=row['sha256']:raise ValueError('Foreign original SaltFarm source: '+name)
    runs=workbook_rows(source/'tools/datamodel.xlsx',1)
    selected=[r for r in runs if int(r['run_id'])==run_id]
    if len(selected)!=1:raise ValueError('Unknown or ambiguous original SaltFarm run')
    selected=selected[0]
    irrigation=[r for r in workbook_rows(source/'tools/datamodel.xlsx',2) if r['irrigation_id']==selected['irrigation_id']]
    if not irrigation:raise ValueError('Missing original irrigation scenario')
    text=(source/'tools/template/swap.swp').read_text(encoding='cp1252')
    lines=[]
    def real_literal(value):
        # Shortest round-trip double spelling preserves the workbook value and
        # keeps TTUTIL columns consistently REAL (e.g.20.0 rather than20).
        return repr(float(value))
    for row in irrigation:
        serial=int(row['IRDATE'])
        when=(date(1899,12,30)+timedelta(days=serial)).isoformat()
        lines.append(' '+when+' '+real_literal(row['IRDEPTH'])+' '+real_literal(row['IRCONC'])+' '+row['IRTYPE'])
    marker='{{#TABLE_IRRIGATIONFIXED}}';end='{{/TABLE_IRRIGATIONFIXED}}'
    if text.count(marker)!=1 or text.count(end)!=1:raise ValueError('Changed original template')
    a=text.index(marker);b=text.index(end,a)+len(end)
    text=text[:a]+' IRDATE IRDEPTH IRCONC IRTYPE\n'+'\n'.join(lines)+'\n* End of table'+text[b:]
    if '{{' in text:raise ValueError('Unresolved original template field')
    if re.findall(r'(?mi)^\s*SWMACRO\s*=\s*(\d+)',text)!=['0']:raise ValueError('Active macro configuration outside release')
    output.mkdir(parents=True,exist_ok=False)
    (output/'swap.swp').write_text(text,encoding='cp1252',newline='\n')
    paths=['swap.dra','initial/swap.ini','crop/fontane.crp','weather/235.met']
    for name in paths:shutil.copyfile(source/'tools/template'/name,output/Path(name).name)
    record={'source_distribution_sha256':manifest['distribution_sha256'],'run':selected,
        'source_workbook_sha256':sha(source/'tools/datamodel.xlsx'),
        'source_template_sha256':sha(source/'tools/template/swap.swp'),
        'irrigation_rows':len(irrigation),'physical_switches_changed':False,
        'preparation':'Literal original template table expanded from original workbook; original files flattened with bytes unchanged',
        'R_byte_equivalence':'NOT_CLAIMED; original numeric table values and dates retained',
        'files':{p.name:sha(p) for p in sorted(output.iterdir())}}
    (output/'PREPARATION.json').write_text(json.dumps(record,indent=2)+'\n',newline='\n')
    return record


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--run',type=int,default=1)
    a=p.parse_args();print(json.dumps(prepare(a.output,a.run),indent=2))
