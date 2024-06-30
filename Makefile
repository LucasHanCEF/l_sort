SHELL := /bin/bash

# Vivado settings
VIVADO_PATH := /home/lucas/Xilinx/Vivado/2024.1
VIVADO_CMD := vivado

# Variables
export CHANNEL_COUNT := 120
export WINDOW_LENGTH := 25
export DATA_WIDTH := 12
export Q_SCALE:= 12
export SIM_STEP:= 10000


# Target
.PHONY: all sw hw hw_gen hw_imp send clean

all: clean sw hw

sw:
	mkdir -p ./python_outputs && \
	python ./src/py/generate_data.py --length $(SIM_STEP) --channel $(CHANNEL_COUNT) --datawidth $(DATA_WIDTH) && \
	python ./src/py/generate_filter.py --bw $(DATA_WIDTH)

hw: hw_gen hw_imp

hw_gen:
	mkdir -p ./vivado_outputs && \
	python ./src/py/generate_detector_coe.py --channel $(CHANNEL_COUNT) --datawidth $(DATA_WIDTH) --window $(WINDOW_LENGTH) && \
	source $(VIVADO_PATH)/settings64.sh && \
	$(VIVADO_CMD) -mode batch -source ./src/tcl/generate_vivado_project.tcl

hw_imp:
	mkdir -p ./vivado_outputs && \
	source $(VIVADO_PATH)/settings64.sh && \
	$(VIVADO_CMD) -mode batch -source ./src/tcl/generate_block_design.tcl

send:
	sshpass -p "xilinx" scp ./vivado_project/vivado_project.runs/impl_1/design_1_wrapper.bit xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/design_1.bit && \
	sshpass -p "xilinx" scp ./vivado_project/vivado_project.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/design_1.hwh && \
	sshpass -p "xilinx" scp ./vivado_project/design_1.tcl xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/design_1.tcl

clean:
	rm -rf ./python_outputs
	rm -f vivado* && \
	rm -f *.log && \
	rm -f *.tmp && \
	rm -rf ./.Xil && \
	rm -f ./source/tcl/vivado* && \
	rm -rf ./vivado_project && \
	rm -rf ./vivado_outputs
