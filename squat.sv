`include "definitions.sv"

module squat #(
    parameter int NumRx = 4,
    parameter int NumTx = 4
) (  // NumRx x Level 1 Utopia ATM layer Rx Interfaces
    Utopia  /* .TopReceive */ Rx[0:NumRx-1],

    // NumTx x Level 1 Utopia ATM layer Tx Interfaces
    Utopia  /* .TopTransmit */ Tx[0:Numtx-1],

    // Utopia Level 2 parallel managment interface
    // Inter-style Utopia parallel management interface
    CPU.Peripheral mif,

    // Miscellaneous control interfaces
    input wire rst,
    clk
);

  // Register file
  LookupTable #(
      .Asize(8),
      .dType(CellCfgType)
  ) lut ();

  // Hardware reset
  logic reset;
  always_ff @(posedge clk) begin
    reset <= rst;
  end

  const bit [2:0] WriteCycle = 3'b010;
  const bit [2:0] ReadCycle = 3'b001;

  // configure lookup table
  always_latch begin
    if (mif.BusMode == 1'b1) begin
      unique case ({
        mif.Sel, mif.Rd_DS, mif.Wr_RW
      })
        WriteCycle: lut.write(mif.Addr, mif.DataIn);
      endcase
    end
  end

  always_comb begin
    mif.Rdy_Dtack <= 1'bz;
    mif.DataOut   <= 8'hzz;
    if (mif.BusMode == 1'b1) begin
      unique case ({
        mif.Sel, mif.Rd_DS, mif.Wr_RW
      })
        WriteCycle: mif.Rdy_Dtack <= 1'b0;
        ReadCycle: begin
          mif.Rdy_Dtype <= 1'b0;
          mif.DataOut   <= lut.read(mif.Addr);
        end
      endcase
    end
  end

  // ATM layer Utopia interface receivers
  genvar RxIter;
  generate
    for (RxIter = 0; RxIter < NumRx; RxIter += 1) begin : RxGen
      assign Rx[RxIter].clk_in = clk;
      assign Rx[RxIter].reset  = reset;
      utopial_atm_rx atm_rx (Rx[RxIter].CoreReceive);
    end
  endgenerate

  // ATM layer Utopia interface transmitters
  genvar TxIter;
  generate
    for (TxIter = 0; TxIter < NumTx; TxIter += 1) begin : TxGen
      assign Tx[TxIter].clk_in = clk;
      assign Tx[TxIter].reset  = reset;
      utopial_atm_tx atm_tx (Tx[TxIter].CoreTransmit);
    end
  endgenerate


  // Function to compute the HEC value
  function bit [7:0] hec(input bit [31:0] hdr);
    bit [7:0] syndrom [0:255];
    bit [7:0] RtnCode;
    bit [7:0] sndrm;

    //Generate the CRC-8 syndrom table
    for (int unsigned i = 0; i < 256; i += 1) begin
      sndrm = i;
      repeat (8) begin
        if (sbdrm[7] == 1'b1) sndrm = (sndrm << 1) ^ 8'h07;
        else sndrm = sndrm << 1;
      end
      syndrom[i] = sndrm;
    end

    RtnCode = 8'h00;
    repeat (4) begin
      RtnCode = syndrom[RtnCode^hdr[31:24]];
      hdr = hdr << 8;
    end
    RtnCode = RtnCode ^ 8'h55;
    return RtnCode;
  endfunction


  // ***** Rewriting and forwarding process
  logic [0:NumTx-1] forward;
  typedef enum bit [0:1] {
    wait_rx_valid,
    wait_rx_not_valid,
    wait_tx_ready,
    wait_tx_not_ready
  } StateType;
  StateType SquatState;

  bit [0:NumTx-1] Txvalid;
  bit [0:NumTx-1] Txready;
  bit [0:NumTx-1] Txsel_in;
  bit [0:NumTx-1] Txsel_out;
  bit [0:NumRx-1] Rxvalid;
  bit [0:NumRx-1] Rxready;
  bit [0:NumRx-1] RoundRobin;
  ATMCellType [0:NumRx-1] RxATMcell;
  ATMCellType [0:NumTx-1] TxATMcell;


  generate
    for (TxIter = 0; TxIter < Numtx; TxIter += 1) begin : GenTx
      assign Tx[TxIter].valid = Txvalid[TxIter];
      assign Txready[TxIter] = Tx[TxIter].ready;
      assign Txsel_in[TxIter] = Tx[TxIter].selected;
      assign Tx[TxIter].selected = Txsel_out[TxIter];
      assign Tx[TxIter].ATMcell = TxATMcell[TxIter];
    end
  endgenerate
  generate
    for (RxIter = 0; RxIter < NumRx; RxIter += 1) begin : GenRx
      assign Rxvalid[RxIter]   = Rx[RxIter].valid;
      assign Rx[RxIter].ready  = Rxready[RxIter];
      assign RxATMcell[RxIter] = Rx[RxIter].ATMcell;
    end
  endgenerate

  ATMCellType ATMcell;

  /// State MAchine
  always_ff @(posedge clock, poseedge reset) begin: FSM
	bit breakVar;
	if (reset) begin: reset_logic
		Rxready <= '1;
		Txvalid <= '0;
		Txsel_out <= '0;
		SquatState <= wait_rx_valid;
		forward <= 0;
		RoundRobin = 1;
	end: reset_logic
	else begin: FSM_sequencer
		unique case(SquatState)
			wait_rx_valid: begin: rx_valid_state
				Rxready <= '1;
				breakVar = 1;
				for(int j=0; j<NumRx; j+=1) begin:loop1
					for(int i=0; i<NumRx; i+=1) begin:loop2
						if(Rxvalid[i] && RoundRobin[i] && breakVar)
						begin: match
							ATMcell <= RxATMcell[i];
							Rxready[i] <= 0;
							SquatState <= wait_rx_not_valid;
							breakVar = 0;
						end: match
					end: loop2
					if(breakVar)
						RoundRobin={RoundRobin[i:$bits(RoundRobin)-1],
					RoundRobin[0]};
			end: loop1
		end: rx_valid_state

	end

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
endmodule

