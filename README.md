# dsh-platform

基于官方 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的第一期本地平台：不改 dsh 源码，只叠加模型路由和工作流 Skill。

## 第一期范围

- 默认模型：SiliconFlow `deepseek-ai/DeepSeek-V4-Flash`
- 能力：coding、代码总结、bug 查找修改、文档总结
- Ollama / vLLM：路由已写好，默认不使用。启用步骤见下文「接入 Ollama 或 vLLM」

同一模型族在 SiliconFlow 目录里还有 `deepseek-ai/DeepSeek-V4-Flash-0731` 和 `deepseek-ai/DeepSeek-V4.1-Flash`。第一期按指定 id 使用 `deepseek-ai/DeepSeek-V4-Flash`。

## 环境

- Node.js 22 或 24+（官方排除 Node 23）
- 能访问 npm
- SiliconFlow API Key

## 启动

```bash
cd /Users/haihuang.hh/PycharmProjects/dsh-platform
cp config/env.example .env
# 编辑 .env，填写 SILICONFLOW_API_KEY
chmod +x scripts/start.sh
./scripts/start.sh
```

浏览器打开 `http://127.0.0.1:3080`。启动脚本会把配置和 Skill 同步到项目内 `.dsh-home/`，不改你的 `~/.dsh`。

无界面跑一条任务（在目标代码目录执行）：

```bash
cd /path/to/your/repo
DSH_HOME=/Users/haihuang.hh/PycharmProjects/dsh-platform/.dsh-home \
  /Users/haihuang.hh/PycharmProjects/dsh-platform/scripts/start.sh \
  --profile headless "用 code-summarize 总结当前仓库核心模块"
```

## 四个 Skill

| Skill | 做什么 | 不做什么 |
|---|---|---|
| `coding` | 按需求改代码并自检 | 不扩 scope、不写密钥 |
| `code-summarize` | 总结结构、主路径、风险点 | 不改文件 |
| `bug-fix` | 取证 → 根因 → 最小修复 | 没有证据不改 |
| `doc-summarize` | 按原文提取结论和约束 | 不改原文、不补事实 |

在对话里直接说「用 bug-fix 查这个报错」即可。dsh 会从 `$DSH_HOME/skills` 发现这些 Skill。

## 模型路由

三条路由都走 dsh 的 `openai-completions`。改 `config/settings.yaml` 后重新执行 `./scripts/start.sh`。启动脚本会把该文件拷到 `$DSH_HOME/settings.yaml`；dsh 发现这份文件就会把它合并进当前 profile。对象按字段合并，`models` 这类数组整段替换，所以模型列表以这份 yaml 为准。

| Provider | 状态 | Endpoint | 环境变量 |
|---|---|---|---|
| `siliconflow` | 第一期默认 | `https://api.siliconflow.cn/v1` | `SILICONFLOW_API_KEY` |
| `ollama` | 已配置，模型 id 仍是占位 | `http://127.0.0.1:11434/v1` | `OLLAMA_API_KEY` |
| `vllm` | 已配置，模型 id 仍是占位 | `http://127.0.0.1:8000/v1` | `VLLM_API_KEY` |

当前 `scripts/start.sh` 在启动前仍检查 `SILICONFLOW_API_KEY`。只跑本地模型时，这个变量也必须非空，否则脚本直接退出。

## 接入 Ollama 或 vLLM

Ollama 和 vLLM 使用同一套写法：服务自己提供 OpenAI 兼容的 `/v1`，dsh 只记录地址、协议、模型 id 和凭据环境变量。仓库里的两条路由已经带上本地服务常用的兼容项，不要删：

```yaml
compat:
  supportsDeveloperRole: false
  maxTokensField: max_tokens
```

`supportsDeveloperRole: false` 让系统提示不用 `developer` 角色；`maxTokensField: max_tokens` 让输出上限走 `max_tokens`。dsh 认不出的地址会按 OpenAI 官方接口组请求，很多本地服务会拒绝那两种字段。

地址里的 `127.0.0.1` 指运行 `./scripts/start.sh` 的那台机器。服务在别的机器或端口上时，只改对应路由的 `baseURL`，并保留末尾的 `/v1`。

### 1. 向服务要真实模型 id

先确认服务已启动，再请求它自己的模型列表。返回 JSON 里 `data` 数组每个对象的 `id`，就是要写入配置的值，必须逐字相同。

Ollama：

```bash
curl -sS http://127.0.0.1:11434/v1/models
```

vLLM：

```bash
curl -sS http://127.0.0.1:8000/v1/models
```

Ollama 的 id 通常带标签，例如 `qwen3:8b`，不能写成不带标签的 `qwen3`。vLLM 的 id 是该进程实际加载的模型名。上面两个名字只说明 id 的样子；以你这次 `curl` 返回的 `id` 为准。

`placeholder/ollama-model` 和 `placeholder/vllm-model` 不是真实模型。不替换就发起请求时，服务会按未知模型拒绝。

### 2. 改 `config/settings.yaml`

把对应路由的 `models[].id` 换成上一步的 `id`，`name` 只影响界面显示。`contextWindow` 和 `maxTokens` 是 dsh 侧声明的上下文长度和单次输出上限，不会从服务自动读取。现有的 `32768` 和 `4096` 是占位，请改成该服务实际允许的值；输出上限不要大于服务配置的上下文长度。

要让新会话默认走这条路由，同时改文件底部的 `agent-default-model`。`provider` 填 `ollama` 或 `vllm`，`model` 填同一个真实 id。

Ollama 示例（id 请换成你的 `curl` 结果）：

```yaml
    ollama:
      displayName: Ollama
      apiKeyEnv: OLLAMA_API_KEY
      api: openai-completions
      baseURL: http://127.0.0.1:11434/v1
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: qwen3:8b
          name: Qwen3 8B
          contextWindow: 32768
          maxTokens: 4096

agent-default-model:
  provider: ollama
  model: qwen3:8b
```

vLLM 只改路由名、地址和 id：

```yaml
    vllm:
      displayName: vLLM
      apiKeyEnv: VLLM_API_KEY
      api: openai-completions
      baseURL: http://127.0.0.1:8000/v1
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: Qwen/Qwen3-4B-Instruct-2507
          name: Qwen3 4B Instruct
          contextWindow: 32768
          maxTokens: 4096

agent-default-model:
  provider: vllm
  model: Qwen/Qwen3-4B-Instruct-2507
```

同一份文件可以同时保留两条本地路由和 SiliconFlow。`models` 下可以写多个条目，每个 `id` 都要来自该服务的 `/v1/models`，且同一路由内不能重复。`agent-default-model` 只能指定一个默认模型。

### 3. 准备环境变量

`config/env.example` 里已经有两个占位。复制到项目根目录的 `.env` 后，保证要用的那一个非空。dsh 按 `apiKeyEnv` 读变量，空值会在请求时报 `MISSING_CREDENTIAL`。

```bash
OLLAMA_API_KEY=ollama
VLLM_API_KEY=vllm
```

服务不校验密钥时，任意非空字符串即可。vLLM 若启动时指定了 API Key，`VLLM_API_KEY` 必须与服务端一致。`./scripts/start.sh` 会 source 项目根目录的 `.env`。

### 4. 重新启动并新开一轮对话

```bash
./scripts/start.sh
```

浏览器打开 `http://127.0.0.1:3080`，新开会话。已经发过消息的会话会继续使用它自己记录的模型；要使用刚改的默认模型，请新开一轮。界面模型选择器里也能改当前选择，这个选择会成为之后新会话的默认模型；下次再执行 `./scripts/start.sh` 时，会用 `config/settings.yaml` 里的 `agent-default-model` 合并回去。

无界面任务同样走启动脚本，因此也会带上 `.env` 和这份路由：

```bash
cd /path/to/your/repo
DSH_HOME=/Users/haihuang.hh/PycharmProjects/dsh-platform/.dsh-home \
  /Users/haihuang.hh/PycharmProjects/dsh-platform/scripts/start.sh \
  --profile headless "用 code-summarize 总结当前仓库核心模块"
```

### 对不上时看这几处

- `curl` 连不上：服务没起来，或 `baseURL` 的主机、端口不是 dsh 进程所在机器上的地址。
- `MISSING_CREDENTIAL`：`OLLAMA_API_KEY` 或 `VLLM_API_KEY` 没进入启动脚本的环境。
- `UNKNOWN_MODEL`：选择的模型不在该路由的 `models` 列表里。
- 服务返回找不到模型：`models[].id` 和 `/v1/models` 的 `id` 不一致。
- 地址和密钥都对，但每个请求都被拒绝：确认路由上仍有上面的两行 `compat`。

## 目录

```text
config/settings.yaml   模型路由
config/env.example     环境变量模板
skills/*/SKILL.md      四个工作流
scripts/start.sh       同步配置并启动 dsh
.dsh-home/             运行时数据，不入库
```
