module UtopiaMethod;
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
