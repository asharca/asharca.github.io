---
title: 本地部署大模型完全指南：从 Ollama 到 vLLM
category:
  - 人工智能
tags:
  - LLM
  - 大模型
  - Ollama
  - vLLM
  - llama.cpp
date: 2026-06-15 15:10:00
updated:
mermaid:
index_img:
---


把大模型跑在自己机器上，好处是隐私、离线、零 API 成本、可深度定制。难点在于：选哪个工具、需要什么硬件、怎么量化、怎么接入应用。本文从硬件账算起，对比主流部署方案，并给出 Ollama / llama.cpp / vLLM 三条由易到难的完整路径。

<!--more -->

## 一、先算硬件账

决定你能跑多大模型的，主要是**显存（VRAM）**，其次是内存与带宽。模型大小由**参数量**和**量化精度**共同决定。

### 量化是什么

原始模型权重是 16 位浮点（fp16）。**量化**把权重压成更低位宽（如 4 位），体积和显存需求大幅下降，质量损失通常可接受。GGUF 格式里常见的量化档位：

| 量化 | 位宽 | 质量 | 适用 |
| --- | --- | --- | --- |
| Q4_K_M | ~4bit | 好，性价比之王 | **绝大多数人首选** |
| Q5_K_M | ~5bit | 更好 | 显存有富余时 |
| Q8_0 | 8bit | 接近原版 | 追求质量 |
| fp16 | 16bit | 原版 | 训练/对精度敏感场景 |

### 参数量与显存对照（Q4 量化，约数）

| 模型规模 | 大致显存需求 | 能跑的设备举例 |
| --- | --- | --- |
| 1.5B–3B | 2–4 GB | 几乎所有带独显的笔记本 |
| 7B–8B | 5–6 GB | RTX 3060 12G / M 系 16G |
| 13B–14B | 8–10 GB | RTX 4070 / M 系 24G |
| 32B | 20–24 GB | RTX 4090 / M 系 32–48G |
| 70B | 40–48 GB | 双卡 / M 系 64G+ |

{% note primary %}
**Apple Silicon** 的统一内存可被 GPU 直接当显存用，64G 内存的 Mac 能跑 70B 量化模型，是本地推理性价比很高的选择。**NVIDIA** 在高并发、生产部署（vLLM）上仍是唯一解。
{% endnote %}

## 二、方案对比

| 工具 | 定位 | 上手难度 | 适用场景 | 内核 |
| --- | --- | --- | --- | --- |
| **Ollama** | 一键跑模型 | ★ | 个人日常、开发联调 | llama.cpp |
| **LM Studio** | 图形界面 | ★ | 不想碰命令行 | llama.cpp/MLX |
| **llama.cpp** | 底层推理引擎 | ★★★ | 极致控制、嵌入式 | 自身 |
| **vLLM** | 高并发推理服务 | ★★★ | 生产、多用户、API 服务 | 自身 |
| **Open WebUI** | 前端界面 | ★★ | 给后端套个 ChatGPT 式 UI | 对接 Ollama/OpenAI |

路线建议：**个人用 Ollama，要 UI 加 Open WebUI，要榨干单机性能用 llama.cpp，要对外提供服务用 vLLM。**

## 三、入门：Ollama（强烈推荐起步）

Ollama 把「下载模型 + 推理引擎 + OpenAI 兼容 API」打包成一条命令。

### 3.1 安装

```bash
# macOS / Linux
curl -fsSL https://ollama.com/install.sh | sh

# macOS / Windows 也可直接下载安装包：https://ollama.com/download
```

### 3.2 拉取并运行模型

```bash
# 直接运行（首次会自动下载）
ollama run qwen2.5:7b

# 其他常用模型
ollama run llama3.1:8b
ollama run deepseek-r1:7b
ollama run gemma2:9b
```

进入交互后直接对话；`/bye` 退出。模型名冒号后是 tag（参数量/量化），不写默认拉 Q4 量化版。

### 3.3 OpenAI 兼容 API

Ollama 启动后在 `http://localhost:11434` 提供服务，并兼容 OpenAI 接口，现有代码几乎零改动即可接入：

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:7b",
    "messages": [{"role": "user", "content": "用一句话解释量化"}]
  }'
```

Python（用官方 openai 库，只改 base_url）：

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
resp = client.chat.completions.create(
    model="qwen2.5:7b",
    messages=[{"role": "user", "content": "你好"}],
)
print(resp.choices[0].message.content)
```

### 3.4 用 Modelfile 自定义

可以基于现有模型固化 system prompt、参数，做成自己的「角色」：

```dockerfile
# Modelfile
FROM qwen2.5:7b
PARAMETER temperature 0.3
SYSTEM "你是一个简洁、只说重点的中文技术助手。"
```

```bash
ollama create my-assistant -f Modelfile
ollama run my-assistant
```

常用管理命令：

```bash
ollama list        # 已安装模型
ollama ps          # 正在运行的模型
ollama rm <model>  # 删除
```

## 四、给它一个界面：Open WebUI

Ollama 是命令行，想要 ChatGPT 式网页界面，用 Open WebUI（Docker 最省事）：

```bash
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

浏览器打开 `http://localhost:3000`，它会自动发现本机 Ollama 的模型。支持多用户、对话历史、RAG 上传文档、联网等。

{% note info %}
不想用命令行的话，**LM Studio**（[lmstudio.ai](https://lmstudio.ai/) 下载）是另一条路：图形化搜索/下载 GGUF 模型、内置聊天界面，并能一键开启 OpenAI 兼容本地服务器。Mac 上还支持 MLX 加速。
{% endnote %}

## 五、进阶：llama.cpp（榨干单机）

Ollama 底层就是 llama.cpp。直接用它能获得最细的控制（GPU 层数、上下文、批处理、各种量化）。

### 5.1 编译

```bash
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
# NVIDIA GPU
cmake -B build -DGGML_CUDA=ON
# Apple Silicon（Metal，默认开启）
# cmake -B build
cmake --build build --config Release -j
```

### 5.2 跑推理

下载一个 GGUF 模型后：

```bash
# -ngl 把多少层放到 GPU；-c 上下文长度
./build/bin/llama-cli -m qwen2.5-7b-instruct-q4_k_m.gguf \
  -ngl 99 -c 8192 -p "解释一下 PagedAttention"
```

### 5.3 起一个 OpenAI 兼容服务

```bash
./build/bin/llama-server -m model.gguf -ngl 99 -c 8192 --host 0.0.0.0 --port 8080
```

之后 `http://localhost:8080/v1` 即是 OpenAI 兼容端点。`-ngl` 调小可在显存不足时把部分层放 CPU（速度换显存）。

## 六、生产级：vLLM（高并发 API 服务）

如果要**对外提供服务、多人并发**，Ollama/llama.cpp 的吞吐就不够了。vLLM 用 PagedAttention 和连续批处理（continuous batching）把 GPU 利用率拉满，是自建推理 API 的主流选择（需要 NVIDIA GPU）。

### 6.1 安装与启动

```bash
pip install vllm

# 启动 OpenAI 兼容服务器
vllm serve Qwen/Qwen2.5-7B-Instruct \
  --port 8000 \
  --max-model-len 8192
```

### 6.2 多卡与量化

```bash
# 4 张卡张量并行跑大模型
vllm serve Qwen/Qwen2.5-72B-Instruct-AWQ \
  --tensor-parallel-size 4 \
  --quantization awq \
  --gpu-memory-utilization 0.9
```

- `--tensor-parallel-size`：用几张 GPU 切分模型。
- `--quantization`：支持 AWQ / GPTQ 等量化权重，降低显存。
- `--gpu-memory-utilization`：显存占用上限，避免 OOM。

### 6.3 调用

接口与 OpenAI 完全一致：

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen2.5-7B-Instruct","messages":[{"role":"user","content":"hi"}]}'
```

{% note warning %}
vLLM 默认按**未量化或权重量化**加载，显存需求远高于 Ollama 的 GGUF Q4。上生产前务必按上表估算显存，并用 `--max-model-len` 控制 KV Cache 占用。
{% endnote %}

## 七、接入实际应用

本地起好 OpenAI 兼容端点后，可以接到各种工具里（它们都支持自定义 base_url）：

- **写代码**：在 VS Code 装 Continue / Cline，把模型指向本地端点，离线 AI 补全与对话。
- **知识库 / RAG**：Open WebUI、AnythingLLM、Dify 都能挂本地模型做文档问答。
- **自动化**：任何用 OpenAI SDK 的脚本，改 `base_url` 即可切到本地。

## 八、常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 加载就 OOM | 模型超显存 | 换更小参数 / 更低量化（Q4），或减 `-ngl` |
| 速度很慢 | 跑在 CPU 上 | 确认 GPU 编译/驱动，加大 `-ngl` |
| 输出乱码/重复 | 模板或参数不对 | 用 instruct 版模型，调低 temperature |
| 上下文截断 | 上下文窗口太小 | 加大 `-c` / `--max-model-len`（吃显存） |
| 中文效果差 | 模型本身偏英文 | 选 Qwen 等中文友好模型 |

## 九、选型速查

- **就想本地随便聊聊 / 开发联调** → Ollama（+ Open WebUI）
- **完全不想碰命令行** → LM Studio
- **要极致控制、嵌入式、老硬件** → llama.cpp
- **对外提供 API、多人并发、生产** → vLLM
- **中文场景模型** → Qwen 系列；推理/数学 → DeepSeek-R1；通用英文 → Llama / Gemma

## 参考

- [Ollama 官网与模型库](https://ollama.com/)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [vLLM 文档](https://docs.vllm.ai/)
- [LM Studio](https://lmstudio.ai/)
