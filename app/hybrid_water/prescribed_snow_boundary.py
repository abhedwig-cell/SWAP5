"""Bounded existing Snow/paired9 composition; independent admission is required."""
from pathlib import Path
import re

POLICY='existing-original-snow-explicit-paired9-all-node-soil-receipt-v1'


def _validate_calendar(text):
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous ordinary Snow drainage-off '+key)
        return values[0][1:-1] if quoted else int(values[0])
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if len(flags)>1 or token not in ('.TRUE.','TRUE','.T.','T','.FALSE.','FALSE','.F.','F'):raise ValueError('Invalid ordinary Snow drainage-off step flag')
    step=token in ('.TRUE.','TRUE','.T.','T');npd=one('NPRINTDAY');monthly=one('SWMONTH');fmt=one('SWCSV',0)
    dates=0 if monthly else one('SWODAT');reset=0 if monthly else one('SWRES');requested=0 if monthly else one('PERIOD')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if not 1<=npd<=1440 or monthly not in (0,1) or fmt not in (0,1,2,3) or dates not in (0,1) or reset not in (0,1) or not 0<=requested<=366 or precision is not None and not 5<=precision<=12:
        raise ValueError('Invalid ordinary Snow drainage-off output domain')


def selection(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 if s.get('SWBOTB')!=9 or s.get('SWSNOW')!=1:return None
 from prescribed_head_flux_boundary import selection as paired
 selected=paired(directory,original_output,hysteresis=s.get('SWHYST'),snow=True)
 if selected is None:return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 if models and any(int(value)!=1 for value in models[0].split()):
  if s.get('SWHYST')!=0 or any(int(value) not in (1,3,4,5,6,7,8,9,10,11) for value in models[0].split()):return None
 vapor=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(vapor)>1:return None
 if vapor and (re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',vapor[0]) is None or any(int(value)!=0 for value in vapor[0].split())):return None
 try:_validate_calendar(text)
 except ValueError:return None
 return dict(selected,policy=POLICY,snow_state='actual original seven-scalar Snow carry',soil_receipt='actual net rainfall/irrigation and melt; all nodes; actual prescribed qbot',physical_equations_changed=False)


def enabled(project):
 return selection(project.input_directory,getattr(project,'original_output',False)) is not None
