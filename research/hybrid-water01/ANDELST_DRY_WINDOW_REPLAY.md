# Andelst dry window native V9 replay

Canonical source pin: `7535a9e650aa01ca3ee711353c2e2801e2872f00`.
See [the same-state comparison](ANDELST_SAME_STATE_WATER.md) for the
B0 observations and the archive binding.

## Native execution and strict restart

The Linux GNU Fortran 13.3 O2 observation build continued from its
verified day-367 restart through day 457, without changing the model
equations. The 90 daily budgets and 45,119 source intervals matched
the archived V9 chronology and attempt counts. The largest daily
absolute differences against the archive were 7.71e-16 cm for bottom
exchange and 5.56e-16 cm for rapid drainage. The accepted day-453
checkpoint was captured and used to start a fresh Linux process for
days 454–457. Daily budgets, progress, cost, diagnostics, accepted
water observations, final head and temperature outputs and final
restart were byte-identical between the two Linux executions.

- Day-453 native checkpoint: `a9697a25df0636aeeb9762d95f3026ccfca7f5f9a71e3fc4e8cf4a11440a0674`.
- Day-457 native checkpoint: `415b706b46f48d876635f1a97ea7f2d0981fff45ea08dcd3be3a5310504492d5`.
- Observation executable: `ae1812a7edfdcd6c08520f21e67d4a8971d0546f9e62347c2d66369bb43e437a`.

To reproduce, render the V9 upper-support candidate and add read-only
printing inside the existing accepted water receipt loop of
`app/solute_project/main_water.f90`. For days 454–457 record interval
endpoints, bottom flux, start/end domain-1 water, rapid outflow,
external and pond-fed macro supply, and domain-1 matrix exchange.
At the day-end snapshot print all nodal pressure heads. Reuse the
V9 archive inputs and its year replay command, replacing the binary,
restart path, stop window and stop time. This is an experimental
native checkpoint tied to the reviewed V9 state and binding. It is
not a production restart admission.

## Four dry days, March 30 through April 2

All quantities are mm per column area, summed over the four days.

| Water movement or stock | B0 | V9 |
|---|---:|---:|
| Net bottom inflow | 5.0600 | 11.8552 |
| Matrix to main macropore domain, signed | -0.1609 | 6.0064 |
| Surface to main macropore domain | 0 | 0 |
| Rapid macropore outflow | 0 | 5.8476 |
| Change in main-domain water stock | -0.1609 | 0.1588 |

V9's 4,010 accepted substeps close the main-domain stock equation
to a maximum absolute residual of 2.17e-16 cm per step in this
window. The B0 instrumentation yielded 12,423 accepted steps and
preserved the original daily series. V9 starts with 1.0965 mm more
water in the main macropore domain than B0. The measured 6.0064 mm
of net matrix supply accounts for the rapid discharge plus the
observed increase in stock. The extra bottom inflow and the excess
transfer from matrix to macropores occur together. These ledgers do
not isolate their causal order.

At the end of the first three days V9 bottom-cell pressure is
1.68–1.83 cm lower than B0. Its accepted bottom flux at those endpoints
is 0.2910–0.3040 cm/day against B0's 0.1259–0.1288 cm/day. The four
end-of-day V9 rates and pressures imply a conductivity of 10 cm/day
using the known aquifer head and half-cell resistance. The matching
B0 endpoints directly record 10 cm/day. The B0 endpoint on April 2
is an exception: its instantaneous flux exceeds V9, while its daily
integral remains smaller. Endpoint samples do not establish that
conductivity matches throughout each day.

The measured discrepancy to resolve is the sustained reversal in
matrix/main-domain exchange. Use the day-453 checkpoint to compare
saturated matrix inflow, perched interflow and absorption separately
on accepted states. Keep the independently established bottom-law
and rapid-potential same-state controls when testing a change.
