import numpy as np
import argparse
import logging


if __name__ == "__main__":
    
    # Read args
    parser = argparse.ArgumentParser(description="Read Data for Testbench")
    parser.add_argument('--channel'  , default=120                                , type=int, help='Channel count from dataset.')
    parser.add_argument('--datawidth', default=16                                 , type=int, help='Data bitwidth from dataset.')
    parser.add_argument('--window'   , default=25                                 , type=int, help='Window point for calculating median.')
    args = parser.parse_args()

    coe_str = 'memory_initialization_radix=2;\nmemory_initialization_vector=\n'
    
    window_bitwidth = np.ceil(np.log2(args.window - 1)).astype(np.int16)
    coe_line = ''
    data_line = '1' * (args.datawidth - 1)
    for w in range(args.window-1):
        coe_line = coe_line + format(w+1, f'0{window_bitwidth}b') + data_line
    coe_line = coe_line + ',\n'
    for c in range(args.channel):
        coe_str = coe_str + coe_line
    coe_str = coe_str[:-2]
    with open('./hw/python_outputs/detector.coe', 'w') as f:
        f.write(coe_str)
        f.close()
