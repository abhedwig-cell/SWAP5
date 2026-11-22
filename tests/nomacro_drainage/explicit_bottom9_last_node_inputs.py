"""Original steady water control with its lateral sink in the actual last node."""
import argparse,re
from pathlib import Path
from explicit_bottom9_inputs import prepare as base
from original_output_baseline import assignment


def prepare(output,initial):
    base('water-pressure-daily',output,initial)
    path=output/'swap.swp';text=path.read_bytes().decode('cp1252');text=assignment(text,'SWDRA',1)
    for pattern,value in [(r'(?mis)(^[ \t]*HTB[ \t]*=[ \t]*\r?\n).*?(^[ \t]*\* End of table)',r'\g<1> -0.5 0.0\n -195.0 0.0\n\g<2>'),(r'(?m)^2002-01-01 0\.0$', '2002-01-01 1.25'),(r'(?m)^2004-01-01 0\.0$', '2004-01-01 1.25'),(r'(?m)^2002-01-01 -1\.0$', '2002-01-01 -0.75'),(r'(?m)^2004-01-01 -1\.0$', '2004-01-01 -0.75')]:
        text,count=re.subn(pattern,value,text);assert count==1,(pattern,count)
    path.write_bytes(text.encode('cp1252'))
    path=output/'swap.dra';text=path.read_bytes().decode('cp1252')
    for key,value in {'DRAMET':1,'SWDIVD':0}.items():text=assignment(text,key,value)
    text,count=re.subn(r'(?mis)(^[ \t]*GWL[ \t]+QDRAIN[^\r\n]*\r?\n).*?(^[ \t]*\* End of table)',r'\g<1> 0.0 0.25\n -1000.0 0.25\n\g<2>',text);assert count==1
    path.write_bytes(text.encode('cp1252'))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',type=int,choices=(1,2),required=True);a=p.parse_args();prepare(a.output,a.initial)
