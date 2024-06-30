`timescale 1ns / 1ps
import conf_pkg::*;


module conditional_relay #(
    parameter int CYCLE = 1,
    parameter int WIDTH = 11
) (
    input clk,
    input rst_n,

    input [WIDTH-1:0] in,
    input valid,
    output [WIDTH-1:0] out
);

  genvar i;

  logic [WIDTH-1:0] data_relay[CYCLE];

  generate
    for (i = 0; i < CYCLE; i++) begin : gen_relay
      if (i == 0) begin : gen_first
        always @(posedge clk or negedge rst_n) begin
          if (~rst_n) begin
            data_relay[0] <= {WIDTH{1'b0}};
          end else begin
            if (valid) begin
              data_relay[0] <= in;
            end else begin
              data_relay[0] <= data_relay[0];
            end
          end
        end
      end else begin : gen_others
        always @(posedge clk or negedge rst_n) begin
          if (~rst_n) begin
            data_relay[i] <= {WIDTH{1'b0}};
          end else begin
            if (valid) begin
              data_relay[i] <= data_relay[i-1];
            end else begin
              data_relay[i] <= data_relay[i];
            end
          end
        end
      end
    end
  endgenerate

  assign out = data_relay[CYCLE-1];

endmodule
