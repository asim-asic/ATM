module utopial_atm_tx (
    Utopia.CoreTransmit Tx
);

  assign Tx.clk_out = Tx.clk_in;

  logic [0:5] PayloadIndex;  // 0 to 47

  enum bit [0:3] {
    reset,
    soc,
    vpi_vci,
    vci,
    vci_clp_pt,
    hec,
    payload,
    ack,
    done
  } UtopiaStatus;

  always_ff @(posedge Tx.clk_in, posedge Tx.reset) begin : FSM
    if (Tx.reset) begin
      Tx.soc <= 0;
      Tx.en <= 1;
      Tx.ready <= 1;
      UtopiaStatus <= reset;
    end else begin : FSM_sequencer
      unique case (UtopiaStatus)
        reset: begin : reset_state
          Tx.en <= 1;
          Tx.ready <= 1;
          if (Tx.valid) begin
            Tx.ready <= 0;
            UtopiaStatus <= soc;
          end
        end : reset_state

        soc: begin : soc_state
          if (Tx.clav) begin
            Tx.soc <= 1;
            Tx.data <= Tx.ATMcell.nni.VPI[11:4];
            UtopiaStatus <= vpi_vci;
          end
          Tx.en <= !Tx.clav;
        end : soc_state

        vpi_vci: begin : vpi_vci_state
          Tx.soc <= 0;
          if (Tx.clav) begin
            Tx.data <= {Tx.ATMcell.nni.VPI[3:0], Tx.ATMcell.nni.VCI[15:12]};
            UtopiaStatus <= vci;
          end
          Tx.en <= !Tx.clav;
        end : vpi_vci_state

        vci: begin : vci_state
          if (Tx.clav) begin
            Tx.data <= Tx.ATMcell.nni.VCI[11:4];
            UtopiaStatus <= vci_clp_pt;
          end
          Tx.en <= !Tx.clav;
        end : vci_state

        vci_clp_pt: begin : vci_clp_pt_state
          if (Tx.clav) begin
            Tx.data <= {Tx.ATMcell.nni.VCI[3:0], Tx.ATMcell.nni.CLP, Tx.ATMcell.nni.PT};
            UtopiaStatus <= hec;
          end
          Tx.en <= !Tx.clav;
        end : vci_clp_pt_state

        hec: begin : hec_state
          if (Tx.clav) begin
            Tx.data <= Tx.ATMcell.nni.HEC;
            UtopiaStatus <= payload;
            PayloadIndex = 0;
          end
          Tx.en <= !Tx.clav;
        end : hec_state

        payload: begin : payload_state
          if (Tx.clav) begin
            Tx.data <= Tx.ATMcell.nni.Payload[PayloadIndex];
            if (PayloadIndex == 47) UtopiaStatus <= ack;
            PayloadIndex++;
          end
          Tx.en <= !Tx.clav;
        end : payload_state

        ack: begin : ack_state
          Tx.en <= 1;
          if (!Tx.valid) begin
            Tx.ready <= 1;
            UtopiaStatus <= done;
          end
        end : ack_state

        done: begin : done_state
          if (!Tx.valid) begin
            Tx.ready <= 0;
            UtopiaStatus <= reset;
          end
        end : done_state
      endcase
    end : FSM_sequencer
  end : FSM
endmodule

