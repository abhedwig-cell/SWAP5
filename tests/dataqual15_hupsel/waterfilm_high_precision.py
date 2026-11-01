"""Independent incomplete-beta and log-quadrature witnesses for actual MvG films.

For u=(alpha*x)^n and z=u/(1+u), integral f(x)dx equals
Capac/(4*pi*sigma^2*n*alpha^3) * B_z(1+2/n, m-2/n).
Both endpoints stay strictly inside (0,1), including negative beta parameter.
This is numerical verification, not a replacement production model.
"""
import argparse,json,hashlib
from pathlib import Path
import mpmath as mp

def witness(fields,node,digits):
 with mp.workdps(digits):
  row=[mp.mpf(x)for x in fields];c=row[6:30];n=c[5];m=c[6];alpha=c[3]/100;upper=-row[3]*100;lower=mp.mpf('1e-10');temperature=row[5]+273
  sigma=mp.mpf('0.07275')*(1-mp.mpf('0.002')*(temperature-291));capac=(c[1]-c[0])*alpha*n*m
  def f(x):return capac*(alpha*x)**(n-1)*(1+(alpha*x)**n)**(-m-1)*x*x/(4*mp.pi*sigma*sigma)
  def z(x):u=(alpha*x)**n;return u/(1+u)
  beta=capac/(4*mp.pi*sigma*sigma*n*alpha**3)*mp.betainc(1+2/n,m-2/n,z(lower),z(upper))
  logarithmic=mp.quad(lambda t:f(mp.exp(t))*mp.exp(t),[mp.log(lower),mp.log(lower)+(mp.log(upper)-mp.log(lower))/2,mp.log(upper)])
  assert abs(beta-logarithmic)<mp.mpf('1e-35')*abs(beta)
  film=2*(mp.sqrt(1/(mp.pi*beta))-2*sigma/upper)
  return dict(node=node,digits=digits,integral_beta=mp.nstr(beta,40),integral_log_quad=mp.nstr(logarithmic,40),film_m=mp.nstr(film,40))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cases',type=Path,required=True);p.add_argument('--node',type=int,default=7);p.add_argument('--output',type=Path,required=True);a=p.parse_args();records=[]
 with a.cases.open()as f:
  while header:=f.readline():
   n=int(header.split()[2]);lines=[next(f)for _ in range(3+n)];row=lines[3+a.node-1].split();values=[witness(row,a.node,d)for d in [50,80]]
   assert abs(mp.mpf(values[0]['film_m'])-mp.mpf(values[1]['film_m']))<mp.mpf('1e-30');records.append(dict(t0=header.split()[0],witnesses=values))
 a.output.write_text(json.dumps(dict(status='INDEPENDENT_BETA_AND_LOG_QUADRATURE_PASS',mpmath_version=mp.__version__,input_sha256=hashlib.sha256(a.cases.read_bytes()).hexdigest(),records=records),indent=2)+'\n');print(json.dumps(records,indent=2))
if __name__=='__main__':main()
