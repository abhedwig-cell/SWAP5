"""Merge only Artifact Tool-authored edits into the original XLSX package.

Artifact Tool authors/recalculates/renders the spreadsheet. This preservation
adapter retains untouched workbook parts, including custom XML and original
worksheet names, which a complete export would otherwise normalise or remove.
It uses ZIP/XML package operations, not an alternative spreadsheet engine.
"""
from pathlib import Path
from zipfile import ZipFile
from lxml import etree as E
from copy import deepcopy
import argparse, json, re, hashlib

NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main'
N={'m':NS}
def tag(name):return '{'+NS+'}'+name

def strings(z):
    return [''.join(x.itertext()) for x in E.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',N)] if 'xl/sharedStrings.xml' in z.namelist() else []

def main(original, authored, changes, output):
    spec=json.loads(changes.read_text());allowed={x['cell']:x['value'] for x in spec['changes']}
    with ZipFile(original) as source, ZipFile(authored) as edits:
        name='xl/worksheets/sheet1.xml'
        root=E.fromstring(source.read(name));new=E.fromstring(edits.read(name))
        oldstyles=E.fromstring(source.read('xl/styles.xml'));newstyles=E.fromstring(edits.read('xl/styles.xml'))
        oldxfs=oldstyles.find('m:cellXfs',N);newxfs=newstyles.find('m:cellXfs',N)
        newstrings=strings(edits)
        oldcells={c.get('r'):c for c in root.findall('.//m:sheetData/m:row/m:c',N)}
        newcells={c.get('r'):c for c in new.findall('.//m:sheetData/m:row/m:c',N)}
        rows={int(r.get('r')):r for r in root.findall('m:sheetData/m:row',N)}
        newrows={int(r.get('r')):r for r in new.findall('m:sheetData/m:row',N)}
        for address,value in allowed.items():
            fresh=deepcopy(newcells[address]);old=oldcells.get(address)
            if old is None:
                row=rows[int(re.search(r'\d+',address).group())];old=E.Element(tag('c'),{'r':address});row.append(old);oldcells[address]=old
            # Read values from the authored workbook, retaining its numeric type.
            for child in list(old):
                if child.tag in (tag('v'),tag('is'),tag('f')):old.remove(child)
            dtype=fresh.get('t')
            if dtype=='s':
                text=newstrings[int(fresh.find('m:v',N).text)];old.set('t','inlineStr');inline=E.SubElement(old,tag('is'));E.SubElement(inline,tag('t')).text=text
            else:
                if dtype:old.set('t',dtype)
                else:old.attrib.pop('t',None)
                for child in fresh:
                    if child.tag in (tag('v'),tag('is'),tag('f')):old.append(deepcopy(child))
        # Preserve original font/fill/borders/number formats; apply only the
        # alignment/wrapping authored for the four requested product rows.
        stylecache={}
        for address,old in oldcells.items():
            match=re.fullmatch(r'([A-Z]+)(\d+)',address)
            if not match or not 2<=int(match.group(2))<=5:continue
            col=match.group(1)
            if len(col)>1 or col>'R':continue
            if address not in newcells:continue
            fresh=newcells[address];oldindex=int(old.get('s','0'));newindex=int(fresh.get('s','0'))
            alignment=newxfs[newindex].find('m:alignment',N)
            cachekey=(oldindex,E.tostring(alignment) if alignment is not None else None)
            if cachekey not in stylecache:
                xf=deepcopy(oldxfs[oldindex])
                for child in list(xf):
                    if child.tag==tag('alignment'):xf.remove(child)
                if alignment is not None:xf.append(deepcopy(alignment));xf.set('applyAlignment','1')
                stylecache[cachekey]=len(oldxfs);oldxfs.append(xf)
            old.set('s',str(stylecache[cachekey]))
        oldxfs.set('count',str(len(oldxfs)))
        for i in range(2,6):
            for k in ('ht','customHeight'):
                if k in newrows[i].attrib:rows[i].set(k,newrows[i].get(k))
            # Keep XML cells in ascending column order.
            children=list(rows[i]);children.sort(key=lambda c:(len(re.sub(r'\d','',c.get('r',''))),re.sub(r'\d','',c.get('r',''))))
            rows[i][:]=children
        replacement={name:E.tostring(root,encoding='utf-8',xml_declaration=True),'xl/styles.xml':E.tostring(oldstyles,encoding='utf-8',xml_declaration=True)}
        output.parent.mkdir(parents=True,exist_ok=True)
        with ZipFile(output,'w') as dest:
            for info in source.infolist():dest.writestr(deepcopy(info),replacement.get(info.filename,source.read(info.filename)))
        with ZipFile(output) as final:
            assert set(source.namelist())==set(final.namelist())
            for p in source.namelist():
                if p not in replacement:assert source.read(p)==final.read(p),p
            assert final.testzip() is None
        print(json.dumps({'status':'PASS','source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'changed_values':len(allowed),'changed_package_parts':list(replacement),'all_other_parts_byte_identical':True,'other_two_worksheets_byte_identical':True,'original_sheet_names_and_custom_xml_retained':True},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('original',type=Path);p.add_argument('authored',type=Path);p.add_argument('changes',type=Path);p.add_argument('output',type=Path);a=p.parse_args();main(a.original,a.authored,a.changes,a.output)
