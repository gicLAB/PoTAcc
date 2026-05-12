
#if defined(QKERAS)

// 8x4 bit non - uniform multiplication - QKeras 

sc_int<PROD_DATA_WIDTH> VMM_UNIT::mul_lut(sc_int<4> wgt, sc_int<8> inp) {
  // #pragma HLS inline off
  sc_int<PROD_DATA_WIDTH> c15 = 0;

  c15 = inp;
  c15 = c15 << wgt.range(2, 0);

  sc_int<PROD_DATA_WIDTH> result = c15;
  return result;
}

#elif defined(MSQ)

sc_int<PROD_DATA_WIDTH> VMM_UNIT::mul_lut(sc_int<4> wgt, sc_int<8> inp) {
  // #pragma HLS inline off
  sc_int<10> c10_1 = 0;
  // dealing with first PoT term
  if (wgt.range(2, 1) == 3) {
    c10_1 = 0;
  } else // shift by 0 or 1 or 2
  {
    c10_1 = inp;
    c10_1 = c10_1 << wgt.range(2, 1);
  }

  sc_int<10> c10_2 = 0;
  // dealing with second PoT term
  if (wgt.range(0, 0) == 0) {
    c10_2 = 0;
  } else { // shift by 2
    c10_2 = inp;
    c10_2 = c10_2 << 2;
  }

  sc_int<PROD_DATA_WIDTH> result = c10_1 + c10_2;
  return result;
}

#elif defined(APOT)
// // 8x4 bit non-uniform multiplication - APoT
sc_int<PROD_DATA_WIDTH> VMM_UNIT::mul_lut(sc_int<4> wgt, sc_int<8> inp) {
  // #pragma HLS inline off
  sc_int<11> c11 = 0;
  // dealing with first PoT term
  if (wgt.range(2, 1) == 1) {
    c11 = 0;
  } else // shift by 0, 2, 3
  {
    c11 = inp;
    c11 = c11 << wgt.range(2, 1);
  }

  sc_int<9> c9 = 0;
  // dealing with second PoT term
  if (wgt.range(0, 0) == 0) {
    c9 = 0;
  } else {
    c9 = inp;
    c9 = c9 << wgt.range(0, 0);
  }

  sc_int<PROD_DATA_WIDTH> result = c11 + c9;
  return result;
}
#else
// 8x4 bit uniform multiplication
// 12-bit intermediate result
sc_int<PROD_DATA_WIDTH> VMM_UNIT::mul_lut(sc_int<4> wgt, sc_int<8> inp) {
  sc_int<PROD_DATA_WIDTH> c = wgt * inp;
#pragma HLS RESOURCE variable = c core = Mul_LUT

  return c;
}

#endif

sc_int<16> VMM_UNIT::mul_s8_dsp(sc_int<8> a, sc_int<8> b) {
  sc_int<16> c;
  c = a * b;

  return c;
}

void VMM_UNIT::VM_PE_URAM(ACC_DTYPE<URAM_DATAWIDTH> *l1,
                          ACC_DTYPE<URAM_DATAWIDTH> *r1,
                          ACC_DTYPE<URAM_DATAWIDTH> *r2, ACC_DTYPE<32> *ws1,
                          ACC_DTYPE<32> *ws2, ACC_DTYPE<32> *ws3,
                          ACC_DTYPE<32> *ws4, ACC_DTYPE<32> out[][4], int d,
                          int w_idx, int wsum_idx, int wID) {

  ACC_DTYPE<16> wgt_read[4];
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
#pragma HLS pipeline II = 1
    wgt_read[0] = l1[w_idx + rin].range(15, 0);
    wgt_read[1] = l1[w_idx + rin].range(31, 16);
    wgt_read[2] = l1[w_idx + rin].range(47, 32);
    wgt_read[3] = l1[w_idx + rin].range(63, 48);

    inp_read[0] = r1[rin].range(31, 0);
    inp_read[1] = r1[rin].range(63, 32);
    inp_read[2] = r2[rin].range(31, 0);
    inp_read[3] = r2[rin].range(63, 32);

    for (int i = 0; i < 4; i++) {
#pragma HLS unroll
      we_a[i + 0] = wgt_read[i].range(3, 0);
      we_a[i + 4] = wgt_read[i].range(7, 4);
      we_b[i + 0] = wgt_read[i].range(11, 8);
      we_b[i + 4] = wgt_read[i].range(15, 12);

      in_a[i + 0] = inp_read[i].range(7, 0);
      in_a[i + 4] = inp_read[i].range(15, 8);
      in_b[i + 0] = inp_read[i].range(23, 16);
      in_b[i + 4] = inp_read[i].range(31, 24);
    }

    // calculate products
    for (int i = 0; i < 4; i++) {
#pragma HLS unroll
      prod[i * 4 + 0][0] = mul_lut(we_a[0 * 4 + i], in_a[0 * 4 + 0]);
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
      if (we_a[0 * 4 + (i >> 2)].range(3, 3)) out[i][0] -= prod[i][0];
      else out[i][0] += prod[i][0];
      if (we_a[1 * 4 + (i >> 2)].range(3, 3)) out[i][1] -= prod[i][1];
      else out[i][1] += prod[i][1];
      if (we_b[0 * 4 + (i >> 2)].range(3, 3)) out[i][2] -= prod[i][2];
      else out[i][2] += prod[i][2];
      if (we_b[1 * 4 + (i >> 2)].range(3, 3)) out[i][3] -= prod[i][3];
      else out[i][3] += prod[i][3];
    }
  }
  DWAIT(5 + d);
  for (int i = 0; i < 16; i++) {
#pragma HLS unroll
    out[i][0] += out[i][1] + out[i][2] + out[i][3] + wsum_read[i / 4];
  }
  DWAIT(2);
}