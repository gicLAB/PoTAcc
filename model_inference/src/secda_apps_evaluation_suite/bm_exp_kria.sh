#!/bin/bash

# run all the benchmark_model evaluations for Kria hardware

./secda_apps_evaluation_suite.sh -j configs/bm_cpu_kria.json -n bm_cpu_kria -b -c

./secda_apps_evaluation_suite.sh -j configs/bm_VMOPT_kria.json -n bm_VMOPT_kria -b -c

./secda_apps_evaluation_suite.sh -j configs/bm_VMSHQKERAS_kria.json -n bm_VMSHQKERAS_kria -b -c

./secda_apps_evaluation_suite.sh -j configs/bm_VMSHMSQ_kria.json -n bm_VMSHMSQ_kria -b -c

./secda_apps_evaluation_suite.sh -j configs/bm_VMSHAPOT_kria.json -n bm_VMSHAPOT_kria -b -c