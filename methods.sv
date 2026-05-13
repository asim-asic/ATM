`ifndef INCL_METHODS
`define INCL_METHODS

interface UtopiaMethod;
  task automatic Initialise();
  endtask

  task automatic Send(input ATMCellType Pkt, input int PortID);
    static int PacketID;
    PacketID++;

    Pkt.tst.PortID   = PortID;
    Pkt.tst.PacketID = PacketID;

    // iterate through bytes of packet, deasserting
    // Start Of cell indicater

    @(negedge Utopia.clk_out);
    Utopia.clav <= 1;
    for (int i = 0; i <= 52; i++) begin
      // If not enable, loop
      while (Utopia.en === 1'b1) @(negedge Utopia.clk_out);

      // Assert start of cell indicator, assert enable,
      // send byte 0 (i==0)
      Utopia.soc  <= (i == 0) ? 1'b1 : 1'b0;
      Utopia.data <= Pkt.Mem[i];
      @(negedge Utopia.clk_out);
    end
    Utopia.data <= 8'bx;
    Utopia.clav <= 0;
  endtask

  task automatic Receive(input int PortID);
    ATMCellType Pkt;

    Utopia.clav = 1;
    while (Utopia.soc !== 1'b1 && Utopia.en !== 1'b0) @(negedge Utopia.clk_out);
    for (int i = 0; i <= 52; i++) begin
      // If not enabled, loop
      while (Utopia.en !== 1'b0) @(negedge Utopia.clk_out);
      Pkt.Mem[i] = Utopia.data;
      @(negedge Utopia.clk_out);
    end
    Utopia.clav = 0;

    // Write Rxed data to logfile
`ifdef verbose
    $write("Received packet at port %0d from port %0d PKT(%0d)\n", PortID, Pkt.tst.PortID,
           Pkt.tst.PacketID);
    // PortID, Pkt.nni.payload[0], Pkt.nni.Payload[1:4]);
`endif
  endtask
endinterface



interface CPUMethod;
  task automatic Initialise_Host();
    CPU.BusMode <= 1;
    CPU.Addr <= 0;
    CPU.DataIn <= 0;
    CPU.Sel <= 1;
    CPU.Rd_DS <= 1;
    CPU.Wr_RW <= 1;
  endtask

  task automatic HostWrite(int a, CellCfgType d);  // configure
    #10 CPU.Addr <= a;
    CPU.DataIn <= d;
    CPU.Sel <= 0;
    #10 CPU.Wr_RW <= 0;
    while (CPU.Rdy_Dtack !== 00) #10;
    #10 CPU.Wr_RW <= 1;
    CPU.Sel <= 1;
    while (CPU.Rdy_Dtack == 0) #10;
  endtask

  task automatic HostRead(int a, output CellCfgType d);
    #10 CPU.Addr <= a;
    CPU.Sel <= 0;
    #10 CPU.Rd_DS <= 0;
    while (CPU.Rdy_Dtack !== 0) #10;
    #10 d = CPU.DataOut;
    CPU.Rd_DS <= 1;
    CPU.Sel   <= 1;
    while (CPU.Rdy_Dtack == 0) #10;
  endtask
endinterface

`endif  // INCL_METHODS
