// X-ALP's testbench utilities (hw/vendor/x-alp/tb/src/verilator/tb_util.svh), with the
// hierarchical paths moved under gr_alp. mcu-gen runs from X-ALP's root directory.
${open("tb/src/verilator/tb_util.svh").read().replace("u_x_alp.", "u_gr_alp.u_x_alp.")}
