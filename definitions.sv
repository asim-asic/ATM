`ifndef INCL_DEFINITIONS
`define INCL_DEFINITIONS

`define RxPorts 4
`define TxPorts 4

typedef struct packed {
  bit [3:0] GFC;
  bit [7:0] VPI;
  bit [15:0] VCI;
  bit CLP;
  bit [2:0] PT;
  bit [7:0] HEC;
  bit [0:47][7:0] Payload;
} uniType;

typedef struct packed {
  bit [11:0] VPI;
  bit [15:0] VCI;
  bit CLP;
  bit [2:0] PT;
  bit [7:0] HEC;
  bit [0:47][7:0] Payload;
} nniType;

// Test view cell format (payload section)
typedef struct packed {
  bit [0:4][7:0]  Header;
  bit [0:3][7:0]  PortID;
  bit [0:3][7:0]  PacketID;
  bit [0:39][7:0] Padding;
} tstType;

// Union of UNI/NNI/test view/byte stream
typedef union packed {
  uniType uni;
  nniType nni;
  tstType tst;
  bit [0:52][7:0] Mem;
} ATMCellType;


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

  modport Peripheral(input BusMode, Addr, Sel, DataIn, Rd_DS, Wr_RW, output DataOut, Rdy_Dtack);

`ifndef SYNTHESIS  // synthesis ignores this code
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

`endif  // INCL_DEFINITIONS
