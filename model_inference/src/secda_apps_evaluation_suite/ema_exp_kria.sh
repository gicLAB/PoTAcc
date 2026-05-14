#!/bin/bash

# run all the eval_model_accuracy evaluations for Kria hardware
./secda_apps_evaluation_suite.sh -j configs/ema_VMOPT_kria.json -n ema_VMOPT_kria -b -c
./secda_apps_evaluation_suite.sh -j configs/ema_VMSHQKERAS_kria.json -n ema_VMSHQKERAS_kria -b -c