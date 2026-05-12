
sc_int<16> VMM_UNIT::mul_lut(sc_int<8> a, sc_int<8> b) {
  sc_int<16> c;
#pragma HLS RESOURCE variable = c core = Mul
  // #pragma HLS inline off
  c = a * b;

  return c;
}

sc_int<16> VMM_UNIT::mul_dsp(sc_int<8> a, sc_int<8> b) {
  sc_int<16> c;
  c = a * b;

  return c;
}
void VMM_UNIT::VM_PE_URAM(ACC_DTYPE<URAM_DATAWIDTH> *l1,
                          ACC_DTYPE<URAM_DATAWIDTH> *l2,
                          ACC_DTYPE<URAM_DATAWIDTH> *r1,
                          ACC_DTYPE<URAM_DATAWIDTH> *r2, ACC_DTYPE<32> *ws1,
                          ACC_DTYPE<32> *ws2, ACC_DTYPE<32> *ws3,
                          ACC_DTYPE<32> *ws4, ACC_DTYPE<32> out[][4], int d,
                          int w_idx, int wsum_idx, int wID) {

  ACC_DTYPE<32> wgt_read[4];
  ACC_DTYPE<32> inp_read[4];
  ACC_DTYPE<32> wsum_read[4];
  ACC_DTYPE<8> in_a[8];
  ACC_DTYPE<8> in_b[8];
  ACC_DTYPE<8> we_a[8];
  ACC_DTYPE<8> we_b[8];
  ACC_DTYPE<16> prod[16][4];

#pragma HLS array_partition variable = wgt_read complete dim = 0
#pragma HLS array_partition variable = inp_read complete dim = 0
#pragma HLS array_partition variable = wsum_read complete dim = 0
#pragma HLS array_partition variable = in_a complete dim = 0
#pragma HLS array_partition variable = in_b complete dim = 0
#pragma HLS array_partition variable = we_a complete dim = 0
#pragma HLS array_partition variable = we_b complete dim = 0
#pragma HLS array_partition variable = prod complete dim = 0

  if (wID == 1) {
    wsum_read[0] = ws1[wsum_idx];
    wsum_read[1] = ws2[wsum_idx];
    wsum_read[2] = ws3[wsum_idx];
    wsum_read[3] = ws4[wsum_idx];
  } else {
    wsum_read[0] = 0;
    wsum_read[1] = 0;
    wsum_read[2] = 0;
    wsum_read[3] = 0;
  }

  for (int i = 0; i < 4; i++) {
#pragma HLS unroll
    for (int j = 0; j < ACC_OUT_SIZE; j++) {
#pragma HLS unroll
      out[j][i] = 0;
    }
  }
  for (int rin = 0; rin < d; rin++) {
#pragma HLS loop_tripcount min = 1 max = 512 avg = 256
#pragma HLS pipeline II = 1
    wgt_read[0] = l1[w_idx + rin].range(31, 0);
    wgt_read[1] = l1[w_idx + rin].range(63, 32);
    wgt_read[2] = l2[w_idx + rin].range(31, 0);
    wgt_read[3] = l2[w_idx + rin].range(63, 32);

    inp_read[0] = r1[rin].range(31, 0);
    inp_read[1] = r1[rin].range(63, 32);
    inp_read[2] = r2[rin].range(31, 0);
    inp_read[3] = r2[rin].range(63, 32);

    for (int i = 0; i < 4; i++) {
#pragma HLS unroll
      we_a[i + 0] = wgt_read[i].range(7, 0);
      we_a[i + 4] = wgt_read[i].range(15, 8);
      we_b[i + 0] = wgt_read[i].range(23, 16);
      we_b[i + 4] = wgt_read[i].range(31, 24);

      in_a[i + 0] = inp_read[i].range(7, 0);
      in_a[i + 4] = inp_read[i].range(15, 8);
      in_b[i + 0] = inp_read[i].range(23, 16);
      in_b[i + 4] = inp_read[i].range(31, 24);
    }

    // calculate products
    for (int i = 0; i < 4; i++) {
#pragma HLS unroll
#ifdef KRIA
      prod[i * 4 + 0][0] = mul_lut(we_a[0 * 4 + i], in_a[0 * 4 + 0]);
#else //PYNQ-Z2
      prod[i * 4 + 0][0] = mul_dsp(we_a[0 * 4 + i], in_a[0 * 4 + 0]);
#endif

      prod[i * 4 + 1][0] = mul_lut(we_a[0 * 4 + i], in_a[0 * 4 + 1]);
      prod[i * 4 + 2][0] = mul_lut(we_a[0 * 4 + i], in_a[0 * 4 + 2]);
      prod[i * 4 + 3][0] = mul_lut(we_a[0 * 4 + i], in_a[0 * 4 + 3]);
      prod[i * 4 + 0][1] = mul_lut(we_a[1 * 4 + i], in_a[1 * 4 + 0]);
      prod[i * 4 + 1][1] = mul_lut(we_a[1 * 4 + i], in_a[1 * 4 + 1]);
      prod[i * 4 + 2][1] = mul_lut(we_a[1 * 4 + i], in_a[1 * 4 + 2]);
      prod[i * 4 + 3][1] = mul_lut(we_a[1 * 4 + i], in_a[1 * 4 + 3]);

      prod[i * 4 + 0][2] = mul_lut(we_b[0 * 4 + i], in_b[0 * 4 + 0]);
      prod[i * 4 + 1][2] = mul_lut(we_b[0 * 4 + i], in_b[0 * 4 + 1]);
      prod[i * 4 + 2][2] = mul_lut(we_b[0 * 4 + i], in_b[0 * 4 + 2]);
      prod[i * 4 + 3][2] = mul_lut(we_b[0 * 4 + i], in_b[0 * 4 + 3]);
      prod[i * 4 + 0][3] = mul_lut(we_b[1 * 4 + i], in_b[1 * 4 + 0]);
      prod[i * 4 + 1][3] = mul_lut(we_b[1 * 4 + i], in_b[1 * 4 + 1]);
      prod[i * 4 + 2][3] = mul_lut(we_b[1 * 4 + i], in_b[1 * 4 + 2]);
      prod[i * 4 + 3][3] = mul_lut(we_b[1 * 4 + i], in_b[1 * 4 + 3]);

      // prod[i * 4 + 0][0] = mul_dsp(we_a[0 * 4 + i], in_a[0 * 4 + 0]);
      // prod[i * 4 + 1][0] = mul_dsp(we_a[0 * 4 + i], in_a[0 * 4 + 1]);
      // prod[i * 4 + 2][0] = mul_dsp(we_a[0 * 4 + i], in_a[0 * 4 + 2]);
      // prod[i * 4 + 3][0] = mul_dsp(we_a[0 * 4 + i], in_a[0 * 4 + 3]);
      // prod[i * 4 + 0][1] = mul_dsp(we_a[1 * 4 + i], in_a[1 * 4 + 0]);
      // prod[i * 4 + 1][1] = mul_dsp(we_a[1 * 4 + i], in_a[1 * 4 + 1]);
      // prod[i * 4 + 2][1] = mul_dsp(we_a[1 * 4 + i], in_a[1 * 4 + 2]);
      // prod[i * 4 + 3][1] = mul_dsp(we_a[1 * 4 + i], in_a[1 * 4 + 3]);

      // prod[i * 4 + 0][2] = mul_dsp(we_b[0 * 4 + i], in_b[0 * 4 + 0]);
      // prod[i * 4 + 1][2] = mul_dsp(we_b[0 * 4 + i], in_b[0 * 4 + 1]);
      // prod[i * 4 + 2][2] = mul_dsp(we_b[0 * 4 + i], in_b[0 * 4 + 2]);
      // prod[i * 4 + 3][2] = mul_dsp(we_b[0 * 4 + i], in_b[0 * 4 + 3]);
      // prod[i * 4 + 0][3] = mul_dsp(we_b[1 * 4 + i], in_b[1 * 4 + 0]);
      // prod[i * 4 + 1][3] = mul_dsp(we_b[1 * 4 + i], in_b[1 * 4 + 1]);
      // prod[i * 4 + 2][3] = mul_dsp(we_b[1 * 4 + i], in_b[1 * 4 + 2]);
      // prod[i * 4 + 3][3] = mul_dsp(we_b[1 * 4 + i], in_b[1 * 4 + 3]);
    }
    for (int i = 0; i < 16; i++) {
#pragma HLS unroll
      out[i][0] += prod[i][0];
      out[i][1] += prod[i][1];
      out[i][2] += prod[i][2];
      out[i][3] += prod[i][3];
    }
  }
  DWAIT(5 + d);
  for (int i = 0; i < 16; i++) {
#pragma HLS unroll
    out[i][0] += out[i][1] + out[i][2] + out[i][3] + wsum_read[i / 4];
  }
  DWAIT(2);
}
