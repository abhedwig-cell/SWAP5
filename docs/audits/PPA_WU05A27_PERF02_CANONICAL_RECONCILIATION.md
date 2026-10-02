# PPA-WU05-A27 PERF02 current-canonical reconciliation

Date: 2026-10-02

PERF02 qualified on branch postimage `d456cccd92667d035a2988cc2228d0402eadd58a`, run `36998043191`.

Canonical then advanced to `9abdc23f759f4d7711881d535797d0ee56d67584` through MIGMAC01 and changes the shared serialized backend, solver contract, default MvG provider and standard-macropore runtime.

Three-way policy:
- current MIGMAC01 canonical files are authority;
- A27-only files, including PERF02 live-preparation zero-waste changes, are replayed;
- the shared backend is taken from current canonical and receives only the already-qualified DEP01 exact RFM carrier case and DEP02 quantitative RFM full/half metric;
- current canonical `tests/fpm/run_ppa_wu05a26_backend_compile.sh` is retained rather than overwritten by the older A27 copy.

No MIGMAC01 source change is replaced wholesale.

The merged postimage requires the full PERF02 qualification workflow again before current-canonical compatibility is claimed.
