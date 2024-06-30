`timescale 1ns / 1ps
import conf_pkg::*;


module check_fall_in (
    input  [BUFFER_DEPTH-1:0] fall_in,
    output buffer_pointer_t index,
    output logic valid
);


  always_comb begin
    index = 0;
    if (!fall_in) begin
        valid = 1'b0;
    end
    else begin
        valid = 1'b1;
        for (int j = 0; j < BUFFER_DEPTH - 1; j = j + 1) begin
          if (fall_in[j] == 1'b1) begin
            index = j;
            break;
          end
        end
    end
  end

endmodule
