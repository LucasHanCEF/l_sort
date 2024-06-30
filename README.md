# L-Sort: An Efficient Hardware for Real-time Multi-channel Spike Sorting with Localization
L-Sort is the first localization-based spike sorting accelerator implemented on a miniaturized chip hardware (FPGA). This work has been submitted to the IEEE for possible publication. Copyright may be transferred without notice, after which
this version may no longer be accessible.

## Setup
**Install Vivado Design Suite**
```makefile
VIVADO_PATH := /home/USER_NAME/Xilinx/Vivado/2024.1
VIVADO_CMD := vivado
```

**Create a Conda environment**

Requirements:
* python=3.12
* numpy==1.26.4
* pytorch==2.3.1

**Download dataset**

The dataset used in this design was recorded using Neuropixel by Dr Nick Steinmetz, when he was with Cortexlab, UCL. The link for this dataset is [dataset](http://phy.cortexlab.net/data/sortingComparison/datasets/), which could be processed by the provided code in this repo (shown in workflow).

However, because the availbility of this website is not stable, we also provided a sliced pre-processed data in
https://datasync.ed.ac.uk/index.php/s/IgzYu0ES3TshAnw (password 27062024).

**Clone this repo**
```shell
git clone git@git.ecdf.ed.ac.uk:s2328236/biocas2024_l_sort.git
```

## Workflow
We integrated the workflow for generting FPGA bitstream into GNU make, which automatically pipeline the execution of python and tcl scripts. We developed this workflow in WSL, but this should be compatible to any Linux distribution capable of installing Python and Vivado.

Note that if you are using the provided processed .txt file as dataset for testing, please comment the following line in Makefile.
```shell
# python ./src/py/generate_data.py --length $(SIM_STEP) --channel $(CHANNEL_COUNT) --datawidth $(DATA_WIDTH)
```

The following command can generate all necessary files and send them to the FPGA board.
```shell
make all
```

However, for the first-time running, we recommand the following step-by-step execution for debugging.
 
```shell
# Generate dataset(.txt) and memory(.coe) file
make sw
# Generate the Vivado project and copy all necessary files into it
make hw_gen
# Create ip and connect it with PS, followed by implementation and bitstream generation
make hw_imp
# Send generated files and dataset to FPGA board through ssh
make send
```

## License

This project is licensed under the GNU GPLv3 License - see the [LICENSE](https://git.ecdf.ed.ac.uk/s2328236/biocas2024_l_sort/-/blob/main/LICENSE) file for details.

## Citation
Should you find this work valuable, we kindly request that you consider referencing our paper as below:
```bibtex
@misc{han2024lsort,
      title={{L-Sort: An Efficient Hardware for Real-time Multi-channel Spike Sorting with Localization}}, 
      author={Yuntao Han and Shiwei Wang and Alister Hamilton},
      year={2024},
      eprint={2406.18425},
      archivePrefix={arXiv},
      primaryClass={eess.SP},
      url={https://arxiv.org/abs/2406.18425}, 
}
```