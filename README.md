# Hermes — local AI coding companion

A fully offline AI coding assistant running on your machine via Ollama and aichat. No cloud, no tokens, persistent sessions.

## Requirements

- [Homebrew](https://brew.sh) — required on macOS, optional on Linux
- NVIDIA GPU recommended on Linux (see hardware notes below)

## Install

```bash
git clone <repo-url> ~/ai/hermes
cd ~/ai/hermes
chmod +x setup.sh
./setup.sh
```

The script will:
- Install and configure Ollama
- Detect your hardware and recommend the best model
- Ask which companion you want (Chiron or Ares)
- Pull the model and set everything up
- Add a shell function with your chosen assistant name

Reload your shell after setup:
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Companions

### Chiron (pair programmer)
The wisest centaur in Greece. Won't just write your code — he'll make sure you understand every decision. Asks before acting, guides your thinking, and calls out bad patterns before they haunt you.

### Ares (implementer)
God of war. No philosophy, no hand-holding. You point, he conquers. Give him a task and get battle-ready code. Fast, direct, unstoppable.

You can switch companions per session regardless of your default:
```bash
hermes chiron my-project   # force Chiron for this session
hermes ares my-project     # force Ares for this session
```

## Usage

```bash
hermes start            # wake up
hermes my-project       # start or resume a session (uses your default companion)
hermes new              # fresh unnamed session
hermes list             # see all saved sessions
hermes stop             # rest
```

Sessions are saved to `~/ai/sessions/` and resume automatically with full history.

## Customization

**Edit a companion's personality** — edit `roles/chiron.md` or `roles/ares.md`, then re-run setup or manually copy:
```bash
cp roles/chiron.md ~/.config/aichat/roles/chiron.md
```

**Switch model** — re-run `./setup.sh`. It will detect your hardware and let you pick again.

## Hardware & model selection

The script auto-detects your hardware and recommends the best model. Here's the logic:

| Hardware | Recommended | Safe fallback |
|---|---|---|
| NVIDIA 24GB+ VRAM | `qwen3-coder:30b` | `qwen2.5-coder:32b` |
| NVIDIA 12–16GB VRAM | `qwen2.5-coder:14b-instruct-q5_K_M` | `q4_K_M` |
| NVIDIA 8GB VRAM | `qwen2.5-coder:7b` | `qwen2.5-coder:7b` |
| NVIDIA <8GB VRAM | `qwen2.5-coder:3b` | `qwen2.5-coder:3b` |
| Apple Silicon 48GB+ | `qwen3-coder:30b` | `qwen2.5-coder:32b` |
| Apple Silicon 32GB | `qwen3-coder:30b` | `qwen2.5-coder:14b-instruct-q5_K_M` |
| Apple Silicon 16GB | `qwen2.5-coder:14b-instruct-q5_K_M` | `q4_K_M` |
| Apple Silicon 8GB | `qwen2.5-coder:7b` | `qwen2.5-coder:3b` |
| Intel Mac / no GPU | `qwen2.5-coder:7b` | `qwen2.5-coder:3b` |

**Why these models:**
- `qwen3-coder:30b` — best open-source coding model as of 2025 (70.6% SWE-Bench), 256K context, fits in ~19GB
- `qwen2.5-coder:14b` — best-in-class for 8–16GB VRAM, battle-tested, fast
- `qwen2.5-coder:7b` — reliable choice for tighter hardware, still very capable

**Apple Silicon note:** Ollama uses Metal natively on M-series chips. Unified memory means your RAM is your VRAM — a 48GB M4 handles 30B models easily.

## Storage

| What | Path |
|---|---|
| Models | `~/.ollama/models/` (~10–20GB per model) |
| Sessions | `~/ai/sessions/` |
| aichat config | `~/.config/aichat/` |

```bash
ollama rm <model-name>   # free up space
ollama list              # see what's downloaded
```
