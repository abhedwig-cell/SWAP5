"""Bounded original CDE output cadences under actual paired9 forcing."""
import argparse
from pathlib import Path
from explicit_bottom9_inputs import prepare as basic
from explicit_bottom9_drain_inputs import prepare as drain
from original_output_baseline import assignment

CASES=('cde-periodic','cde-monthly','cde-subdaily','cde-step','cde-distributed-subdaily')


def prepare(case,output,initial):
    assert case in CASES and initial in (1,2)
    if case=='cde-distributed-subdaily':drain('cde',output,initial)
    else:basic('cde-pressure-daily',output,initial)
    controls={'cde-periodic':dict(PERIOD=3,SWRES=1),'cde-monthly':dict(SWMONTH=1,SWRES=0),'cde-subdaily':dict(NPRINTDAY=3,PERIOD=3,SWRES=0),'cde-step':dict(PERIOD=0,SWRES=0,FLPRINTDT='.TRUE.'),'cde-distributed-subdaily':dict(NPRINTDAY=3,PERIOD=3,SWRES=0)}[case]
    path=output/'swap.swp';text=path.read_bytes().decode('cp1252')
    for key,value in controls.items():text=assignment(text,key,value)
    path.write_bytes(text.encode('cp1252'))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',type=int,choices=(1,2),required=True);a=p.parse_args();prepare(a.case,a.output,a.initial)
