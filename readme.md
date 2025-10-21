# PoTAcc: Power of Two quantization acceleration pipeline

This repository will contain the code for the PoTAcc pipeline.

## SECDA-TFLite v2 SETUP

- To run PoTAcc, please download the SECDA-TFLite repository from
[https://github.com/gicLAB/SECDA-TFLite.git](https://github.com/gicLAB/SECDA-TFLite.git) and follow the instructions in the SECDA-TFLite repository to set up the environment.

- Use Dev Container Method of VSCode to set up the development environment.

- Verify that you can run SECDA-TFLite v2 for vm/v5 accelerator, **simulation, hardware automation and benchmark suite** for Pynq-Z2 board before integrating PoTAcc.

- If you face any issues setting up SECDA-TFLite v2, please create an issue in the SECDA-TFLite repository.

## PoTAcc Integration Steps

Now we will describe the steps to integrate PoTAcc into SECDA-TFLite v2. We have two accelerators:

1. MatMul accelerator(MM): For evaluating shift-PEs with synthetic benchmarks for QKeras, MSQ and APoT quantization methods.
      - Copy the mm_accelerator/vm_shift_delegate/v4 folder to SECDA-TFLite workspace(`<Path To SECDA-TFLite workspace>/src/secda_delegates/vm_shift_delegate/v4`).

2. Shift-based accelerator: For evaluating DNN models on shift-PEs for QKeras, MSQ and APoT quantization methods.
      - Copy the vm_shift_accelerator/vm_shift_delegate/v2 folder to SECDA-TFLite workspace(`<Path To SECDA-TFLite workspace>/src/secda_delegates/vm_shift_delegate/v2`).

3. Quantization selection

- File: accelerator/acc_config.sc.h (present in both accelerator copies).
- Purpose: choose which PoT quantization method the accelerator will use at build time.
- How to use: uncomment the single define that corresponds to the desired method and comment out the others. Only enable one method at a time to avoid conflicting configurations. After changing the file, rebuild the accelerator / SECDA-TFLite workspace.

      // Example (only QKERAS enabled):
      // Select exactly one quantization method:
      #define QKERAS
      //#define MSQ
      //#define APOT
      
4. Copy the models:

- Copy the models from `models/ImageNet/` to SECDA-TFLite workspace(`<Path To SECDA-TFLite workspace>/data/models/`). This models are int8 quantized and ran with the shift-based accelerator just to collect performance and energy metrics.

- Copy the models from `models/cifar10/` to SECDA-TFLite workspace(`<Path To SECDA-TFLite workspace>/data/models/`). This model is PoT quantized with QKeras quantization method and trained from scartch by us using TensorFlow-Keras and later converted to TFLite.
This model will be used to verify the correctness of the shift-based accelerator when selecting QKeras quantization method. Update `<Path To SECDA-TFLite workspace>/src/benchmark_suite/configs/models.json` to include the cifar10 model.

      {
            "name": "mobilenetv2_QKERAS",
            "dataset": "cifar10",
            "datatype": "int8",
            "layers": [
            "CONV_2D",
            "depthwise_conv2d"
            ]
      },      

- Copy the models from `models/synthetic_benchmark/` to SECDA-TFLite workspace(`<Path To SECDA-TFLite workspace>/src/benchmark_suite/model_gen/models/synthetic_exp/`). These models are used to evaluate the MatMul accelerator with synthetic benchmarks for different PoT quantization methods. Since these models are as a set, copy `models/synthetic_exp.json` to SECDA-TFLite workspace(`<Path To SECDA-TFLite workspace>/src/benchmark_suite/configs/model_sets/`).

### Run Simulation

1. To run the simulation vm_shift_delegate/v2 and vm_shift_delegate/v4 accelerators, we need to modify the `<Path To SECDA-TFLite workspace>/tensorflow/.vscode/launch.json` and add the following configurations:

      ```json
        {
            "preLaunchTask": "inference_diff_plus_vm_shift_delegate_v2",
            "name": "Inference Diff | VMSHv2",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/bazel-bin/tensorflow/lite/delegates/utils/secda_delegates/vm_shift_delegate/v2/inference_diff_plus_vm_shift_delegate",
            "args": [
                "--model_file=${workspaceFolder}/../data/models/mobilenetv2_QKERAS.tflite",
                "--num_runs=1",
                "--use_vm_shift_delegate=true",
            ],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ]
        },
        {
            "preLaunchTask": "inference_diff_plus_vm_shift_delegate_v4",
            "name": "Inference Diff | VMSHMMv4",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/bazel-bin/tensorflow/lite/delegates/utils/secda_delegates/vm_shift_delegate/v4/inference_diff_plus_vm_shift_delegate",
            "args": [
                "--model_file=${workspaceFolder}/../src/benchmark_suite/model_gen/models/synthetic_exp/mnk_128_64_256.tflite",
                "--num_runs=1",
                "--use_vm_shift_delegate=true",
            ],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ]
        },
      ```

2. We also need to modify the `<Path To SECDA-TFLite workspace>/tensorflow/.vscode/tasks.json` to add the following preLaunchTasks:

      ```json
    {
      "label": "inference_diff_plus_vm_shift_delegate_v2",
      "type": "shell",
      "command": "bazel6 build tensorflow/lite/delegates/utils/secda_delegates/vm_shift_delegate/v2:inference_diff_plus_vm_shift_delegate -c dbg --cxxopt='-DSYSC' --cxxopt='-DTF_LITE_DISABLE_X86_NEON' --cxxopt='-DACC_PROFILE' --define tflite_with_xnnpack=false --cxxopt='-DRUY_OPT_SET=0' --@secda_tools//:config=sysc ",
      "group": {
        "kind": "build",
        "isDefault": true
      }
    },
    {
      "label": "inference_diff_plus_vm_shift_delegate_v4",
      "type": "shell",
      "command": "bazel6 build tensorflow/lite/delegates/utils/secda_delegates/vm_shift_delegate/v4:inference_diff_plus_vm_shift_delegate -c dbg --cxxopt='-DSYSC' --cxxopt='-DTF_LITE_DISABLE_X86_NEON' --cxxopt='-DACC_PROFILE' --define tflite_with_xnnpack=false --cxxopt='-DRUY_OPT_SET=0' --@secda_tools//:config=sysc ",
      "group": {
        "kind": "build",
        "isDefault": true
      }
    },
      ```

3. Now if we run simulation for QKERAS quantization method using the vm_shift_delegate/v2 accelerator for 'inference_diff' application, we should get average error as 0.0. That means the accelerator is working correctly.

4. For vm_shift_delegate/v4 accelerator, we will not see average error as 0.0 since the synthetic models are int8 quantized.

### Hardware Automation

In this section, we will describe how to generate bitstream for both accelerators.

1. Copy `vm_shift_accelerator/hardware_automation/configs/VM/VMSHQKv2_0_Z2.json` to `<Path To SECDA-TFLite workspace>/hardware_automation/configs/VM/` for shift-based accelerator.

2. Copy `mm_accelerator/hardware_automation/configs/VM/VMSHQKMMv4_0_Z2.json` to `<Path To SECDA-TFLite workspace>/hardware_automation/configs/VM/` for MatMul accelerator.

3. Run hardware automation steps as described in SECDA-TFLite documentation to generate bitstream for both accelerators.

### Run on Hardware (Benchmark Suite)

1. Before running benchmark suite from Dev Container, make sure Pynq-Z2 board can be accessed via SSH.

2. Open the benchmark suite `<Path To SECDA-TFLite workspace>/src/benchmark_suite/secda_benchmarking_suite.ipynb` and select the appropriate accelerator, models from the GUI of the notebook.

## Paper

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

## Journal Paper Extension

- To be updated soon.
