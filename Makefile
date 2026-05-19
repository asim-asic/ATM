SRCS = definitions.sv \
       utopia.sv \
       methods.sv \
       utopial_atm_rx.sv \
       utopial_atm_tx.sv \
       squat.sv \
       test.sv \
       top.sv

msim:
	vlib work
	vmap work work
	vlog -sv $(SRCS)
	vsim -c work.top -do "run -all; quit"

clean:
	rm -rf work transcript vsim.wlf
