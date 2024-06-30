`timescale 1ns / 1ps
import conf_pkg::*;


module spike_locator (
    input clk,
    input rst_n,

    input  time_t    s_axis_a_time,
    input  x_acc_t   s_axis_a_tx,
    input  x_acc_t   s_axis_a_ty,
    input  a_acc_t   s_axis_a_ta,
    input            s_axis_a_tvalid,
    output logic     s_axis_a_tready,
    input            s_axis_a_tlast,
    output time_t    m_axis_b_time,
    output x_t       m_axis_b_tx,
    output y_t       m_axis_b_ty,
    output logic     m_axis_b_tvalid,
    input            m_axis_b_tready,
    output logic     m_axis_b_tlast
);

  localparam DIV_LATENCY = 33;

  logic is_last;

  logic [3:0] divider_ready;
  logic [1:0] divider_valid;
  logic [31:0] divider_result [2];

  enum logic [1:0] {
    IDLE,
    CALC,
    SEND
  } state;

  loc_divider u_loc_divider_0(
    .aclk(clk),
    .s_axis_divisor_tdata({7'b0, s_axis_a_ta}),
    .s_axis_divisor_tready(divider_ready[0]),
    .s_axis_divisor_tvalid(s_axis_a_tvalid),
    .s_axis_dividend_tdata({4'b0, s_axis_a_tx}),
    .s_axis_dividend_tready(divider_ready[1]),
    .s_axis_dividend_tvalid(s_axis_a_tvalid),
    .m_axis_dout_tdata(divider_result[0]),
    .m_axis_dout_tvalid(divider_valid[0])
  );

  loc_divider u_loc_divider_1(
    .aclk(clk),
    .s_axis_divisor_tdata({7'b0, s_axis_a_ta}),
    .s_axis_divisor_tready(divider_ready[2]),
    .s_axis_divisor_tvalid(s_axis_a_tvalid),
    .s_axis_dividend_tdata({4'b0, s_axis_a_ty}),
    .s_axis_dividend_tready(divider_ready[3]),
    .s_axis_dividend_tvalid(s_axis_a_tvalid),
    .m_axis_dout_tdata(divider_result[1]),
    .m_axis_dout_tvalid(divider_valid[1])
  );

  assign s_axis_a_tready = &divider_ready;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (&divider_ready & s_axis_a_tvalid) begin
            state <= CALC;
          end
          else begin
            state <= IDLE;
          end
        end
        CALC: begin
          if (&divider_valid) begin
            state <= SEND;
          end
          else begin
            state <= CALC;
          end
        end
        SEND: begin
          if (m_axis_b_tready) begin
            state <= IDLE;
          end
          else begin
            state <= SEND;
          end
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_time <= 0;
    end else begin
      if (state == IDLE & s_axis_a_tvalid) begin
        m_axis_b_time <= s_axis_a_time;
      end else begin
        m_axis_b_time <= m_axis_b_time;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_tx <= 0;
      m_axis_b_ty <= 0;
    end else begin
      if (state == CALC & &divider_valid) begin
        m_axis_b_tx <= divider_result[0][10:0];
        m_axis_b_ty <= divider_result[1][10:0];
      end else begin
        m_axis_b_tx <= m_axis_b_tx;
        m_axis_b_ty <= m_axis_b_tx;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_tvalid <= 0;
    end else begin
      if (state == SEND & m_axis_b_tready) begin
        m_axis_b_tvalid <= 1;
      end else begin
        m_axis_b_tvalid <= 0;
      end
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      is_last <= 0;
    end else begin
      if ((s_axis_a_tlast | is_last) & ((state != IDLE) | ~m_axis_b_tready)) begin
        is_last <= 1'b1;
      end else begin
        is_last <= 1'b0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_tlast <= 0;
    end else begin
      if ((s_axis_a_tlast | is_last) & (state == IDLE) & m_axis_b_tready) begin
        m_axis_b_tlast <= 1'b1;
      end else begin
        m_axis_b_tlast <= 1'b0;
      end
    end
  end

endmodule
