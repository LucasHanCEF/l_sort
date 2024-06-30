package conf_pkg;

  parameter int CHANNEL_COUNT = 120;
  parameter int WINDOW_LENGTH = 25;
  parameter int DATA_WIDTH = 12;
  parameter int COE_WIDTH = 12;
  parameter int X_WIDTH = 11;
  parameter int Y_WIDTH = 11;

  typedef logic unsigned [$clog2(CHANNEL_COUNT)-1:0] channel_t;
  typedef logic unsigned [$clog2(WINDOW_LENGTH-1)-1:0] window_t;
  typedef logic signed [DATA_WIDTH-1:0] data_t;
  typedef logic signed [COE_WIDTH-1:0] coe_t;

  parameter coe_t COE_B0 = 12'b0001_1001_1110;
  parameter coe_t COE_B1 = 12'b0000_0000_0000;
  parameter coe_t COE_B2 = 12'b1110_0110_0010;
  parameter coe_t COE_A0 = 12'b0100_0000_0000;
  parameter coe_t COE_A1 = 12'b1011_0111_0011;
  parameter coe_t COE_A2 = 12'b0000_1100_0011;

  // parameter coe_t COE_B0 = 12'b0001_1010_00;
  // parameter coe_t COE_B1 = 12'b0000_0000_00;
  // parameter coe_t COE_B2 = 12'b1110_0110_00;
  // parameter coe_t COE_A0 = 12'b0100_0000_00;
  // parameter coe_t COE_A1 = 12'b1011_0111_01;
  // parameter coe_t COE_A2 = 12'b0000_1100_01;

  parameter int Q_SCALE = 10;

  typedef logic unsigned [DATA_WIDTH-2:0] udata_t;

  parameter int BUFFER_DEPTH = 4;

  typedef logic [$clog2(BUFFER_DEPTH)-1:0] buffer_pointer_t;

  typedef logic unsigned [X_WIDTH-1:0] x_t;
  typedef logic unsigned [Y_WIDTH-1:0] y_t;
  typedef logic unsigned [X_WIDTH+Y_WIDTH-1:0] p_t;

  typedef logic unsigned [X_WIDTH+DATA_WIDTH+5-1:0] x_acc_t;
  typedef logic unsigned [Y_WIDTH+DATA_WIDTH+5-1:0] y_acc_t;
  typedef logic unsigned [DATA_WIDTH+5-1:0] a_acc_t;


  parameter time TIME_TH = 12;
  parameter channel_t CHANNEL_TH = 30;

  parameter int INTERVEL = 20;

  parameter int CLUSTER_COUNT = CHANNEL_COUNT;

  typedef logic unsigned [$clog2(CLUSTER_COUNT)-1:0] cluster_t;

  typedef logic unsigned [64-X_WIDTH-Y_WIDTH-$clog2(CLUSTER_COUNT)-1-1:0] time_t;

  parameter logic unsigned [2*Y_WIDTH-1:0] POS_TH = 1600;

  parameter int C_SLACK = 31 - $clog2(CLUSTER_COUNT);

endpackage
