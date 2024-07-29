

create_clock  -period 20 [get_ports CLOCK_50]
derive_clocks -period 40
derive_clock_uncertainty