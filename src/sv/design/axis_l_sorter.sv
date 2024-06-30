`timescale 1ns / 1ps
import conf_pkg::*;


module axis_l_sorter #(
    parameter int ADDR_WIDTH = 12,
    parameter int C_AXIS_TDATA_WIDTH = 32
) (
    /*
     * AXI slave interface (input to the FIFO)
     */
    input  wire                                s00_axis_aclk,
    input  wire                                s00_axis_aresetn,
    input  wire [      C_AXIS_TDATA_WIDTH-1:0] s00_axis_tdata,
    input  wire [(C_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
    input  wire                                s00_axis_tvalid,
    output wire                                s00_axis_tready,
    input  wire                                s00_axis_tlast,

    /*
     * AXI master interface (output of the FIFO)
     */
    input  wire                                m00_axis_aclk,
    input  wire                                m00_axis_aresetn,
    output wire [    2*C_AXIS_TDATA_WIDTH-1:0] m00_axis_tdata,
    output wire [(2*C_AXIS_TDATA_WIDTH/8)-1:0] m00_axis_tstrb,
    output wire                                m00_axis_tvalid,
    input  wire                                m00_axis_tready,
    output wire                                m00_axis_tlast
);

  // *****************
  // Signal Definition
  // *****************

  // raw: output of input ports
  //      input  of filter
  channel_t raw_channel;
  data_t    raw_data;
  logic     raw_valid;
  logic     raw_last;

  channel_t filtered_channel;
  data_t    filtered_data;
  logic     filtered_valid;
  logic     filtered_last;

  udata_t   ufiltered_data;

  time_t    detected_time;
  channel_t detected_channel;
  udata_t   detected_data;
  logic     detected_valid;
  logic     detected_last;

  time_t    grouped_time;
  x_acc_t   grouped_x;
  y_acc_t   grouped_y;
  a_acc_t   grouped_a;
  logic     grouped_valid;
  logic     grouped_ready;
  logic     grouped_last;

  time_t    located_time;
  x_t       located_x;
  y_t       located_y;
  logic     located_valid;
  logic     located_ready;
  logic     located_last;

  assign raw_channel = s00_axis_tdata[$clog2(CHANNEL_COUNT)+DATA_WIDTH-1:DATA_WIDTH];
  assign raw_data = s00_axis_tdata[DATA_WIDTH-1:0];
  assign raw_valid = s00_axis_tvalid;
  assign raw_last = s00_axis_tlast;
  assign s00_axis_tready = 1'b1;

  assign m00_axis_tstrb = {(2*C_AXIS_TDATA_WIDTH/8){m00_axis_tvalid}};

  digital_filter u_digital_filter (
      .clk(s00_axis_aclk),
      .rst_n(s00_axis_aresetn),
      .s_axis_a_tchannel(raw_channel),
      .s_axis_a_tdata(raw_data),
      .s_axis_a_tvalid(raw_valid),
      .s_axis_a_tlast(raw_last),
      .m_axis_b_tchannel(filtered_channel),
      .m_axis_b_tdata(filtered_data),
      .m_axis_b_tvalid(filtered_valid),
      .m_axis_b_tlast(filtered_last)
  );

  assign ufiltered_data = filtered_data[DATA_WIDTH-1] ? (~filtered_data[DATA_WIDTH-2:0] + 1'b1) : filtered_data[DATA_WIDTH-2:0];

  median_detector u_median_detector (
      .clk(s00_axis_aclk),
      .rst_n(s00_axis_aresetn),
      .s_axis_a_tchannel(filtered_channel),
      .s_axis_a_tdata(ufiltered_data),
      .s_axis_a_tvalid(filtered_valid),
      .s_axis_a_tlast(filtered_last),
      .m_axis_b_time(detected_time),
      .m_axis_b_tchannel(detected_channel),
      .m_axis_b_tdata(detected_data),
      .m_axis_b_tvalid(detected_valid),
      .m_axis_b_tlast(detected_last)
  );

  spike_grouper u_spike_grouper (
      .clk(s00_axis_aclk),
      .rst_n(s00_axis_aresetn),
      .s_axis_a_time(detected_time),
      .s_axis_a_tchannel(detected_channel),
      .s_axis_a_tdata(detected_data),
      .s_axis_a_tvalid(detected_valid),
      .s_axis_a_tlast(detected_last),
      .m_axis_b_time(grouped_time),
      .m_axis_b_tx(grouped_x),
      .m_axis_b_ty(grouped_y),
      .m_axis_b_ta(grouped_a),
      .m_axis_b_tvalid(grouped_valid),
      .m_axis_b_tready(grouped_ready),
      .m_axis_b_tlast(grouped_last)
  );

  spike_locator u_spike_locator (
      .clk(s00_axis_aclk),
      .rst_n(s00_axis_aresetn),
      .s_axis_a_time(grouped_time),
      .s_axis_a_tx(grouped_x),
      .s_axis_a_ty(grouped_y),
      .s_axis_a_ta(grouped_a),
      .s_axis_a_tvalid(grouped_valid),
      .s_axis_a_tready(grouped_ready),
      .s_axis_a_tlast(located_last),
      .m_axis_b_time(located_time),
      .m_axis_b_tx(located_x),
      .m_axis_b_ty(located_y),
      .m_axis_b_tvalid(located_valid),
      .m_axis_b_tready(located_ready),
      .m_axis_b_tlast(located_last)
  );

  o_sort u_o_sort (
      .clk(m00_axis_aclk),
      .rst_n(m00_axis_aresetn),
      .s_axis_a_time(located_time),
      .s_axis_a_tx(located_x),
      .s_axis_a_ty(located_y),
      .s_axis_a_tvalid(located_valid),
      .s_axis_a_tready(located_ready),
      .s_axis_a_tlast(located_last),
      .m_axis_b_tdata(m00_axis_tdata),
      .m_axis_b_tvalid(m00_axis_tvalid),
      .m_axis_b_tready(m00_axis_tready),
      .m_axis_b_tlast(m00_axis_tlast)
  );



endmodule
