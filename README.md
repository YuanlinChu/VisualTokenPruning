# VisualTokenDrop: Accelerating Vision-Language Models via Visual Redundancy Reduction

## 🔧 Install

1. Install Package
```Shell
conda create -n pdrop python=3.10 -y
conda activate pdrop
pip install --upgrade pip  # enable PEP 660 support
pip install -e .
```

2. Install additional packages
```Shell
pip install flash-attn --no-build-isolation
```

## ⭐️ Quick Start
```Shell
conda activate pdrop && python llava/serve/controller.py --host 0.0.0.0 --port 21001

conda activate pdrop && python llava/serve/model_worker.py --host 0.0.0.0 --port 21002 --controller-address http://localhost:21001 --worker-address http://localhost:21002 --model-path /hpc2hdd/home/ychu763/Documents/PyramidDrop/download/llava-v1.5-13b --pdrop-infer --layer-list "[8,16,24]" --image-token-ratio-list "[0.5,0.25,0.125]"

conda activate pdrop && python llava/serve/gradio_web_server.py --host 0.0.0.0 --port 7860 --controller-url http://localhost:21001
```

When not using this policy, use this command instead
```Shell
conda activate pdrop && python llava/serve/model_worker.py --host 0.0.0.0 --port 21002 --controller-address http://localhost:21001 --worker-address http://localhost:21002 --model-path /hpc2hdd/home/ychu763/Documents/PyramidDrop/download/llava-v1.5-13b
```

## ❤️ Acknowledgments

- [LLaVA](https://github.com/haotian-liu/LLaVA): the codebase we built upon. Thanks for their brilliant contributions to the community.
- [Open-LLaVA-NeXT](https://github.com/xiaoachen98/Open-LLaVA-NeXT): Thanks for the impressive open-source implementation of LLaVA-NeXT series.
- [PyramidDrop](https://github.com/Cooperx521/PyramidDrop): Thanks for the impressive open-source implementation of Dynamic token pruning strategy.
- [VLMEvalKit](https://github.com/open-compass/VLMEvalKit): the amazing open-sourced suit for evaluating various LMMs!
