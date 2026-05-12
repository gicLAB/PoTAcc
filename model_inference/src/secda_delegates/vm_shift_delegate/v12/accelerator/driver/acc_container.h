#ifndef ACC_CONTAINER
#define ACC_CONTAINER

#ifdef SYSC
#include "../acc.sc.h"
#include "systemc_binding.h"
#else
#endif

#include "../acc_config.sc.h"
#include "secda_tools/axi_support/v5/axi_api_v5.h"
#include "secda_tools/secda_profiler/profiler.h"
#include "secda_tools/secda_utils/acc_helpers.h"
#include "secda_tools/secda_utils/multi_threading.h"
#include "secda_tools/secda_utils/utils.h"
#include <chrono>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <sys/mman.h>
#include <typeinfo>
#include <unistd.h>
#include <vector>

#ifdef ACC_NEON
#include "arm_neon.h"
#endif

using namespace std;
using namespace std::chrono;
#define TSCALE microseconds

struct vm_times {
  duration_ns load_send_inputs;
  duration_ns load_send_weights;
  duration_ns send_weights;
  duration_ns set_results;
  duration_ns start_compute;
  duration_ns receive_results;
  duration_ns vm_acc;
  duration_ns store;
  duration_ns ipack;
  duration_ns conv_total;

  void print() {
#ifdef ACC_PROFILE
    cout << "================================================" << endl;
    prf_out(TSCALE, load_send_inputs);
    prf_out(TSCALE, load_send_weights);
    prf_out(TSCALE, send_weights);
    prf_out(TSCALE, set_results);
    prf_out(TSCALE, start_compute);
    prf_out(TSCALE, receive_results);
    prf_out(TSCALE, store);
    prf_out(TSCALE, vm_acc);
    prf_out(TSCALE, ipack);
    prf_out(TSCALE, conv_total);
    cout << "================================================" << endl;
#endif
  }

  void save_prf() {
#ifdef ACC_PROFILE
    std::ofstream file("prf.csv", std::ios::out);
    prf_file_out(TSCALE, load_send_inputs, file);
    prf_file_out(TSCALE, load_send_weights, file);
    prf_file_out(TSCALE, send_weights, file);
    prf_file_out(TSCALE, set_results, file);
    prf_file_out(TSCALE, start_compute, file);
    prf_file_out(TSCALE, receive_results, file);
    prf_file_out(TSCALE, store, file);
    prf_file_out(TSCALE, vm_acc, file);
    prf_file_out(TSCALE, ipack, file);
    prf_file_out(TSCALE, conv_total, file);
    file.close();
#endif
  }
};

// Used for profiling
struct layer_details {
  int layer = 0;
  int conv_layer_no = 0; // for conv layers
  int node = 0;
  int layer_weight_tile = 0;
  int layer_input_tile = 0;
  unsigned int wgt_tile_offset = 0;           // offset for the weight tile
  unsigned int layer_wgt_dma_curr_offset = 0; // each buffer layer offset
  unsigned int layer_wgt_offsets[500]; // assuming we will not need to allocate
                                       // more than 500
  // layers
  bool layer_wgt_preLoadedToDMA[500]; // to check if the layer is allocated or
                                      // not
  bool profile = false;

  bool alloc_layer(int layer, unsigned int layer_wgt_dma_curr_offset,
                   unsigned int wgt_size) {
    if (((layer_wgt_dma_curr_offset * NO_OF_DATA_CHANNELS * sizeof(int32_t)) +
         wgt_size) >= (DMA_WGT_SIZE_4 * NO_OF_DATA_CHANNELS)) {
      return false;
    }
    layer_wgt_offsets[layer] = layer_wgt_dma_curr_offset;
    layer_wgt_preLoadedToDMA[layer] = true;
    return true;
  }
  bool alloc_layerV2(int layer, unsigned int layer_wgt_dma_curr_offset,
                     unsigned int wgt_size_per_buf_bytes) {
    const uint64_t offset_bytes =
        uint64_t(layer_wgt_dma_curr_offset) * sizeof(int32_t);
    if (offset_bytes + wgt_size_per_buf_bytes > DMA_WGT_SIZE_4) {
      return false;
    }
    layer_wgt_offsets[layer] =
        layer_wgt_dma_curr_offset; // per-buffer word offset
    layer_wgt_preLoadedToDMA[layer] = true;
    return true;
  }
};

// Used for tracking output locations
struct store_params {
  int *dst;
  int dcs;
  int rows;
  int cols;
  int rcols;
  int rrows;
};

struct acc_container {
#ifdef SYSC
  // Gives SystemC accelerator access
  ACCNAME *acc;
#else
  // Gives accelerator access
  int *acc;
#endif

  Profile *profile;
  // DMAs Pointer
  struct s_mdma *mdma;
  MultiThreadContext *mt_context;
  // Accelerator Layer Details
  int op_type;

  // Temporary Weight non-MMapped Padded Buffers
  int *wb_0;
  int *wb_1;
  int *wb_2;
  int *wb_3;

  // Temporary Input non-MMapped Padded Buffers
  int *inb_0;
  int *inb_1;
  int *inb_2;
  int *inb_3;
  int in_id = 0;

  // Driver variables
  struct store_params *st_params;
  int thread_count;
  int w_c = 0;

  // Output Pipeline Metadata
  vector<int> wt_sum1;
  vector<int> wt_sum2;
  vector<int> wt_sum3;
  vector<int> wt_sum4;
  int *in_sum1;
  int *in_sum2;
  int *in_sum3;
  int *in_sum4;
  int *bias;
  vector<int> crf;
  vector<int8_t> crx;
  int ra;
  int inp_offset = 0;
  int wgt_offset = 0;

  int rows = 0;
  int cols = 0;
  int depth = 0;
  int8_t *dst;

  // Pipeline vars
  struct dma_buffer_set *dfs;
  struct DSR dsr;
  bool wgt_start = false;
  int recv_len;

  // GEMM Info variable
  struct layer_details *t;
  struct vm_times t2;
  bool use_sim = false;

  bool Check_Done() { return (mdma->multi_dma_check_recv() == 0); }

  void End_Transfer() { mdma->multi_dma_wait_send(); }

  bool Start_Transfer() {
    if (!(dsr.sID == dsr.cID && dsr.dID > dsr.sID)) return false;
    int s_buf = find_dbuf(dfs[0], dsr.sID);
    mdma->multi_dma_change_start_4(dfs[0].dbuf_set[s_buf].offset);
    mdma->dmas[0].dma_start_send(dfs[0].dbuf_set[s_buf].len);
    mdma->dmas[1].dma_start_send(dfs[1].dbuf_set[s_buf].len);
    mdma->dmas[2].dma_start_send(dfs[2].dbuf_set[s_buf].len);
    mdma->dmas[3].dma_start_send(dfs[3].dbuf_set[s_buf].len);
    End_Transfer();
    dsr.sID++;
    return true;
  }

  void Set_Results() {
    // int s_buf = find_dbuf(dfs[0], dsr.cID);
    // mdma->multi_dma_change_end(dfs[0].dbuf_set[s_buf].offset);
    mdma->multi_dma_change_end(0);
    mdma->multi_dma_start_recv(recv_len);
    // dsr.cID++;
  }

  void Recieve_Results() { mdma->multi_dma_wait_recv_4(); }
};

void pre_load_wgt_toDMA(vector<int8_t> &wb0, vector<int8_t> &wb1,
                        vector<int8_t> &wb2, vector<int8_t> &wb3, int *dims,
                        layer_details *t, s_mdma *mdma) {

  // check NO_OF_DATA_CHANNELS is 4
  assert(NO_OF_DATA_CHANNELS == 4 &&
         "Error: pre_load_wgt_toDMA():NO_OF_DATA_CHANNELS must be 4 for this "
         "function");
  // round up width and depth
  int width = dims[0];
  int depth = dims[1] * dims[2] * dims[3];
  int rwidth = roundUp(width, WGTBLOCK_WIDTH);
  int rdepth = roundUp(depth, BLOCK_DEPTH);

  // Calculate the data size needs to copy this time to DMA
  int dataSize = rwidth * rdepth / 2; // divide by 2 because 4-bit weights
  int dataSizeEachBuff = dataSize / NO_OF_DATA_CHANNELS;
  // DLOG("pre_load_wgt_toDMA: width: " << width << " depth: " << depth
  //                                    << " rwidth: " << rwidth << " rdepth: "
  //                                    << rdepth << " dataSize: " << dataSize);
  // check allocation will be okay or not
  // bool check =
  //     t->alloc_layer(t->conv_layer_no, t->layer_wgt_dma_curr_offset,
  //     dataSize);
  bool check = t->alloc_layerV2(t->conv_layer_no, t->layer_wgt_dma_curr_offset,
                                dataSizeEachBuff);
  assert(check && "Error: pre_load_wgt_toDMA(): "
                  "alloc_layer failed");

  // DLOG("conv_layer_no: " << t->conv_layer_no << " layer_wgt_offsets: "
  //                        << t->layer_wgt_offsets[t->conv_layer_no]);

  //
  int *in0 = mdma->dmas[0].dma_get_inbuffer() + DMA_SCRATCH_SIZE_4 +
             t->layer_wgt_dma_curr_offset;
  int *in1 = mdma->dmas[1].dma_get_inbuffer() + DMA_SCRATCH_SIZE_4 +
             t->layer_wgt_dma_curr_offset;
  int *in2 = mdma->dmas[2].dma_get_inbuffer() + DMA_SCRATCH_SIZE_4 +
             t->layer_wgt_dma_curr_offset;
  int *in3 = mdma->dmas[3].dma_get_inbuffer() + DMA_SCRATCH_SIZE_4 +
             t->layer_wgt_dma_curr_offset;
  // reinterpret cast to int8_t pointer
  int8_t *in0_ptr = reinterpret_cast<int8_t *>(in0);
  int8_t *in1_ptr = reinterpret_cast<int8_t *>(in1);
  int8_t *in2_ptr = reinterpret_cast<int8_t *>(in2);
  int8_t *in3_ptr = reinterpret_cast<int8_t *>(in3);

  // use memcpy to copy the data from wb0, wb1, wb2, wb3
  // to in0_ptr, in1_ptr, in2_ptr, in3_ptr because in
  // here wb0, wb1, wb2, wb3 are pointing to the 0
  // address
  memcpy(in0_ptr, wb0.data(), dataSizeEachBuff);
  memcpy(in1_ptr, wb1.data(), dataSizeEachBuff);
  memcpy(in2_ptr, wb2.data(), dataSizeEachBuff);
  memcpy(in3_ptr, wb3.data(), dataSizeEachBuff);

  // update prev_offset
  // dataSizeEachBuff is in no. of bytes, since we are
  // using int8 weights no. of elements are same as no.
  // of bytes we are pointing in0, in1, in2, in3 using
  // int pointers
  t->layer_wgt_dma_curr_offset += dataSizeEachBuff / sizeof(int32_t);
}


void precal_sum_load_pad(const int8_t *data, int width, int depth, int8_t *inb0,
                         int8_t *inb1, int8_t *inb2, int8_t *inb3) {
  int w = ((width + 3) - ((width + 3) % 4));
  int d = ((depth + 15) - ((depth + 15) % 16));
  int d2 = depth * 2;
  int d3 = depth * 3;
  int d4 = depth * 4;
  int i_c = 0;
  int sums_curr = 0;

  const int8_t *inp_d = reinterpret_cast<const int8_t *>(data);
  int dm = 0;
  for (int i = 0; i < w / 4; i++) {
    int id = i * d4;
    int i0 = id;
    int i1 = id + depth;
    int i2 = id + d2;
    int i3 = id + d3;
    int ss0 = 0;
    int ss1 = 0;
    int ss2 = 0;
    int ss3 = 0;

#ifdef ACC_NEON
    dm = d - 16;
    int8x16_t tmp0;
    int8x16_t tmp1;
    int8x16_t tmp2;
    int8x16_t tmp3;

    for (int j = 0; j < dm; j += 16) {
      tmp0 = vld1q_s8(inp_d + i0 + j);
      tmp1 = vld1q_s8(inp_d + i1 + j);
      tmp2 = vld1q_s8(inp_d + i2 + j);
      tmp3 = vld1q_s8(inp_d + i3 + j);
      vst1q_s8(inb0 + i_c, tmp0);
      vst1q_s8(inb1 + i_c, tmp1);
      vst1q_s8(inb2 + i_c, tmp2);
      vst1q_s8(inb3 + i_c, tmp3);
      i_c += 16;
    }

#endif
    for (int j = dm; j < d; j++) {
      if (j < depth) {
        unsigned char w0 = data[i0 + j];
        unsigned char w1 = data[i1 + j];
        unsigned char w2 = data[i2 + j];
        unsigned char w3 = data[i3 + j];

        inb0[i_c] = w0;
        inb1[i_c] = w1;
        inb2[i_c] = w2;
        inb3[i_c++] = w3;
      } else {
        inb0[i_c] = 0;
        inb1[i_c] = 0;
        inb2[i_c] = 0;
        inb3[i_c++] = 0;
      }
    }
  }
}

#endif // ACC_CONTAINER