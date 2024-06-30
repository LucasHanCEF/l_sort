`timescale 1ns / 1ps
import conf_pkg::*;


module o_sort (
    input clk,
    input rst_n,

    input  time_t        s_axis_a_time,
    input  x_t           s_axis_a_tx,
    input  y_t           s_axis_a_ty,
    input                s_axis_a_tvalid,
    output logic         s_axis_a_tready,
    input                s_axis_a_tlast,
    output logic  [63:0] m_axis_b_tdata,
    output logic         m_axis_b_tvalid,
    input                m_axis_b_tready,
    output logic         m_axis_b_tlast
);

  genvar i;

  cluster_t cluster_bottom;

  time_t spike_time;
  cluster_t spike_cluster;
  x_t spike_x;
  y_t spike_y;

  cluster_t bram_write_channel;
  p_t       bram_din;
  logic     bram_wea;
  cluster_t bram_read_channel;
  p_t       bram_dout;
  logic     bram_ena;     

  x_t write_x;
  y_t write_y;
  x_t read_x;
  y_t read_y;

  logic unsigned [2*Y_WIDTH-1:0] loc_diff;
  logic is_existing;
  logic is_merge;

  logic is_last;

  bram_median u_bram_cluster (
      .addra(bram_write_channel),
      .clka (clk),
      .dina (bram_din),
      .ena  (bram_wea),
      .wea  (bram_wea),
      .addrb(bram_read_channel),
      .clkb (clk),
      .doutb(bram_dout),
      .enb  (bram_ena)
  );

  assign bram_din[X_WIDTH-1:0] = write_x;
  assign bram_din[X_WIDTH+Y_WIDTH-1:X_WIDTH] = write_y;
  assign read_x = bram_dout[X_WIDTH-1:0];
  assign read_y = bram_dout[X_WIDTH+Y_WIDTH-1:X_WIDTH];

  assign bram_ena = 1'b1;

  assign loc_diff = (spike_x - read_x) * (spike_x - read_x) + (spike_y - read_y) * (spike_y - read_y);
  assign is_existing = (loc_diff < POS_TH);
  assign is_merge = is_existing & (spike_cluster != bram_read_channel);

  assign s_axis_a_tready = (state == IDLE);

  enum logic [3:0] {
    IDLE,
    COMP_READ,
    COMP_COMP,
    NEWC,
    MERG_READ,
    MERG_COMP,
    MERG_EX,
    SEND_N,
    SEND_S,
    SEND_M
  } state;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                if (s_axis_a_tvalid) begin
                    state <= COMP_READ;
                end
                else begin
                    state <= IDLE;
                end
            end
            COMP_READ: begin
                if (bram_read_channel < cluster_bottom - 1 & cluster_bottom != 0) begin
                    state <= COMP_COMP;
                end
                else begin
                    state <= NEWC;
                end
            end
            COMP_COMP: begin
                if (is_existing) begin
                    state <= SEND_S;
                end
                else begin
                    state <= COMP_READ;
                end
            end
            NEWC: begin
                state <= SEND_N;
            end
            MERG_READ: begin
                if (bram_read_channel < cluster_bottom - 1) begin
                    state <= MERG_COMP;
                end
                else begin
                    state <= IDLE;
                end
            end
            MERG_COMP: begin
                if (is_merge) begin
                    state <= SEND_M;
                end
                else begin
                    state <= MERG_READ;
                end
            end
            MERG_EX: begin
                if (bram_read_channel < cluster_bottom - 1) begin
                    state <= MERG_EX;
                end
                else begin
                    state <= IDLE;
                end
            end
            SEND_N: begin
                if (m_axis_b_tready) begin
                    state <= IDLE;
                end
                else begin
                    state <= SEND_N;
                end
            end
            SEND_S: begin
                if (m_axis_b_tready) begin
                    state <= MERG_READ;
                end
                else begin
                    state <= SEND_S;
                end
            end
            SEND_M: begin
                if (m_axis_b_tready) begin
                    state <= MERG_EX;
                end
                else begin
                    state <= SEND_M;
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
        spike_time <= 0;
        spike_x <= 0;
        spike_y <= 0;
    end
    else begin
        if (state == IDLE & s_axis_a_tvalid) begin
            spike_time <= s_axis_a_time;
            spike_x <= s_axis_a_tx;
            spike_y <= s_axis_a_ty;
        end
        else if (state == SEND_S & m_axis_b_tready) begin
            spike_time <= spike_time;
            spike_x <= read_x;
            spike_y <= read_y;
        end
        else begin
            spike_time <= spike_time;
            spike_x <= spike_x;
            spike_y <= spike_y;
        end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        spike_cluster <= 0;
    end
    else begin
        if (state == COMP_COMP & is_existing) begin
            spike_cluster <= bram_read_channel;
        end
        else if (state == NEWC) begin
            spike_cluster <= cluster_bottom;
        end
        else begin
            spike_cluster <= 0;
        end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        cluster_bottom <= 0;
    end
    else begin
        if (state == NEWC) begin
            cluster_bottom <= cluster_bottom + 1;
        end
        else if (state == MERG_EX & (bram_read_channel == cluster_bottom - 1)) begin
            cluster_bottom <= cluster_bottom - 1;
        end
        else begin
            cluster_bottom <= cluster_bottom;
        end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        bram_read_channel <= 0;
    end
    else begin
        case (state)
            COMP_READ: begin
                bram_read_channel <= bram_read_channel + 1'b1;
            end
            COMP_COMP: begin
                bram_read_channel <= bram_read_channel;
            end
            MERG_READ: begin
                bram_read_channel <= bram_read_channel + 1'b1;
            end
            MERG_COMP: begin
                bram_read_channel <= bram_read_channel;
            end
            MERG_EX: begin
                bram_read_channel <= bram_read_channel + 1'b1;
            end
            SEND_M: begin
                bram_read_channel <= bram_read_channel;
            end
            default: begin
                bram_read_channel <= 0;
            end
        endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        bram_write_channel <= 0;
        write_x <= 0;
        write_y <= 0;
        bram_wea <= 0;
    end
    else begin
        case (state)
            NEWC: begin
                bram_write_channel <= cluster_bottom;
                write_x <= spike_x;
                write_y <= spike_y;
                bram_wea <= 1'b1;
            end
            MERG_COMP: begin
                if (is_merge) begin
                    bram_write_channel <= bram_read_channel;
                    write_x <= (write_x + read_x) / 2;
                    write_y <= (write_y + read_y) / 2;
                    bram_wea <= 1'b1;
                end
                else begin
                    bram_write_channel <= 0;
                    write_x <= 0;
                    write_y <= 0;
                    bram_wea <= 0;
                end
            end
            MERG_EX: begin
                bram_write_channel <= bram_read_channel;
                write_x <= read_x;
                write_y <= read_y;
                bram_wea <= 1'b1;
            end
            default: begin
                bram_write_channel <= 0;
                write_x <= 0;
                write_y <= 0;
                bram_wea <= 0;
            end
        endcase
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

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      m_axis_b_tdata <= 0;
      m_axis_b_tvalid <= 0;
    end
    else begin
      if (state == SEND_N | state == SEND_S | state == SEND_M) begin
        if (state == SEND_M) begin
          m_axis_b_tdata <= {{C_SLACK{1'b0}}, spike_cluster, {C_SLACK{1'b0}}, bram_read_channel, {2'b11}};
        end else if (state == SEND_N | state == SEND_S) begin
          m_axis_b_tdata <= {spike_time, spike_cluster, spike_x, spike_y, 1'b0};
        end else begin
          m_axis_b_tdata <= m_axis_b_tdata;
        end
        if (m_axis_b_tready) begin
          m_axis_b_tvalid <= 1'b1;
        end
        else begin
          m_axis_b_tvalid <= 1'b0;
        end
      end
      else if ((s_axis_a_tlast | is_last) & (state == IDLE) & m_axis_b_tready) begin
        m_axis_b_tdata <= 0;
        m_axis_b_tvalid <= 1;
      end else begin
        m_axis_b_tdata <= 0;
        m_axis_b_tvalid <= 0;
      end
    end
  end

endmodule
