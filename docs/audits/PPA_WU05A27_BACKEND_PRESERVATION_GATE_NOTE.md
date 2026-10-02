# PPA-WU05-A27 backend preservation gate note

Current canonical `9abdc23f759f4d7711881d535797d0ee56d67584` carries the pre-DEP02 exact RFM temporal identity and its A26 static gate asserts that identity.

A27 carries DEP01/DEP02 as branch-local qualified repair candidates. The A27 backend-preservation runner is forked from the current canonical A26 runner, so it inherits the current MIGMAC01 compile/dependency surface, but replaces only the mutually exclusive exact-RFM-temporal static assertion with the preregistered DEP02 quantitative metric assertions.

This preserves the governance distinction. It does not claim canonical admission of DEP01/DEP02.
