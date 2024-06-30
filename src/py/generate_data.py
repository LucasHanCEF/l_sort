import numpy as np
import multiprocessing as mp
import argparse


def generate_str(data, channel_length, datawidth):
    data_file = ''
    for t in range(data.shape[0]):
        data_file_temp = ''
        for c in range(data.shape[1]):
            channel_temp = format(c, f'0{channel_length}b')
            data_max = 2 ** (datawidth - 1) - 1
            data_min = - 2 ** (datawidth - 1)
            data[data<data_min] = data_min
            data[data>data_max] = data_max
            data_temp = np.binary_repr(data[t, c], width=datawidth)
            data_file_temp = data_file_temp + (32 - channel_length - datawidth - 1) * '0' + channel_temp + data_temp + '1' + '\n'
        # for i in range(5):
        #     data_file_temp = data_file_temp + 32 * '0' + '\n'
        data_file = data_file + data_file_temp
    return data_file


def generate_npy(data, channel_length, datawidth):
    data_npy = np.empty_like(data, dtype=np.uint32)
    for t in range(data.shape[0]):
        for c in range(data.shape[1]):
            channel_temp = format(c, f'0{channel_length}b')
            data_temp = np.binary_repr(data[t, c], width=datawidth)
            value = (32 - channel_length - datawidth) * '0' + channel_temp + data_temp
            data_npy[t, c] = int(value, 2)
    return data_npy


if __name__ == "__main__":
    
    # Read args
    parser = argparse.ArgumentParser(description="Read Data for Testbench")
    parser.add_argument('--file'     , default='/root/dataset/20141202_all_es.dat', type=str, help='Path to dataset.')
    parser.add_argument('--geo'      , default='/root/dataset/geoC.txt'           , type=str, help='Path to geometry.')
    parser.add_argument('--length'   , default=100000                                   , type=int, help='Read length from dataset.')
    parser.add_argument('--channel'  , default=120                                      , type=int, help='Channel count from dataset.')
    parser.add_argument('--datawidth', default=16                                       , type=int, help='Data bitwidth from dataset.')
    args = parser.parse_args()
    
    # Read data
    data = np.memmap(filename=args.file, dtype='int16')
    prb = np.loadtxt(args.geo, delimiter=",", dtype='int16') - 1
    data = data.reshape([data.shape[0] // 129, 129])
    data = data[:args.length, prb][:, :args.channel]
    channel_length = np.ceil(np.log2(args.channel)).astype(np.int16)

    num_cores = int(mp.cpu_count())
    pool = mp.Pool(num_cores)

    time_length = data.shape[0] // num_cores
    data = data.reshape(num_cores,time_length,data.shape[1])

    data_file = [pool.apply_async(generate_str, args=(data_slice, channel_length, args.datawidth)) for data_slice in data]
    data_file = [p.get() for p in data_file]
    data_file = ''.join(data_file)
    with open('./hw/python_outputs/raw_data.txt', 'w') as f:
        f.write(data_file)
        f.close()
