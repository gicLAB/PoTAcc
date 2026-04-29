# PoTAcc: Power of Two quantization acceleration pipeline

This repository will contain the code for the PoTAcc pipeline.

## SECDA-TFLite v2 SETUP

- To run PoTAcc, please download the SECDA-TFLite repository from
[https://github.com/gicLAB/SECDA-TFLite.git](https://github.com/gicLAB/SECDA-TFLite.git) and follow the instructions in the SECDA-TFLite repository to set up the environment.

- Use Dev Container Method of VSCode to set up the development environment.

- Verify that you can run SECDA-TFLite v2 for vm/v5 accelerator, **simulation, hardware automation and benchmark suite** for Pynq-Z2 board before integrating PoTAcc.

- If you face any issues setting up SECDA-TFLite v2, please create an issue in the SECDA-TFLite repository.

## PoTAcc Integration Steps

Will be updated soon.

## Folder structure:

|-- tensorflow/
  |-- .vscode/
    |-- launch.json
    |-- tasks.json
|-- hardware_automation/
  |-- configs/
    |-- potacc/
      |-- VMSHv12_0_KRIA.json
|-- src/
  |-- secda_delegates/
    |-- vm_opt_delegate/
      |-- v12/
    |-- vm_shift_delegate/
      |-- v12/
|-- potacc_integration.sh
|-- readme.md

```
@article{SAHA2026TCASAI,
      title={{PoTAcc: A Pipeline for End-to-End Acceleration of Power-of-Two Quantized DNNs}}, 
      author={Rappy Saha and Jude Haris and Nicolas Bohm Agostini and David Kaeli and José Cano},
      journal={IEEE Transactions on Circuits and Systems for Artificial Intelligence},
      year={2026}
      comment = {Accepted for publication}
}
```
