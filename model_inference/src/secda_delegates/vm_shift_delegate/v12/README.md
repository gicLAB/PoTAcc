-- copied from vm_shift_delegate --> v2 --> v6 --> v7-->v9--v11-->v12

v12
-- add the fc support in the delegate
-- Enable DMA Weight Preload for FC layer.
-- Transformer based model support (ViT, DeiT, etc.)(_small,_tiny)

v11:
-- Changing the PE Design
-- optimized for KRIA by utilizing the KIRA URAM bandwidth.
-- V11 is not updated for depth tile yet. -- needs to be updated.

v9:
-- we are adding DMA weight preloading optimization.
-- removing DMA buffer piplining in the driver
-- weight copy optimization.
-- converting to shift accelerator
