## Download CIFAR-10 Test DATA

The CIFAR-10 data directory is organized as:

```text
data/cifar10/
	labels/
	models/
	testData/
	trainData/
```

- `labels/` contains the class label files used by the evaluation scripts.
- `models/` stores the CIFAR-10 model files.
- `testData/` is the test set used by `eval_model_accuracy` and related scripts.

## Download ImageNet Validation DATA

The ImageNet data directory is organized as:

```text
data/imagenet/
	labels/
	models/
	testData_10k_0/
	testData_10k_1/
	testData_10k_2/
	testData_10k_3/
	testData_10k_4/
```

- `labels/` contains the ImageNet label and ground-truth label files.
- `models/` stores the ImageNet model files.
- `testData_10k_0` to `testData_10k_4` are the ImageNet 10K test splits used by `imagenet_image_classification`.

We use the 50K ImageNet validation images as the base testData set, and the `testData_10k_*` folders provide smaller split sets for focused runs.

## How to Download and Prepare the data
    - Will be updated soon