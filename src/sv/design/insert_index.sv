`timescale 1ns / 1ps
import conf_pkg::*;


module insert_index (
    input  udata_t   buffer[WINDOW_LENGTH-1],
    input  udata_t   data,
    output window_t index
);

  logic [WINDOW_LENGTH-2:0] comparison;

  genvar i;

  generate
    for (i = 0; i < WINDOW_LENGTH - 1; i++) begin : gen_comparison
      assign comparison[i] = (data < buffer[i]);
    end
  endgenerate

  always_comb begin
    index = 0;
    if (!comparison) begin
        index = WINDOW_LENGTH - 1;
    end
    else begin
        for (int j = 0; j < WINDOW_LENGTH - 1; j = j + 1) begin
          if (comparison[j] == 1'b1) begin
            index = j;
            break;
          end
        end
    end
  end

endmodule
