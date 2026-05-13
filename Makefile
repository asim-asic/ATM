SV = iverilog
FLAGS =-g2012
SIM = atm_sim
SRCS = definitions.sv utopia.sv methods.sv squat.sv utopial_atm_rx.sv utopial_atm_tx.sv test.sv
all: $(SIM)

$(SIM): $(SRCS)
	$(SV) $(FLAGS) -o $(SIM) $(SRCS)

run: $(SIM)
	vvp $(SIM)

sim: all run

lint:
	verilator --lint-only --sv $(SRCS)
	
clean: 
	rm -f $(SIM) *.vcd *.log

.PHONY: all run sim clean
