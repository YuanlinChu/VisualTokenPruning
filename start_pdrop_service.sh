#!/bin/bash

# 启动 PyramidDrop 推理服务的完整脚本
# 按顺序启动：Controller -> Model Worker -> Gradio Web Server

echo "Starting PyramidDrop inference service..."

# 检查是否在正确的环境中
if ! command -v conda &> /dev/null; then
    echo "Conda not found. Please activate your conda environment manually."
    exit 1
fi

# 激活 conda 环境
echo "Activating conda environment..."
source ~/anaconda3/etc/profile.d/conda.sh
conda activate pdrop

# 验证环境
if [ "$CONDA_DEFAULT_ENV" != "pdrop" ]; then
    echo "Error: Failed to activate pdrop environment. Current env: $CONDA_DEFAULT_ENV"
    exit 1
fi
echo "Conda environment activated: $CONDA_DEFAULT_ENV"

# 设置模型路径
MODEL_PATH="/hpc2hdd/home/ychu763/Documents/PyramidDrop/download/llava-v1.5-13b"

# 检查模型路径是否存在
if [ ! -d "$MODEL_PATH" ]; then
    echo "Error: Model path $MODEL_PATH does not exist!"
    exit 1
fi

echo "Using model path: $MODEL_PATH"

# 停止可能存在的旧服务
echo "Stopping any existing services..."
pkill -f "controller.py" 2>/dev/null
pkill -f "model_worker.py" 2>/dev/null
pkill -f "gradio_web_server.py" 2>/dev/null
sleep 5

# 检查端口是否被占用
check_port() {
    local port=$1
    local service_name=$2
    if lsof -i :$port >/dev/null 2>&1; then
        echo "Error: Port $port is still in use by another process!"
        echo "Please check and kill the process using port $port"
        lsof -i :$port
        return 1
    fi
    return 0
}

echo "Checking if ports are available..."
if ! check_port 21001 "Controller"; then
    exit 1
fi
if ! check_port 21002 "Model Worker"; then
    exit 1
fi
if ! check_port 7860 "Gradio"; then
    exit 1
fi

# 1. 启动 Controller (端口 21001)
echo "Starting Controller on port 21001..."
python llava/serve/controller.py --host 0.0.0.0 --port 21001 > controller.log 2>&1 &
CONTROLLER_PID=$!
echo "Controller PID: $CONTROLLER_PID"

# 等待 Controller 启动，增加重试次数和等待时间
echo "Waiting for Controller to start..."
for i in {1..20}; do
    if curl -s http://localhost:21001/list_models >/dev/null 2>&1; then
        echo "Controller started successfully!"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "Error: Controller failed to start after 60 seconds!"
        echo "Controller log:"
        tail -20 controller.log
        kill $CONTROLLER_PID 2>/dev/null
        exit 1
    fi
    echo "Waiting for controller to start... ($i/20)"
    sleep 3
done

# 2. 启动 Model Worker with PyramidDrop (端口 21002)
echo "Starting Model Worker with PyramidDrop on port 21002..."
python llava/serve/model_worker.py \
    --host 0.0.0.0 \
    --port 21002 \
    --controller-address http://localhost:21001 \
    --worker-address http://localhost:21002 \
    --model-path "$MODEL_PATH" \
    --pdrop-infer \
    --layer-list "[8,16,24]" \
    --image-token-ratio-list "[0.5,0.25,0.125]" > model_worker.log 2>&1 &
WORKER_PID=$!
echo "Worker PID: $WORKER_PID"

# 等待模型加载（增加等待时间）
echo "Waiting for model to load (this may take 2-3 minutes for first run)..."
for i in {1..60}; do
    if curl -s http://localhost:21002/worker_get_status >/dev/null 2>&1; then
        echo "Model Worker is responding!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "Error: Model Worker failed to start after 5 minutes!"
        echo "Model Worker log:"
        tail -30 model_worker.log
        kill $CONTROLLER_PID $WORKER_PID 2>/dev/null
        exit 1
    fi
    echo "Waiting for worker to start... ($i/60)"
    sleep 5
done

# 等待模型完全加载
echo "Waiting for model to fully load..."
sleep 30

# 3. 启动 Gradio Web Server (端口 7860)
echo "Starting Gradio Web Server on port 7860..."
python llava/serve/gradio_web_server.py \
    --host 0.0.0.0 \
    --port 7860 \
    --controller-url http://localhost:21001 > gradio.log 2>&1 &
GRADIO_PID=$!
echo "Gradio PID: $GRADIO_PID"

# 等待 Gradio 启动
echo "Waiting for Gradio to start..."
for i in {1..20}; do
    if curl -s http://localhost:7860 >/dev/null 2>&1; then
        echo "Gradio Web Server started successfully!"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "Error: Gradio Web Server failed to start after 60 seconds!"
        echo "Gradio log:"
        tail -20 gradio.log
        kill $CONTROLLER_PID $WORKER_PID $GRADIO_PID 2>/dev/null
        exit 1
    fi
    echo "Waiting for gradio to start... ($i/20)"
    sleep 3
done

echo ""
echo "=========================================="
echo "All services started successfully!"
echo "=========================================="
echo "Controller PID: $CONTROLLER_PID (port 21001)"
echo "Worker PID: $WORKER_PID (port 21002)" 
echo "Gradio PID: $GRADIO_PID (port 7860)"
echo ""
echo "Access the web interface at:"
echo "  Local: http://localhost:7860"
echo "  Remote: http://$(hostname -I | awk '{print $1}'):7860"
echo ""
echo "PyramidDrop Configuration:"
echo "  Layer List: [8, 16, 24]"
echo "  Image Token Ratio: [1.0, 0.5, 0.25, 0.125]"
echo ""
echo "Log files:"
echo "  Controller: controller.log"
echo "  Model Worker: model_worker.log"
echo "  Gradio: gradio.log"
echo ""
echo "To stop all services, run:"
echo "  kill $CONTROLLER_PID $WORKER_PID $GRADIO_PID"
echo "  or press Ctrl+C"
echo ""

# 等待用户中断
trap 'echo ""; echo "Stopping all services..."; kill $CONTROLLER_PID $WORKER_PID $GRADIO_PID 2>/dev/null; echo "All services stopped."; exit 0' INT
wait 