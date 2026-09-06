# A23BN natural retry finding

A qualification-only counter was inserted at the existing B1.6 `TimeControl(5)` branch that executes when `fldecdt` is true. Over the Hupsel continuation 2002-01-04 through 2002-01-05 it observed 10 genuine internal timestep reductions under the unchanged default numerical configuration.

The observer is measurement-only. A binary dump containing `h`, `theta`, `tsoil`, `cml`, `pond`, `dt`, `ldwet` and `gwl` is byte-identical with and without the counter. Both dumps hash to:

`2c68fd7b14016c8e3160589970c0d5b78490e7165c9610e2da0839aabf321883`

This proves a natural retry path is active in the qualified physical interval and motivates making retry count/cost a first-class result of the future soil-water execution interface. The observer itself is VQ instrumentation and is not production state.
