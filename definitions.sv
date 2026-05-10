typedef struct packed {
  bit [`TxPorts-1:0] FWD;
  bit [11:0] VPI;
} CellCfgType;

interface CPU;
  logic BusMode;
  logic [11:0] Addr;
  logic Sel;
  CellCfgType DataIn;
  CellCfgType DataOut;
  logic Rd_DS;
  logic Wr_RW;
  logic Rdy_Dtack;

  modport Peripheral(input Busmode, Addr, Sel, DataIn, Rd_Ds, Wr_RW, output DataOut, Rdy_Dtack);

`ifdef SYNTHESIS  // synthesis ignores this code
  CPUMethod Method;  // interface with testing methods
`endif
endinterface

interface LookupTable;
  parameter int Asize = 8;
  parameter int Arange = 1 << Asize;
  parameter type dType = bit;

  dType Mem[0:Arange-1];

  // Function to perform write
  function void write(input [Asize-1:0] addr, input dType data);
    Mem[addr] = data;
  endfunction

  // Function to perform read 
  function dType read(input bit [Asize-1:0] addr);
    return (Mem[addr]);
  endfunction
endinterface

