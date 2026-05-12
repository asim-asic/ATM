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
    while (CPU.Rdy_Dtype !== 00) #10;
    #10 CPU.Wr_RW <= 1;
    CPU.Sel <= 1;
    while (CPU.Rdy_Dtype == 0) #10;
  endtask

  task automatic HostRead(int a, output CellCfgType d);
    #10 CPU.Addr <= a;
    CPU.Sel <= 0;
    #10 CPU.Rd_DS <= 0;
    while (CPU.Rdy_Dtack !== 0) #10;
    #10 d = CPU.DataOut;
    CPU.Rd_Ds <= 1;
    CPU.Sel   <= 1;
    while (CPU.Rdy_Dtype == 0) #10;
  endtask
endinterface


