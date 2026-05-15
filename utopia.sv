import definitions_sv_unit::*;

interface Utopia;
  parameter int Ifwidth = 8;

  bit clk_in;
  bit clk_out;
  logic [Ifwidth-1:0] data;
  bit soc;
  bit en;
  bit clav;
  bit valid;
  bit ready;
  bit reset;
  bit selected;

  ATMCellType ATMcell;  // union of structures for ATM cells

  modport TopReceive(
      input clk_in, data, soc, clav, ready, reset,
      output clk_out, en, ATMcell, valid
  );

  modport TopTransmit(
      input clk_in, clav, ATMcell, ready, reset,
      output clk_out, data, soc, en, valid
  );

  modport CoreReceive(
      input clk_in, data, soc, clav, ready, reset,
      output clk_out, en, ATMcell, valid
  );

  modport CoreTransmit(
      input clk_in, clav, ATMcell, valid, reset,
      output clk_out, data, soc, en, ready
  );

`ifndef SYNTHESIS  // synthesis ignores this code
  UtopiaMethod Method();  // interface with testing methods
`endif
endinterface

