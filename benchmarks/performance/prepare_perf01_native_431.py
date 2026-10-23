"""Prepare one shared complete original-input simple-crop application fixture.

This is a constructed supported site, not the original Andelst model and not
the previous synthetic WOFOST fixture. A zero tracer keeps the existing native
project interface unchanged; both applications explicitly select it.
"""
import argparse,datetime,decimal,gzip,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--rain',type=int,choices=[1,4],required=True)
    ap.add_argument('--days',type=int,default=97)
    a=ap.parse_args();assert 1<=a.days<=97
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    template=ROOT/'tests/data/ppa_wu05_migmac01/modified_andelst.swp'
    text=template.read_text();start=datetime.date(1999,1,20)
    end=start+datetime.timedelta(days=a.days-1)
    def value(key,val):
        nonlocal text
        pattern=r'(?mi)^\s*'+re.escape(key)+r'\s*=.*$'
        replacement=key+'='+str(val)
        if re.search(pattern,text):text=re.sub(pattern,lambda _:replacement,text)
        else:text+='\n'+replacement+'\n'
    def table(header,rows,output_header=None):
        nonlocal text
        pattern=r'(?m)^\s*'+re.escape(header)+r'\s*\n(?:[^*\n][^\n]*\n)+'
        text,n=re.subn(pattern,(output_header or header)+'\n'+rows+'\n',text)
        assert n==1,header
    for key,val in dict(PROJECT="'PERF01 constructed common input'",PATHWORK="' '",PATHATM="' '",PATHCROP="' '",
        TSTART=start.isoformat(),TEND=end.isoformat(),METFIL="'weather'",SWETR=1,SWMETDETAIL=0,SWRAIN=0,
        SWCROP=1,SWIRFIX=0,SWINCO=1,SWPONDMX=0,PONDMX=.5,RSRO=.001,RSROEXP=1.,
        SWRUNON=0,SWCFBS=0,SWREDU=0,CFEVAPPOND=1.,RDS=30.,SWSOPHY=0,IHWCKMODEL=1,
        SWHYST=0,SWMACRO=0,SWSNOW=0,SWFROST=0,SWDRA=0,SWBBCFILE=0,SWBOTB=2,SW2=1,
        SINAVE=-.01,SINAMP=0.,SINMAX=1.,SWHEA=0,SWSOLU=1,SWBR=0,SWSP=0,SWDC=0,
        CPRE=0.,CDRAIN=0.,CMLTB='0.,0.,-30.,0.',DDIF=.0001,LDIS=1.,TSCF=.5,
        HTB='0.,-75.,-30.,-75.',SWKIMPL=0,SWCSV=1,NUM_DECIMALS=12,
        INLIST_CSV="'RAIN,RUNOFF,EPOT,EACT,EPD,TPOT,TACT,BOT,WTOT,PD_VOL,DSTOR,BALDEV'",
        DTMIN=1e-7,DTMAX=.1).items():value(key,val)
    table('CROPSTART    CROPEND    CROPFIL CROPTYPE',start.isoformat()+' '+end.isoformat()+" 'crop' 1")
    table('ISUBLAY ISOILLAY HSUBLAY NCOMP','1 1 10.0 2\n2 1 20.0 2')
    table('ORES  OSAT   ALFA   NPAR    LEXP KSATFIT KSATEXM H_ENPR  BDENS',
          '.032 .423 .0135 1.455 .365 4.75 0.0 1300.',
          'ORES OSAT ALFA NPAR LEXP KSATFIT H_ENPR BDENS')
    crop='''IDEV=1
LCC=97
SWHARV=0
SWCF=1
SWINTER=0
SWCO2=0
SWPREP=0
SWSOW=0
SWGERM=0
SCHEDULE=0
SWRD=1
KDIR=.8
KDIF=.6
LAITB=0.,.2,1.,3.,2.,1.
CFTB=0.,1.,2.,1.
RDTB=0.,5.,1.,20.,2.,30.
RDCTB=0.,1.,1.,1.
SWDROUGHT=1
SWOXYGEN=0
HLIM3L=-500.
HLIM3H=-800.
HLIM4=-16000.
ADCRL=.1
ADCRH=.5
'''
    weather_path=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz'
    weather=gzip.decompress(weather_path.read_bytes())
    assert hashlib.sha256(weather).hexdigest()=='ba5c1f880f6166842ed292c18fd12a142cfda4158002f9487fd1420e734e7b72'
    if a.rain==4:
        lines=[]
        for line in weather.decode().splitlines(keepends=True):
            tokens=list(re.finditer(r'\S+',line))
            if len(tokens)==12 and tokens[0][0].startswith("'"):
                t=tokens[9];rain=format(decimal.Decimal(t[0])*4,'f')
                line=line[:t.start()]+rain+line[t.end():]
            lines.append(line)
        weather=''.join(lines).encode()
    (out/'swap.swp').write_text(text);(out/'crop.crp').write_text(crop)
    (out/'weather.999').write_bytes(weather)
    manifest={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in out.iterdir()}
    (out/'INPUTS.json').write_text(json.dumps(dict(days=a.days,rain_multiplier=a.rain,files=manifest,
        template_sha256=hashlib.sha256(template.read_bytes()).hexdigest(),
        scope='Constructed common complete SWP/simple crop/ETref with zero tracer; not WOFOST or original Andelst model'),indent=2)+'\n')
    print(json.dumps(manifest))
if __name__=='__main__':main()
