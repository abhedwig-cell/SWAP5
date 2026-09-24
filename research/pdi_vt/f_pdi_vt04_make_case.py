#!/usr/bin/env python3
from pathlib import Path
import argparse
import re
import shutil
import hashlib

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def scalar(text, name, value):
    pat = rf'(?mi)^(\s*{re.escape(name)}\s*=\s*)([^!\r\n]*)(.*)$'
    text, n = re.subn(pat, lambda m: m.group(1) + str(value) + ' ' + m.group(3), text, count=1)
    if n != 1:
        raise RuntimeError(f'{name}: expected one match, got {n}')
    return text

def insert_after_scalar(text, anchor, line):
    m = re.search(rf'(?mi)^\s*{re.escape(anchor)}\s*=.*$', text)
    if not m:
        raise RuntimeError(f'{anchor} not found for insertion')
    return text[:m.end()] + '\n' + line + text[m.end():]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src', type=Path)
    ap.add_argument('dst', type=Path)
    ap.add_argument('--swvapor', type=int, default=1)
    a = ap.parse_args()

    if a.dst.exists():
        shutil.rmtree(a.dst)
    shutil.copytree(a.src, a.dst)

    template = a.dst / 'swap_linux.swp.template'
    if not template.exists():
        raise SystemExit('missing swap_linux.swp.template')

    path = a.dst / 'swap.swp'
    shutil.copy2(template, path)
    text = path.read_text()

    for name, value in [
        ('PROJECT', "'pdi_vt04_fullrun'"),
        ('TSTART', '1980-01-01'),
        ('TEND', '1980-01-02'),
        ('DATEFIX', '02 01'),
        ('SWHEADER', '0'),
        ('SWBAL', '1'),
        ('SWBLC', '1'),
        ('SWCSV', '0'),
        ('METFIL', "'pdi.met'"),
        ('SWETR', '1'),
        ('SWDIVIDE', '0'),
        ('SWCROP', '0'),
        ('SWINCO', '1'),
        ('SWDRA', '0'),
        ('SWBBCFILE', '0'),
        ('SWHEA', '0')
    ]:
        text = scalar(text, name, value)

    text = scalar(text, 'SWAFO', '2')

    if re.search(r'(?mi)^\s*CRITDEVMASBAL\s*=', text):
        text = scalar(text, 'CRITDEVMASBAL', '1.0E-6')
    else:
        text = insert_after_scalar(text, 'SWHEADER', '  CRITDEVMASBAL = 1.0E-6')

    if re.search(r'(?mi)^\s*SWDISCRVERT\s*=', text):
        text = scalar(text, 'SWDISCRVERT', '0')
    else:
        text = insert_after_scalar(text, 'SWSOPHY', '  SWDISCRVERT = 0')

    # Uniform very dry initial pressure head. SWINCO=1 reads parallel ZI and H arrays.
    text, n = re.subn(
        r'(?mi)^\s*GWLI\s*=.*$',
        '  ZI = -0.5 -600.0\n  H = -1.0E5 -1.0E5',
        text,
        count=1,
    )
    if n != 1:
        raise RuntimeError('initial profile replacement failed')

    # Five-layer model-8 PDI setup, vapor switch controlled by --swvapor.
    pat = r'(?ms)^\s*(?:IHWCKMODEL\s+)?ORES\s+OSAT\s+ALFA\s+NPAR.*?^\* End of table'
    rows = f''' IHWCKMODEL ORES OSAT ALFA NPAR KSATFIT LEXP H_ENPR KSATEXM BDENS H0 HA APAR OMEGA_K SWVAPOR
 8 0.02 0.433878 0.021645 1.34877 83.24164 7.202077 0.0 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.02 0.433878 0.021645 1.34877 83.24164 7.202077 0.0 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.02 0.433878 0.021645 1.34877 83.24164 7.202077 0.0 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.01 0.364074 0.013642 1.48844 25.81471 2.179397 0.0 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.01 0.364074 0.013642 1.48844 25.81471 2.179397 0.0 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
* End of table'''
    text, n = re.subn(pat, rows, text, count=1)
    if n != 1:
        raise RuntimeError('hydraulic table replacement failed')

    if re.search(r'(?mi)^\s*SWBOTB\s*=', text):
        text = scalar(text, 'SWBOTB', '6')
    else:
        m = re.search(r'(?mi)^\s*BBCFIL\s*=.*$', text)
        if not m:
            raise RuntimeError('BBCFIL not found')
        text = text[:m.end()] + '\n\n  SWBOTB = 6' + text[m.end():]

    path.write_text(text)

    met = a.dst / 'pdi.met'
    met.write_text(
        "Station,DD,MM,YYYY,Rad,Tmin,Tmax,Hum,Wind,Rain,ETref,Wet\n"
        "'999',01,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
        "'999',02,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
    )

    print('swap.swp', sha(path))
    print('pdi.met', sha(met))

if __name__ == '__main__':
    main()
