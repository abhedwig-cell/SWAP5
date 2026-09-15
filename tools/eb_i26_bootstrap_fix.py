from pathlib import Path
import runpy

p = Path('tools/eb_i26_top_outflow_bootstrap.py')
s = p.read_text()
old = '''    """    publication = eb_i25_sensible_boundary_publication_t()\\n\\n    ! Opt in only for this call.\\n""",
    """    publication = eb_i25_sensible_boundary_publication_t()\\n    if (present(accepted_top_candidate)) call accepted_top_candidate%clear()\\n\\n    ! Opt in only for this call.\\n"""'''
new = '''    """    publication = eb_i25_sensible_boundary_publication_t()\\n\\n""",
    """    publication = eb_i25_sensible_boundary_publication_t()\\n    if (present(accepted_top_candidate)) call accepted_top_candidate%clear()\\n\\n"""'''
if s.count(old) != 1:
    raise SystemExit(f'bootstrap repair anchor count={s.count(old)}')
p.write_text(s.replace(old, new, 1))
runpy.run_path(str(p), run_name='__main__')
