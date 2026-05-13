`include "definitions.sv"
`include "methods.sv"

module test ();
  parameter int NumRx = `RxPorts;
  parameter int NumTx = `TxPorts;

  // NumRx x Level 1 Utopia Rx Interfaces
  Utopia Rx[0:NumRx-1];

  // NumTx x Level 1 Utopia Tx Interfaces
  Utopia Tx[0:NumTx-1];

  // Interstyle Utopia parallel management interface
  CPU mif;

  // Miscellaneous control interfaces
  logic rst;
  logic clk;
  logic Initialised;

  squat dut (
      .Rx (Rx),
      .Tx (Tx),
      .mif(mif),
      .rst(rst),
      .clk(clk)
  );

  task automatic RandomPkt(inout ATMCellType Pkt, inout seed);
    Pkt.uni.GFC = $random(seed);
    Pkt.uni.VPI = $random(seed);
    Pkt.uni.VCI = $random(seed);
    Pkt.uni.CLP = $random(seed);
    Pkt.uni.PT  = $random(seed);
    Pkt.uni.HEC = hec(Pkt.Mem[0:3]);
    for (int i = 0; i <= 47; i++) begin
      Pkt.uni.Payload[i] = 47 - i;  // $random(seed);
    end
  endtask

  logic [7:0] syndrom[0:255];
  initial begin : gen_syndrom
    int i;
    logic [7:0] sndrm;
    for (i = 0; i < 256; i++) begin
      sndrm = i;
      repeat (8) begin
        if (sndrm[7] === 1'b1) sndrm = (sndrm << 1) ^ 8'h07;
        else sndrm = sndrm << 1;
      end
      syndrom[i] = sndrm;
    end
  end

  // Function to compute the HEC value
  function automatic bit [7:0] hec(bit [31:0] hdr);
    bit [7:0] rtn;
    rtn = 8'h00;
    repeat (4) begin
      rtn = syndrom[rtn^hdr[31:24]];
      hdr = hdr << 8;
    end
    rtn = rtn ^ 8'h55;
    return rtn;
  endfunction

  // System Clock and Reset
  initial begin
    #0 rst = 0;
    clk = 0;
    #5 rst = 1;
    #5 clk = 1;
    #5 rst = 0;
    clk = 0;
    forever begin
      #5 clk = 1;
      #5 clk = 0;
    end
  end

  CellCfgType lookup[255:0];  // copy of look-up table

  function bit [0:NumTx-1] find(bit [11:0] VPI);
    for (int i = 0; i <= 255; i++) begin
      if (lookup[i].VPI == VPI) begin
        return lookup[i].FWD;
      end
    end
    return 0;
  endfunction

  // Stimulus
  initial begin
    int automatic seed = 1;
    CellCfgType   CellFwd;
    $display("Configuration RxPorts=%0d TxPorts=%0d", `RxPorts, `TxPorts);
    mif.Method.Initialise_Host();

    // Configure through Host interface
    repeat (10) @(negedge clk);
    $display("Loading Memory");
    for (int i = 0; i <= 255; i++) begin
      CellFwd.FWD = i;
`ifdef FWDALL
      CellFwd.FWD = '1;
`endif
      CellFwd.VPI = i;
      mif.Method.HostWrite(i, CellFwd);
      lookup[i] = CellFwd;
    end

    // Verify memory
    $display("Verifying Memory");
    for (int i = 0; i <= 255; i++) begin
      mif.Method.HostRead(i, CellFwd);
      if (lookup[i] != CellFwd) begin
        $display("Error, Mem Location 0x%x contains 0x%x,expected 0x%x", i, lookup[i], CellFwd);
        $stop;
      end
    end
    $display("Memory Verified");

    Initialised = 1;
    repeat (5000000) @(negedge clk);
    $display("Error Timeout");
    $finish();
  end

  int TxPktCtr[0:NumTx-1];
  bit [0:NumRx-1] RxGenInProgress;
  genvar RxIter;
  genvar TxIter;
  generate  // replicate access to ports
    for (RxIter = 0; RxIter < NumRx; RxIter++) begin : RxGen
      initial begin : Sender
        int seed;
        bit [0:NumTx-1] TxPortTarget;
        ATMCellType Pkt;

        Rx[RxIter].data = 0;
        Rx[RxIter].soc = 0;
        Rx[RxIter].en = 1;
        Rx[RxIter].clav = 0;
        Rx[RxIter].ready = 0;

        RxGenInProgress[RxIter] = 1;
        wait (Initialised === 1'b1);
        seed = RxIter + 1;
        Rx[RxIter].Method.Initialise();
        repeat (200) begin
          RandomPkt(Pkt, seed);
          TxPortTarget = find(Pkt.uni.VPI);

          // Increment counter if output packet expected 	
          for (int i = 0; i < NumTx; i++) begin
            if (TxPortTarget[i]) begin
              TxPktCtr[i]++;
              //$display("port %0d ->> %0d", Rxiter,i);
            end
          end
          Rx[RxIter].Method.Send(Pkt, RxIter);
          //$display("Port %d sent packet", RxIter);
          repeat ($random(seed) % 200) @(negedge clk);
        end
        RxGenInProgress[RxIter] = 0;
      end
    end
  endgenerate

  // Response - open files for response
  generate
    for (TxIter = 0; TxIter < NumTx; TxIter++) begin : TxGen
      initial begin : Receiver
        wait (Tx[TxIter].reset === 1);
        wait (Tx[TxIter].reset === 0);
        forever begin
          Tx[TxIter].Method.Receive(TxIter);
          TxPktCtr[TxIter]--;
        end
      end
    end
  endgenerate

  // Check for all detected packets
  bit [0:NumTx-1] TxDetectEnd;
  generate
    for (TxIter = 0; TxIter < NumTx; TxIter++) begin : TxDetect
      initial begin
        TxDetectEnd[TxIter] = 1'b1;
        wait (Initialised === 1'b1);
        wait (RxGenInProgress == 0);
        wait (TxPktCtr[TxIter] == 0);
        TxDetectEnd[TxIter] = 1'b0;
        $display("TxPktCtr[%0d] == %d", TxIter, TxPktCtr[TxIter]);
      end
    end
  endgenerate

  initial begin
    wait (Initialised === 1'b1);
    wait (RxGenInProgress === 0);
    wait (TxDetectEnd === 0);
    $finish();
  end
endmodule


