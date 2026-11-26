import os,sys
os.environ['MACRO_REPLAY_MODE']=sys.argv.pop(1)
assert os.environ['MACRO_REPLAY_MODE'] in ['NORMAL','DIRECT']
from run_worker_window import main
raise SystemExit(main())
