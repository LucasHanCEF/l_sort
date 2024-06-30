`timescale 1ns / 1ps
import conf_pkg::*;


module median_detector (
    input clk,
    input rst_n,

    input  channel_t s_axis_a_tchannel,
    input  udata_t   s_axis_a_tdata,
    input            s_axis_a_tvalid,
    input  logic     s_axis_a_tlast,
    output time_t    m_axis_b_time,
    output channel_t m_axis_b_tchannel,
    output udata_t   m_axis_b_tdata,
    output           m_axis_b_tvalid,
    output logic     m_axis_b_tlast
);

  genvar i;

  channel_t bram_read_channel;
  window_t bram_read_counter[WINDOW_LENGTH-1];
  udata_t bram_read_data[WINDOW_LENGTH-1];
  logic bram_ena;
  channel_t bram_write_channel;
  window_t bram_write_counter[WINDOW_LENGTH-1];
  udata_t bram_write_data[WINDOW_LENGTH-1];
  logic bram_wea;
  logic bram_ceb;

  logic [(WINDOW_LENGTH-1)*($clog2(WINDOW_LENGTH-1)+DATA_WIDTH-1)-1:0] bram_dout;
  logic [(WINDOW_LENGTH-1)*($clog2(WINDOW_LENGTH-1)+DATA_WIDTH-1)-1:0] bram_din;
  
  window_t tmp_counter[WINDOW_LENGTH-2];
  udata_t  tmp_data[WINDOW_LENGTH-2];

  logic unsigned [DATA_WIDTH-1+5-1:0] com[2];

  logic vld_relay;

  generate
    for (i = 0; i < WINDOW_LENGTH - 1; i++) begin : gen_bram
      assign bram_read_counter[i] = bram_dout[(($clog2(WINDOW_LENGTH-1)+DATA_WIDTH-1)*i+DATA_WIDTH-1)+:$clog2(WINDOW_LENGTH-1)];
      assign bram_read_data[i] = bram_dout[(($clog2(WINDOW_LENGTH-1)+DATA_WIDTH-1)*i)+:(DATA_WIDTH-1)];
      assign bram_din[(($clog2(WINDOW_LENGTH-1)+DATA_WIDTH-1)*i+DATA_WIDTH-1)+:$clog2(WINDOW_LENGTH-1)] = bram_write_counter[i];
      assign bram_din[(($clog2(WINDOW_LENGTH-1)+DATA_WIDTH-1)*i)+:(DATA_WIDTH-1)] = bram_write_data[i];
    end
  endgenerate

  bram_median u_bram_median (
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

  window_t index_in;
  window_t index_out;
  window_t index_insert;
  window_t reduced_counter[WINDOW_LENGTH-1];

  assign bram_read_channel = s_axis_a_tchannel;  // provide addr to read data from buffer
  assign bram_ena = s_axis_a_tvalid;

  assign m_axis_b_tchannel = bram_write_channel;  // delay channel for detected

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
      .out(m_axis_b_tdata)
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

    conditional_relay #(
      .CYCLE(2),
      .WIDTH(1)
    ) u_conditional_relay_vld (
      .clk(clk),
      .rst_n(rst_n),
      .in(s_axis_a_tvalid),
      .valid(1'b1),
      .out(vld_relay)
  );  // Enable read reg

  insert_index u_insert_index (
      .buffer(bram_read_data),
      .data  (m_axis_b_tdata),
      .index (index_in)
  );  // calculate index for inserting

  generate
    for (i = 0; i < WINDOW_LENGTH - 1; i++) begin : gen_reduced_counter
      assign reduced_counter[i] = bram_read_counter[i] - 1;  // reduce counter
    end
  endgenerate

  always_comb begin
    index_out = 0;
    for (int j = 0; j < WINDOW_LENGTH - 1; j = j + 1) begin
      if (reduced_counter[j] == {$clog2(WINDOW_LENGTH - 1) {1'b0}}) begin
        index_out = j;  // find expired index
        break;
      end
    end
  end

  assign index_insert = index_in - (index_out < index_in);  // find write-location for new data

  generate
    for (i = 0; i < WINDOW_LENGTH - 2; i++) begin : gen_tmp
      assign tmp_counter[i] = reduced_counter[i + (i >= index_out)];
      // write back counter
      assign tmp_data[i] = bram_read_data[i + (i >= index_out)];
      // write back data
    end
  endgenerate


  generate
    for (i = 0; i < WINDOW_LENGTH - 1; i++) begin : gen_writer
      assign bram_write_counter[i] = (index_insert == i) ? (WINDOW_LENGTH-1) : tmp_counter[i - (i > index_insert)];
      // write back counter
      assign bram_write_data[i] = (index_insert == i) ? m_axis_b_tdata : tmp_data[i - (i > index_insert)];
      // write back data
    end
  endgenerate

  assign com[0] = {5'b0, m_axis_b_tdata};
  assign com[1] = {bram_write_data[(WINDOW_LENGTH-1)/2], 5'b0};
  assign m_axis_b_tvalid = (com[0] > com[1]) & (com[0] > 32);

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_time <= 0;
    end else begin
      if ((m_axis_b_tchannel == CHANNEL_COUNT - 1) & vld_relay) begin
        m_axis_b_time <= m_axis_b_time + 1'b1;
      end else begin
        m_axis_b_time <= m_axis_b_time;
      end
    end
  end

endmodule
