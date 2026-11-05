"""Private precommit-only generation publication candidate, no production admission."""
import hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='57849a4d3a02abeb54a297be0fde215160309bfd'
C='app/support/restart_publish.c'
SOURCES=['src/adapter/mod_crop_n_output_generation.f90','src/adapter/mod_crop_n_saved_generation.f90','src/adapter/mod_crop_ext_csv_file.f90']
sha=lambda b:hashlib.sha256(b).hexdigest()
def before(n):return subprocess.check_output(['git','show',BASE+':'+n],cwd=ROOT).decode()
def candidate_c():
 s=before(C);old='static int publish(const char *pending, const char *target, int failure) {';assert s.count(old)==1
 s=s.replace(old,'static int publish(const char *pending, const char *target, int failure, int directory_sync) {',1)
 a=s.index('    /* Open the destination directory before altering the published name. */');z=s.index('    fd = failure == 2',a)
 block=s[a:z];s=s[:a]+'    directory = -1;\n    if (directory_sync) {\n'+''.join('    '+l+'\n'for l in block.splitlines())+'    }\n'+s[z:]
 s=s.replace('if (!status && (failure == 6 || fsync(directory)))','if (!status && directory_sync && (failure == 6 || fsync(directory)))').replace('if (close(directory) && !status)','if (directory_sync && close(directory) && !status)')
 s=s.replace('return publish(pending, target, 0);','return publish(pending, target, 0, 1);').replace('return publish(pending, target, failure);','return publish(pending, target, failure, 1);')
 anchor='/* Same reflected CRC-32/ISO-HDLC bytes';i=s.index(anchor)
 addition='''/* Complete generation callers publish their staged owners only after success.
 * Retain their existing file-flush + atomic-name contract: no fallible step
 * after replacement. Directory durability remains the restart API contract.
 * Windows Fortran path handling is qualified only for ASCII in this scope.
 */
static int generation_paths(const char *pending, const char *target) {
#ifdef _WIN32
    const unsigned char *p;
    if (!pending || !target) return 0;
    for (p=(const unsigned char *)pending; *p; ++p) if (*p>127) return 0;
    for (p=(const unsigned char *)target; *p; ++p) if (*p>127) return 0;
#else
    (void)pending; (void)target;
#endif
    return 1;
}
API int swap5_generation_publish(const char *pending, const char *target) {
    if (!generation_paths(pending,target)) return 1;
    return publish(pending,target,0,0);
}
#ifdef SWAP5_RESTART_TESTING
API int swap5_generation_publish_test(const char *pending, const char *target, int failure) {
    if (failure && (failure<2 || failure>5)) return 1;
    if (!generation_paths(pending,target)) return 1;
    return publish(pending,target,failure,0);
}
#endif

'''
 return s[:i]+addition+s[i:]
def candidate(n):
 s=before(n);s=s.replace('! POSIX complete-file exporter;','! Complete-file exporter;').replace('! Same-platform POSIX','! Same-platform native')
 s=s.replace("function c_rename(old,new)bind(C,name='rename')", "function c_publish(old,new)bind(C,name='swap5_generation_publish')").replace('io=c_rename(','io=c_publish(')
 if n in SOURCES[:2]:
  for name in ('c_open','c_fsync','c_close'):
   pattern=r'^  function '+name+r'\(.*?^  end function\n';s,count=re.subn(pattern,'',s,flags=re.M|re.S);assert count==1,(n,name)
  a=s.index('  fd=c_open(pending//c_null_char,0_c_int)');z=s.index('  io=c_publish(',a);s=s[:a]+s[z:]
 return s

def guard():
 assert not subprocess.check_output(['git','diff',BASE,'--','src','app','reference'],cwd=ROOT)
 assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','src','app','reference'],cwd=ROOT)
 r=json.loads((ROOT/'integration/dataqual15_hupsel/GENERATION_PUBLICATION_PREREGISTRATION_20261106.json').read_text());assert r['baseline']==BASE and r['production_delta']==[]
 for p,h in r['source_sha256'].items():assert sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==h,p
 return r
