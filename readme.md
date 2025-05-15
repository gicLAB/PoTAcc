# PoTAcc: Power of Two quantization acceleration pipeline

This repository will contain the code for the PoTAcc pipeline.

To run the code, please download the SECDA-TFLite repository from
[https://github.com/gicLAB/SECDA-TFLite.git](https://github.com/gicLAB/SECDA-TFLite.git).

Copy the following folders in the SECDA-TFLite workspace:

- The mm_accelerator folder needs to be renamed to vm_shift_delegate and copied under `<Path To SECDA-TFLite workspace>/src/secda_delegates`.
- The `vm_shift_accelerator--> vm_shift_delegate` folder needs to be copied under `<Path To SECDA-TFLite workspace>/src/secda_delegates`.

#### Hardware Generation

- To be updated

#### Run Simulation

- To be updated

#### Run on Hardware

- To be updated

# Paper

In this paper, we first design shift-based processing elements
(shift-PE) for different PoT quantization methods and evaluate
their efficiency using synthetic benchmarks. We then design a
shift-based accelerator using our most efficient shift-PE, but
we found lack of open-source pipelines for accelerating PoT-
quantized DNN models, hence we propose an open source end-
to-end PoT acceleration pipeline (PoTAcc) for edge devices.
Using PoTAcc, we evaluate the accelerator performance across
three well-known DNN models.

```
@inproceedings{SAHA2024ICECS,
      title={{Accelerating PoT Quantization on Edge Devices}}, 
      author={Rappy Saha and Jude Haris and José Cano},
      booktitle = {2024 31st IEEE International Conference on Electronics, Circuits and Systems (ICECS)},
      year={2024}
      comment = {Accepted for publication}
}
```
