# No-macro CI checkout transport

Status: implemented; actual current CI and canonical admission pending.
This is an ACCELERATE02 build/evidence transport change. It adds no model scope,
physical equations, numerical policy, compiler flags, tolerances or state.

Thirteen selected workflows contain43 unfiltered, unsparse checkout steps.
The existing sparse LRV workflow is retained unchanged. The proposed inputs use
partial clone and a non-cone checkout that includes every source, test, reference
input, document and JSON metadata file. Only complete ZIPs and three-digit ZIP
parts directly under integration/f-ci/nomacro-complete01 are omitted from the
working directory. Their genuine Git objects remain the evidence authority;
readers retrieve and verify those exact original bytes through GitArchiveSource.
No fabricated working files or projected HEAD are introduced.

Every workflow has a complete literal inverse against its real qualified parent.
Local YAML comparison confirms all other values and all run commands stay
identical. Real Git check-rules on the16759-path qualified candidate selects
every source/input/metadata path and excludes exactly739 archive paths. These
are selection checks, not a measured CI speedup or scientific qualification.

The dependency candidate is PR1805 cb712974e37e41256877d9770a0af071afe241dd.
Its new64-context science is already independently qualified, but its canonical
admission is still pending. Original producer identities and raw evidence are
retained. No unchanged scientific model periods are replayed for this change.

The existing STATUS.json remains the recovery point. After actual PR1805
admission, reconcile its genuine merge normally, retain its original receipt,
and qualify the actual current checkout/dependency postimage and selected CI.
Historical closure remains PARTIAL, whole science NOT_QUALIFIED, global
family/gap counts UNKNOWN and fixed RC3 unchanged.
