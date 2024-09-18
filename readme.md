# PoTAcc: Power of Two quantization acceleration pipeline
This repository will contain the code for the PoTAcc pipeline.

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
      booktitle = {ICECS},
      year={2024}
      comment = {Accepted for publication}
}
```