module utopial_atm_rx (
    Utopia.CoreReceive Rx
);

  // 25 MHz Rx clk out
  assign Rx.clk_out = Rx.clk_in;

  // Listen to the interface, collecting byte.
  // A complete cell is then copied to the cell buffer

  bit [0:5] PayloadIndex;
  enum bit [0:2] {
    reset,
    soc,
    vpi_vci,
    vci,
    vci_clp_pt,
    hec,
    payload,
    ack
  } UtopiaStatus;

  // State Machine
  always_ff @(posedge Rx.clk_in, posedge Rx.reset) begin : FSM
    if (Rx.reset) begin
      Rx.valid <= 0;
      Rx.en <= 1;
      UtopiaStatus <= reset;
    end else begin : FSM_sequencer
      unique case (UtopiaStatus)
        reset: begin : reset_state
          if (Rx.ready) begin
            UtopiaStatus <= soc;
            Rx.en <= 0;
          end
        end : reset_state

        soc: begin : soc_state
          if (Rx.soc && Rx.clav) begin
            {Rx.ATMcell.uni.GFC, Rx.ATMcell.uni.VPI[7:4]} <= Rx.data;
            UtopiaStatus <= vpi_vci;
          end
        end : soc_state

        vpi_vci: begin : vpi_vci_state
          if (Rx.clav) begin
            {Rx.ATMcell.uni.VPI[3:0], Rx.ATMcell.uni.VCI[15:12]} <= Rx.data;
            UtopiaStatus <= vci;
          end
        end : vpi_vci_state

        vci: begin : vci_state
          if (Rx.clav) begin
            Rx.ATMcell.uni.VPI[11:4] <= Rx.data;
            UtopiaStatus <= vci_clp_pt;
          end
        end : vci_state

        vci_clp_pt: begin : vci_clp_pt_state
          if (Rx.clav) begin
            {Rx.ATMcell.uni.VCI[3:0], Rx.ATMcell.uni.CLP, Rx.ATMcell.uni.PT} <= Rx.data;
            UtopiaStatus <= hec;
          end
        end : vci_clp_pt_state

        hec: begin : hec_state
          if (Rx.clav) begin
            Rx.ATMcell.uni.HEC <= Rx.data;
            UtopiaStatus <= payload;
            PayloadIndex = 0;  // Blocking Assignment due to bloacking increment in payload state
          end
        end : hec_state

        payload: begin : payload_state
          if (Rx.clav) begin
            Rx.ATMcell.uni.Payload[PayloadIndex] <= Rx.data;
            if (PayloadIndex == 47) begin
              UtopiaStatus <= ack;
              Rx.valid <= 1;
              Rx.en <= 1;
            end
            PayloadIndex++;
          end
        end : payload_state

        ack: begin : ack_state
          if (!Rx.ready) begin
            UtopiaStatus <= reset;
            Rx.valid <= 0;
          end
        end : ack_state

        default: UtopiaStatus <= reset;
      endcase
    end : FSM_sequencer
  end : FSM
endmodule
