from pathlib import Path
import re,textwrap
from docx import Document
from docx.shared import Inches,Pt,RGBColor,Cm
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.text import WD_ALIGN_PARAGRAPH
W=Path(__file__).resolve().parent;source=W/'Kalmthout_V02_technical_note.md';dest=W/'Kalmthout_V02_technical_note.docx'
doc=Document();sec=doc.sections[0];sec.page_width=Cm(21);sec.page_height=Cm(29.7);sec.top_margin=Cm(1.9);sec.bottom_margin=Cm(1.8);sec.left_margin=Cm(2);sec.right_margin=Cm(2)
styles=doc.styles
for name in ('Normal','Title','Subtitle','Heading 1','Heading 2','Heading 3'):
 s=styles[name];s.font.name='Calibri';s.font.color.rgb=RGBColor(0,0,0)
styles['Normal'].font.size=Pt(10.5);styles['Normal'].paragraph_format.space_after=Pt(6);styles['Normal'].paragraph_format.line_spacing=1.08
for n,size in [('Title',25),('Heading 1',16),('Heading 2',12)]:
 styles[n].font.size=Pt(size);styles[n].font.bold=True
 styles[n].paragraph_format.space_before=Pt(14);styles[n].paragraph_format.space_after=Pt(6)
styles['Subtitle'].font.size=Pt(13)
for st in styles:
 for el in list(st.element.iter(qn('w:pBdr'))):el.getparent().remove(el)
header=sec.header.paragraphs[0];header.text='SYMPHONICA   |   Kalmthoutse Heide   |   SWAP 4.3.1 V02';header.style='Normal'
for r in header.runs:r.font.size=Pt(8);r.font.color.rgb=RGBColor.from_string('555555')
footer=sec.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.RIGHT
r=footer.add_run('Provisional technical exercise   |   19 October 2026   |   ');r.font.size=Pt(8)
f=OxmlElement('w:fldSimple');f.set(qn('w:instr'),'PAGE');footer._p.append(f)
doc.core_properties.title='Kalmthoutse Heide SWAP regional runs';doc.core_properties.subject='Technical construction and output metadata for the first provisional version';doc.core_properties.author='SYMPHONICA';doc.core_properties.keywords='SWAP 4.3.1, Kalmthout, WOFOST, soil heat, NetCDF, provisional'
lines=source.read_text().splitlines();i=0

def add_table(rows):
 table=doc.add_table(rows=0, cols=len(rows[0]));table.autofit=False
 width=17/len(rows[0]);widths=[width]*len(rows[0])
 if len(rows[0])==2:widths=[5.2,11.8]
 elif len(rows[0])==3:widths=[3.2,8.8,5.0]
 elif len(rows[0])==4:widths=[4.5,2,2,8.5]
 elif len(rows[0])==5:widths=[5,3,3,3,3]
 if rows[0][0]=='Variable group':widths=[5.4,4.4,7.2]
 if rows[0][0]=='Setting':widths=[4.3,6.35,6.35]
 if rows[0][0]=='Layer':widths=[1.5,4,2.5,9]
 for j,w in enumerate(widths):table.columns[j].width=Cm(w)
 for n,row in enumerate(rows):
  cells=table.add_row().cells
  for j,text in enumerate(row):
   cells[j].width=Cm(widths[j]);cells[j].vertical_alignment=1
   # Long identifiers and hashes wrap explicitly without changing visible characters.
   text=re.sub(r'\b[0-9a-f]{64}\b',lambda m:m[0][:32]+'\n'+m[0][32:],text)
   p=cells[j].paragraphs[0];p.paragraph_format.space_before=Pt(3);p.paragraph_format.space_after=Pt(3);p.paragraph_format.line_spacing=1.02
   r=p.add_run(text);r.font.size=Pt(9 if len(row)<5 else 8.7)
   pr=cells[j]._tc.get_or_add_tcPr();sh=OxmlElement('w:shd');sh.set(qn('w:fill'),'E7ECEF' if n==0 else ('F5F6F7' if n%2==0 else 'FFFFFF'));pr.append(sh)
   margins=OxmlElement('w:tcMar')
   for side in ('top','left','bottom','right'):
    el=OxmlElement('w:'+side);el.set(qn('w:w'),'65');el.set(qn('w:type'),'dxa');margins.append(el)
   pr.append(margins)
   if n==0:r.bold=True
   if len(rows)<=9 and n<len(rows)-1:p.paragraph_format.keep_with_next=True
  trpr=table.rows[-1]._tr.get_or_add_trPr();cant=OxmlElement('w:cantSplit');trpr.append(cant)
  if n==0:repeat=OxmlElement('w:tblHeader');trpr.append(repeat)
 borders=OxmlElement('w:tblBorders')
 for side in ('top','left','bottom','right','insideH','insideV'):
  e=OxmlElement('w:'+side);e.set(qn('w:val'),'single');e.set(qn('w:sz'),'4');e.set(qn('w:color'),'D9D9D9');borders.append(e)
 table._tbl.tblPr.append(borders)
 doc.add_paragraph().paragraph_format.space_after=Pt(0)

while i<len(lines):
 line=lines[i]
 if line.startswith('|'):
  rows=[]
  while i<len(lines) and lines[i].startswith('|'):
   r=[s.strip() for s in lines[i].strip('|').split('|')]
   if not all(re.fullmatch(r':?-+:?',s) for s in r):rows.append(r)
   i+=1
  add_table(rows);continue
 if line.startswith('```'):
  code=[];i+=1
  while i<len(lines) and not lines[i].startswith('```'):code.append(lines[i]);i+=1
  for c in code:
   for part in textwrap.wrap(c,width=100,break_long_words=True,break_on_hyphens=False) or ['']:
    p=doc.add_paragraph();p.paragraph_format.space_after=Pt(1);p.paragraph_format.line_spacing=1
    r=p.add_run(part);r.font.name='DejaVu Sans Mono';r.font.size=Pt(7.2)
  i+=1;continue
 if line.startswith('# '):doc.add_paragraph(line[2:],'Title')
 elif line.startswith('## '):doc.add_paragraph(line[3:],'Heading 1')
 elif line.startswith('### '):doc.add_paragraph(line[4:],'Heading 2')
 elif line:
  if i==2:doc.add_paragraph(line,'Subtitle')
  else:
   p=doc.add_paragraph(line)
   if re.match(r'^\d+\. ',line):p.paragraph_format.left_indent=Cm(.5);p.paragraph_format.first_line_indent=Cm(-.5)
 i+=1
# Keep all heading text with following content and use Word navigation via built-in styles.
for p in doc.paragraphs:
 if p.style.name.startswith('Heading'):p.paragraph_format.keep_with_next=True
settings=doc.settings.element;upd=OxmlElement('w:updateFields');upd.set(qn('w:val'),'true');settings.append(upd)
doc.save(dest);print(dest)
