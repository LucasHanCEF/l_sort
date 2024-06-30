`timescale 1ns / 1ps
import conf_pkg::*;


module tb_top;

  parameter int C_AXIS_TDATA_WIDTH = 32;

  int                                           raw_file;
  string                                        line;

  logic                                         clk;
  logic                                         rst_n;

  logic  [C_AXIS_TDATA_WIDTH:0] raw_line;

  logic                                         s00_axis_aclk;
  logic                                         s00_axis_aresetn;
  logic  [              C_AXIS_TDATA_WIDTH-1:0] s00_axis_tdata;
  logic  [        (C_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb;
  logic                                         s00_axis_tvalid;
  logic                                         s00_axis_tready;
  logic                                         s00_axis_tlast;

  logic                                         m00_axis_aclk;
  logic                                         m00_axis_aresetn;
  logic  [              C_AXIS_TDATA_WIDTH-1:0] m00_axis_tdata;
  logic  [        (C_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb;
  logic                                         m00_axis_tvalid;
  logic                                         m00_axis_tready;
  logic                                         m00_axis_tlast;

  assign s00_axis_aclk = clk;
  assign m00_axis_aclk = clk;

  assign s00_axis_aresetn = rst_n;
  assign m00_axis_aresetn = rst_n;

  initial begin
    clk   <= 1'b0;
    rst_n <= 1'b0;
    #200 raw_file = $fopen("/home/lucas/biocas2024_l_sort/hw/python_outputs/raw_data.txt", "r");
    if (raw_file == 0) $fatal("Error: Unable to open raw file");
    raw_line = line.atobin();
    rst_n <= 1'b1;
  end

  always #100 clk <= ~clk;

  always @(posedge clk) begin
    if (raw_file) begin
      if (!$feof(raw_file)) begin
        raw_line <= line.atobin();
        $fgets(line, raw_file);
        if (!$feof(raw_file)) begin
            s00_axis_tlast <= 1'b0;
        end else begin
            s00_axis_tlast <= 1'b1;
        end
      end else begin
        raw_line <= line.atobin();
        s00_axis_tlast <= 1'b0;
      end
    end
    else begin
      raw_line <= 0;
      s00_axis_tlast <= 0;
    end
  end

  always @(posedge clk) begin
    if (m00_axis_tlast) begin
        $stop;
    end
  end


  assign s00_axis_tdata = raw_line[C_AXIS_TDATA_WIDTH:1];
  assign s00_axis_tvalid = raw_line[0];
  assign m00_axis_tready = 1'b1;

  axis_l_sorter u_axis_l_sorter (
      .s00_axis_aclk(clk),
      .s00_axis_aresetn(rst_n),
      .s00_axis_tdata(s00_axis_tdata),
      .s00_axis_tstrb(s00_axis_tstrb),
      .s00_axis_tvalid(s00_axis_tvalid),
      .s00_axis_tready(s00_axis_tready),
      .s00_axis_tlast(s00_axis_tlast),
      .m00_axis_aclk(clk),
      .m00_axis_aresetn(rst_n),
      .m00_axis_tdata(m00_axis_tdata),
      .m00_axis_tstrb(m00_axis_tstrb),
      .m00_axis_tvalid(m00_axis_tvalid),
      .m00_axis_tready(m00_axis_tready),
      .m00_axis_tlast(m00_axis_tlast)
  );

endmodule
