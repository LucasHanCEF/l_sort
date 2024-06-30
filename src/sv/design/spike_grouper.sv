`timescale 1ns / 1ps
import conf_pkg::*;


module spike_grouper (
    input clk,
    input rst_n,

    input  time_t    s_axis_a_time,
    input  channel_t s_axis_a_tchannel,
    input  udata_t   s_axis_a_tdata,
    input            s_axis_a_tvalid,
    input            s_axis_a_tlast,
    output time_t    m_axis_b_time,
    output x_acc_t   m_axis_b_tx,
    output y_acc_t   m_axis_b_ty,
    output a_acc_t   m_axis_b_ta,
    output logic     m_axis_b_tvalid,
    input            m_axis_b_tready,
    output logic     m_axis_b_tlast
);

  genvar i;

  time_t time_buffer[BUFFER_DEPTH];
  channel_t channel_buffer[BUFFER_DEPTH];
  x_acc_t x_acc_buffer[BUFFER_DEPTH];
  y_acc_t y_acc_buffer[BUFFER_DEPTH];
  a_acc_t a_acc_buffer[BUFFER_DEPTH];
  udata_t data_buffer[BUFFER_DEPTH];

  buffer_pointer_t buffer_pointer;

  time_t time_diff_buffer[BUFFER_DEPTH];
  channel_t channel_diff_buffer[BUFFER_DEPTH];

  logic [BUFFER_DEPTH-1:0] fall_in;
  buffer_pointer_t fall_in_index;
  logic fall_in_valid;
  
  logic is_last;

  generate
    for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin : gen_diff
      assign time_diff_buffer[i] = s_axis_a_time - time_buffer[i];
      assign channel_diff_buffer[i] = (channel_buffer[i] > s_axis_a_tchannel) ? (channel_buffer[i] - s_axis_a_tchannel) : (s_axis_a_tchannel - channel_buffer[i]);
      assign fall_in[i]  = ((time_diff_buffer[i] <= TIME_TH) & (channel_diff_buffer[i] <= CHANNEL_TH));
    end
  endgenerate

  check_fall_in u_check_fall_in (
      .fall_in(fall_in),
      .index  (fall_in_index),
      .valid  (fall_in_valid)
  );

  generate
    for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin : gen_buffer
      always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
          time_buffer[i] <= 0;
          channel_buffer[i] <= 0;
          x_acc_buffer[i] <= 0;
          y_acc_buffer[i] <= 0;
          a_acc_buffer[i] <= 0;
          data_buffer[i] <= 0;
        end else begin
          if (s_axis_a_tvalid & fall_in_valid & (fall_in_index == i)) begin
            if (data_buffer[i] < s_axis_a_tdata) begin
              time_buffer[i] <= s_axis_a_time;
              channel_buffer[i] <= s_axis_a_tchannel;
              data_buffer[i] <= s_axis_a_tdata;
            end else begin
              time_buffer[i] <= time_buffer[i];
              channel_buffer[i] <= channel_buffer[i];
              data_buffer[i] <= data_buffer[i];
            end
            x_acc_buffer[i] <= x_acc_buffer[i] + s_axis_a_tdata * s_axis_a_tchannel[0] * INTERVEL;
            y_acc_buffer[i] <= y_acc_buffer[i] + s_axis_a_tdata * s_axis_a_tchannel[$clog2(
                CHANNEL_COUNT
            )-1:1] * INTERVEL;
            a_acc_buffer[i] <= a_acc_buffer[i] + s_axis_a_tdata;
          end else if (s_axis_a_tvalid & ~fall_in_valid & (buffer_pointer == i)) begin
            time_buffer[i] <= s_axis_a_time;
            channel_buffer[i] <= s_axis_a_tchannel;
            data_buffer[i] <= s_axis_a_tdata;
            x_acc_buffer[i] <= s_axis_a_tdata * s_axis_a_tchannel[0] * INTERVEL;
            y_acc_buffer[i] <= s_axis_a_tdata * s_axis_a_tchannel[$clog2(
                CHANNEL_COUNT
            )-1:1] * INTERVEL;
            a_acc_buffer[i] <= s_axis_a_tdata;
          end else if (~s_axis_a_tvalid & (time_diff_buffer[0] > TIME_TH) & buffer_pointer & m_axis_b_tready & (buffer_pointer >= i)) begin
            time_buffer[i] <= time_buffer[i+1];
            channel_buffer[i] <= channel_buffer[i+1];
            data_buffer[i] <= data_buffer[i+1];
            x_acc_buffer[i] <= x_acc_buffer[i+1];
            y_acc_buffer[i] <= y_acc_buffer[i+1];
            a_acc_buffer[i] <= a_acc_buffer[i+1];
          end else begin
            time_buffer[i] <= time_buffer[i];
            channel_buffer[i] <= channel_buffer[i];
            data_buffer[i] <= data_buffer[i];
            x_acc_buffer[i] <= x_acc_buffer[i];
            y_acc_buffer[i] <= y_acc_buffer[i];
            a_acc_buffer[i] <= a_acc_buffer[i];
          end
        end
      end
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      buffer_pointer <= 0;
    end else begin
      if (s_axis_a_tvalid & !fall_in_valid & (buffer_pointer <= BUFFER_DEPTH - 1)) begin
        buffer_pointer <= buffer_pointer + 1;
      end else if (~s_axis_a_tvalid & (time_diff_buffer[0] > TIME_TH) & buffer_pointer & m_axis_b_tready) begin
        buffer_pointer <= buffer_pointer - 1;
      end else begin
        buffer_pointer <= buffer_pointer;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_time <= 0;
      m_axis_b_tx <= 0;
      m_axis_b_ty <= 0;
      m_axis_b_ta <= 0;
      m_axis_b_tvalid <= 0;
    end else begin
      if (~s_axis_a_tvalid & (time_diff_buffer[0] > TIME_TH) & buffer_pointer & m_axis_b_tready) begin
        m_axis_b_time <= time_buffer[0];
        m_axis_b_tx <= x_acc_buffer[0];
        m_axis_b_ty <= y_acc_buffer[0];
        m_axis_b_ta <= a_acc_buffer[0];
        m_axis_b_tvalid <= 1;
      end else begin
        m_axis_b_time <= 0;
        m_axis_b_tx <= 0;
        m_axis_b_ty <= 0;
        m_axis_b_ta <= 0;
        m_axis_b_tvalid <= 0;
      end
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        is_last <= 1'b0;
    end
    else begin
        if ((s_axis_a_tlast | is_last) & (buffer_pointer != 0)) begin
            is_last <= 1'b1;
        end
        else begin
            is_last <= 1'b0;
        end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_tlast <= 1'b0;
    end else begin
      if ((is_last | s_axis_a_tlast) & (buffer_pointer == 0)) begin
        m_axis_b_tlast <= 1'b1;
      end else begin
        m_axis_b_tlast <= 1'b0;
      end
    end
  end

endmodule
