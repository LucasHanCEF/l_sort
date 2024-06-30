`timescale 1ns / 1ps
import conf_pkg::*;


module digital_filter (
    input clk,
    input rst_n,

    input  channel_t s_axis_a_tchannel,
    input  data_t    s_axis_a_tdata,
    input            s_axis_a_tvalid,
    input            s_axis_a_tlast,
    output channel_t m_axis_b_tchannel,
    output data_t    m_axis_b_tdata,
    output logic     m_axis_b_tvalid,
    output logic     m_axis_b_tlast
);

  channel_t                             bram_read_channel;
  logic        [      2*DATA_WIDTH-1:0] bram_dout;
  logic                                 bram_ena;
  channel_t                             bram_write_channel;
  logic        [      2*DATA_WIDTH-1:0] bram_din;
  logic                                 bram_wea;
  logic                                 bram_ceb;

  data_t                                D                  [3];

  logic signed [Q_SCALE+DATA_WIDTH-1:0] d_partial          [3];
  logic signed [Q_SCALE+DATA_WIDTH-1:0] d_temp;
  logic signed [Q_SCALE+DATA_WIDTH-1:0] result_partial     [3];
  logic signed [Q_SCALE+DATA_WIDTH-1:0] result;

  data_t                                data_relay;

  assign D[0] = bram_dout[0+:DATA_WIDTH];
  assign D[1] = bram_dout[DATA_WIDTH+:DATA_WIDTH];
  assign bram_din[0+:DATA_WIDTH] = D[1];
  assign bram_din[DATA_WIDTH+:DATA_WIDTH] = D[2];

  bram_filter u_bram_filter (
      .addra(bram_write_channel),
      .clka (clk),
      .dina (bram_din),
      .ena  (bram_wea),
      .wea  (bram_wea),
      .addrb(bram_read_channel),
      .clkb (clk),
      .doutb(bram_dout),
      .enb  (bram_ena),
      .regceb(bram_ceb)
  );

  assign bram_read_channel = s_axis_a_tchannel;
  assign bram_ena = s_axis_a_tvalid;

  conditional_relay #(
      .CYCLE(2),
      .WIDTH($clog2(CHANNEL_COUNT))
  ) u_conditional_relay_channel (
      .clk(clk),
      .rst_n(rst_n),
      .in(s_axis_a_tchannel),
      .valid(1'b1),
      .out(bram_write_channel)
  );  // Write channel

  conditional_relay #(
      .CYCLE(2),
      .WIDTH(DATA_WIDTH)
  ) u_conditional_relay_data (
      .clk(clk),
      .rst_n(rst_n),
      .in(s_axis_a_tdata),
      .valid(1'b1),
      .out(data_relay)
  );  // Data relay

  conditional_relay #(
      .CYCLE(1),
      .WIDTH(1)
  ) u_conditional_relay_ceb (
      .clk(clk),
      .rst_n(rst_n),
      .in(s_axis_a_tvalid),
      .valid(1'b1),
      .out(bram_ceb)
  );  // Enable read reg
  
  conditional_relay #(
      .CYCLE(1),
      .WIDTH(1)
  ) u_conditional_relay_wea (
      .clk(clk),
      .rst_n(rst_n),
      .in(bram_ceb),
      .valid(1'b1),
      .out(bram_wea)
  );  // Enable read reg

  conditional_relay #(
      .CYCLE(2),
      .WIDTH(1)
  ) u_conditional_relay_last (
      .clk(clk),
      .rst_n(rst_n),
      .in(s_axis_a_tlast),
      .valid(1'b1),
      .out(m_axis_b_tlast)
  );  // Enable read reg

  assign d_partial[0] = {data_relay, {Q_SCALE{data_relay[DATA_WIDTH-1]}}};
  assign d_partial[1] = COE_A1 * D[1];
  assign d_partial[2] = COE_A2 * D[0];
  assign d_temp = d_partial[0] - d_partial[1] - d_partial[2];
  assign D[2] = d_temp[Q_SCALE+DATA_WIDTH-1:Q_SCALE];

  assign result_partial[0] = COE_B0 * D[2];
  assign result_partial[1] = COE_B1 * D[1];
  assign result_partial[2] = COE_B2 * D[0];
  assign result = result_partial[0] + result_partial[1] + result_partial[2];
  assign m_axis_b_tdata = result[Q_SCALE+DATA_WIDTH-1:Q_SCALE];

  assign m_axis_b_tchannel = bram_write_channel;
  assign m_axis_b_tvalid = bram_wea;

endmodule
