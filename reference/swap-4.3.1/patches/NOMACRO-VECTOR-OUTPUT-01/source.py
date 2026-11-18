"""Explicit vector catalog initialization from the exact original DATA table."""
import hashlib
import re

ORIGINAL_SHA='a1b1b261ec05153d2075099c04cc6bb656f657344d4c1ceb5c9e43d0fd225355'
ANCHOR='      ! extract all individual vars from InList;'


def catalog(text):
    if hashlib.sha256(text.encode('cp1252')).hexdigest()!=ORIGINAL_SHA:raise ValueError('Foreign original vector catalog source')
    begin='   data (vars_v%name(i), vars_v%unit(i), vars_v%conv(i), vars_v%subr(i), vars_v%itzq(i), i = 1, M_v) / &'
    assert text.count(begin)==1
    block=text.split(begin,1)[1].split('\n      /',1)[0]
    block='\n'.join(line.split('!')[0] for line in block.splitlines())
    rows=re.findall(r"'([^']*)'\s*,\s*'([^']*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)",block)
    assert len(rows)==58 and len({row[0] for row in rows})==58
    residue=re.sub(r"'([^']*)'\s*,\s*'([^']*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)",'',block)
    assert not residue.replace('&','').replace(',','').strip()
    return rows


def edits(original):
    text=original.replace(b'\r\n',b'\n').decode('cp1252');rows=catalog(text)
    routine='   subroutine original_vector_catalog_init()\n'
    for i,row in enumerate(rows,1):
        for field,value in zip(('name','unit','conv','subr','itzq'),row):
            routine+=f"      vars_v%{field}({i})="+("'"+value+"'" if field in ('name','unit') else value)+'\n'
    routine+='   end subroutine original_vector_catalog_init\n\n'
    closing='end module SWAP_csv_output';assert text.count(closing)==1 and text.count(ANCHOR)==1
    return [(ANCHOR,'      call original_vector_catalog_init()\n'+ANCHOR),(closing,routine+closing)]


def source(original):
    canonical=original.replace(b'\r\n',b'\n');text=canonical.decode('cp1252')
    for old,new in edits(original):text=text.replace(old,new,1)
    corrected=text.encode('cp1252')
    if original==canonical:return corrected
    if original==canonical.replace(b'\n',b'\r\n'):return corrected.replace(b'\n',b'\r\n')
    raise ValueError('Mixed original vector output line endings')
