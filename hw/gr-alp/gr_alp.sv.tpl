// Copyright 2026 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: gr_alp.sv
// Description: GR-ALP top-level module on X-ALP. The DRAM port of the
//              last-level cache is exposed to the board wrapper; the external
//              AXI and register interfaces are where GR-ALP IPs plug in.

<%!
    from pads.pin import Input, Output, Inout
%>
<%
    # One top-level port per pad, named as in x_alp
    pad_ports = []
    for pad in xheep.get_padring().pad_list:
        has_in = any(isinstance(pin, Input) for pin in pad.pins)
        has_out = any(isinstance(pin, Output) for pin in pad.pins)
        has_inout = any(isinstance(pin, Inout) for pin in pad.pins)
        if not (has_in or has_out or has_inout):
            continue
        suffix = "io" if has_inout or (has_in and has_out) else ("i" if has_in else "o")
        pad_ports.append(pad.pins[0].rtl_name() + suffix)
%>
module gr_alp (
    // DRAM interface (last-level cache master port)
    output core_v_mcu_pkg::axi_llc_req_t ext_llc_req_o,
    input  core_v_mcu_pkg::axi_llc_rsp_t ext_llc_rsp_i,

    // Test mode
    input logic test_mode_i,

    // Exit interface
    output logic [31:0] exit_value_o,

    // Pads
% for port in pad_ports:
    inout wire ${port}${"" if loop.last else ","}
% endfor
);

  // No GR-ALP IPs yet: external slaves never answer, external masters stay idle
  x_alp u_x_alp (
      .ext_slv_req_o(),
      .ext_slv_rsp_i('0),
      .ext_mst_req_i('0),
      .ext_mst_rsp_o(),
      .ext_llc_req_o(ext_llc_req_o),
      .ext_llc_rsp_i(ext_llc_rsp_i),
      .ext_reg_req_o(),
      .ext_reg_rsp_i('0),
      .test_mode_i  (test_mode_i),
      .exit_value_o (exit_value_o),
% for port in pad_ports:
      .${port}(${port})${"" if loop.last else ","}
% endfor
  );

endmodule
