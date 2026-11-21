"""Prove the entire original initializer survives one bounded admission block."""
import ast,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='56df667d37c6e4070d6e552e493ddc0e28880a28'
CORE='9e19329049ef92705fdca98948b4c4c1baba2ffa'
PATH='app/hybrid_water/experimental_project.py'
SURFACES=('app','src','tools/solute','tools/vq','reference')
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed initial pressure profile source delta'
 assert git('diff','--name-only',BASE,CORE,'--',*SURFACES).decode().splitlines()==[PATH]
 before=git('show',BASE+':'+PATH);after=(ROOT/PATH).read_bytes().replace(b'\r\n',b'\n');assert after==git('show',CORE+':'+PATH)
 a,b=ast.parse(before),ast.parse(after)
 f=lambda tree:next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='inspect')
 added=[n for n in f(b).body if isinstance(n,ast.If) and ast.unparse(n.test)=="selected.get('SWINCO') == 1"];assert len(added)==1
 f(b).body.remove(added[0]);assert ast.dump(a,include_attributes=False)==ast.dump(b,include_attributes=False),'Incomplete original input adapter inverse'
 return True
