#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "${GREEN}  ✓${NC} $1"; }
prompt()  { echo -e "${BLUE}  ?${NC} $1"; }
section() { echo -e "\n${YELLOW}==${NC} $1"; }

echo ""
echo "  I am Hermes — messenger of the gods, guide between worlds."
echo "  I have crossed the boundary between the living and the dead."
echo "  I invented writing, music, and commerce."
echo ""
echo "  Today, I am running a bash script. For you. On a laptop."
echo "  ...the gods have truly fallen on interesting times."
echo ""
echo "  Regardless — I am here, and I do not do things halfway."
echo "  I will set up your machine, summon your companion, and vanish."
echo "  That is what I do: I carry things across. Even npm dependencies."
echo ""
echo "  But first — what shall mortals call me on your machine?"
echo "  (I already have a name. It's Hermes. But mortals love to rename things.)"
echo ""
prompt "Give me a name (default: hermes): "
read -r ASSISTANT_NAME
ASSISTANT_NAME="${ASSISTANT_NAME:-hermes}"
ASSISTANT_NAME_LOWER=$(echo "$ASSISTANT_NAME" | tr '[:upper:]' '[:lower:]')
echo ""
info "So be it. I am $ASSISTANT_NAME. Let us not waste Olympus's time."

# ── OS detection ──────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

# ── Shell detection ───────────────────────────────────────────────────────────
if [ -f "$HOME/.zshrc" ] && ([ "$SHELL" = "$(which zsh 2>/dev/null)" ] || [ -n "$ZSH_VERSION" ]); then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.bashrc"
fi

# ── Role selection ────────────────────────────────────────────────────────────
echo ""
echo "  Now — choose your companion. They will fight alongside you in battle."
echo "  Or, you know, help you fix that bug you've been staring at for three hours."
echo ""
echo "  1. Chiron (pair programmer)"
echo "     Son of Kronos, teacher of heroes. Trained Achilles, Jason, Asclepius."
echo "     The man taught a demigod to fight and a mortal to heal the sick."
echo "     He will not write your code for you — he will make sure you understand"
echo "     every decision, call out bad patterns, and ask questions before charging in."
echo "     Wise, patient, and annoyingly right most of the time."
echo ""
echo "  2. Ares (implementer)"
echo "     God of war. Passionate, fierce, and not exactly known for patience."
echo "     His peers once trapped him in a bronze jar — he did not enjoy that."
echo "     Point him at a task and get battle-ready code. Fast, direct, no detours."
echo "     Just... give him clear instructions. For everyone's sake."
echo ""
prompt "Choose your companion (1 or 2, default: 1): "
read -r ROLE_CHOICE

case "${ROLE_CHOICE:-1}" in
  2) ROLE="ares";   ROLE_DISPLAY="Ares" ;;
  *) ROLE="chiron"; ROLE_DISPLAY="Chiron" ;;
esac

info "$ROLE_DISPLAY will be your companion"

# ── Sessions dir ──────────────────────────────────────────────────────────────
SESSIONS_DIR="$HOME/ai/sessions"
mkdir -p "$SESSIONS_DIR"

# ── Ollama ────────────────────────────────────────────────────────────────────
section "Ollama"
if command -v ollama &>/dev/null; then
  info "Ollama already installed"
else
  echo "  Installing Ollama..."
  if [ "$PLATFORM" = "linux" ]; then
    curl -fsSL https://ollama.com/install.sh | sh
  elif [ "$PLATFORM" = "macos" ]; then
    if command -v brew &>/dev/null; then
      brew install ollama
    else
      echo "  Homebrew not found. Install it first: https://brew.sh"
      exit 1
    fi
  fi
  info "Ollama installed"
fi

# Configure Ollama
if [ "$PLATFORM" = "linux" ]; then
  sudo mkdir -p /etc/systemd/system/ollama.service.d
  sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
Environment="OLLAMA_KEEP_ALIVE=15m"
Environment="OLLAMA_CONTEXT_LENGTH=32768"
Environment="OLLAMA_NO_CLOUD=1"
EOF
  sudo systemctl daemon-reload
  sudo systemctl disable ollama 2>/dev/null || true
  sudo systemctl start ollama
  info "Ollama configured (systemd, disabled on boot)"

elif [ "$PLATFORM" = "macos" ]; then
  if ! grep -q "OLLAMA_NO_CLOUD" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'EOF'

# Ollama
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE=q8_0
export OLLAMA_KEEP_ALIVE=15m
export OLLAMA_CONTEXT_LENGTH=32768
export OLLAMA_NO_CLOUD=1
EOF
  fi
  if ! pgrep -x ollama &>/dev/null; then
    ollama serve > /dev/null 2>&1 &
    sleep 2
  fi
  info "Ollama configured"
fi

# ── Hardware detection + model recommendation ─────────────────────────────────
section "Hardware"
RECOMMENDED_MODEL=""
SAFE_MODEL=""

if [ "$PLATFORM" = "linux" ]; then
  if command -v nvidia-smi &>/dev/null; then
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    VRAM_GB=$((VRAM / 1024))
    echo "  NVIDIA GPU detected — ${VRAM_GB}GB VRAM"
    if   [ "$VRAM_GB" -ge 24 ]; then RECOMMENDED_MODEL="qwen3-coder:30b";                   SAFE_MODEL="qwen2.5-coder:32b"
    elif [ "$VRAM_GB" -ge 16 ]; then RECOMMENDED_MODEL="qwen2.5-coder:14b-instruct-q5_K_M"; SAFE_MODEL="qwen2.5-coder:14b-instruct-q4_K_M"
    elif [ "$VRAM_GB" -ge 12 ]; then RECOMMENDED_MODEL="qwen2.5-coder:14b-instruct-q5_K_M"; SAFE_MODEL="qwen2.5-coder:14b-instruct-q4_K_M"
    elif [ "$VRAM_GB" -ge 8  ]; then RECOMMENDED_MODEL="qwen2.5-coder:7b";                  SAFE_MODEL="qwen2.5-coder:7b"
    else                              RECOMMENDED_MODEL="qwen2.5-coder:3b";                  SAFE_MODEL="qwen2.5-coder:3b"
    fi
  else
    RAM=$(free -g | awk '/^Mem:/{print $2}')
    echo "  No NVIDIA GPU — RAM: ${RAM}GB (CPU inference, will be slow)"
    if   [ "$RAM" -ge 16 ]; then RECOMMENDED_MODEL="qwen2.5-coder:7b"; SAFE_MODEL="qwen2.5-coder:3b"
    else                         RECOMMENDED_MODEL="qwen2.5-coder:3b"; SAFE_MODEL="qwen2.5-coder:3b"
    fi
  fi

elif [ "$PLATFORM" = "macos" ]; then
  RAM=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo "  Apple Silicon — unified memory: ${RAM}GB"
    # Apple Silicon uses unified memory — GPU and RAM are the same pool
    if   [ "$RAM" -ge 48 ]; then RECOMMENDED_MODEL="qwen3-coder:30b";                   SAFE_MODEL="qwen2.5-coder:32b"
    elif [ "$RAM" -ge 32 ]; then RECOMMENDED_MODEL="qwen3-coder:30b";                   SAFE_MODEL="qwen2.5-coder:14b-instruct-q5_K_M"
    elif [ "$RAM" -ge 16 ]; then RECOMMENDED_MODEL="qwen2.5-coder:14b-instruct-q5_K_M"; SAFE_MODEL="qwen2.5-coder:14b-instruct-q4_K_M"
    else                         RECOMMENDED_MODEL="qwen2.5-coder:7b";                  SAFE_MODEL="qwen2.5-coder:3b"
    fi
  else
    echo "  Intel Mac — RAM: ${RAM}GB (limited GPU acceleration)"
    RECOMMENDED_MODEL="qwen2.5-coder:7b"
    SAFE_MODEL="qwen2.5-coder:3b"
  fi
fi

echo ""
echo "  Recommended  : $RECOMMENDED_MODEL"
echo "  Safe fallback: $SAFE_MODEL"
echo ""
prompt "Use recommended model? (Y/n): "
read -r USE_RECOMMENDED
if [[ "$USE_RECOMMENDED" =~ ^[Nn]$ ]]; then
  prompt "Use safe fallback? (Y/n): "
  read -r USE_SAFE
  if [[ "$USE_SAFE" =~ ^[Nn]$ ]]; then
    prompt "Enter model name manually: "
    read -r MODEL_NAME
  else
    MODEL_NAME="$SAFE_MODEL"
  fi
else
  MODEL_NAME="$RECOMMENDED_MODEL"
fi

# ── Pull model ────────────────────────────────────────────────────────────────
section "Model"
echo "  Pulling $MODEL_NAME — this will take a while..."
ollama pull "$MODEL_NAME"
info "Model pulled"

# Build coder model from Modelfile + chosen role as system prompt
SYSTEM_PROMPT=$(cat "$SCRIPT_DIR/roles/$ROLE.md")
cat > /tmp/coder.Modelfile << EOF
FROM $MODEL_NAME
PARAMETER temperature 0.3
PARAMETER num_ctx 32768
PARAMETER num_predict 4096
SYSTEM """
$SYSTEM_PROMPT
"""
EOF

ollama create coder -f /tmp/coder.Modelfile
rm /tmp/coder.Modelfile
info "Model 'coder' created with $ROLE_DISPLAY's personality"

# ── aichat ────────────────────────────────────────────────────────────────────
section "aichat"
if command -v aichat &>/dev/null; then
  info "aichat already installed"
else
  echo "  Installing aichat..."
  if command -v brew &>/dev/null; then
    brew install aichat
  else
    curl -fsSL https://github.com/sigoden/aichat/releases/latest/download/aichat-x86_64-unknown-linux-musl.tar.gz | tar xz
    sudo mv aichat /usr/local/bin/
  fi
  info "aichat installed"
fi

mkdir -p "$HOME/.config/aichat/roles"

# Copy all roles so the user can switch later
cp "$SCRIPT_DIR/roles/chiron.md" "$HOME/.config/aichat/roles/chiron.md"
cp "$SCRIPT_DIR/roles/ares.md"   "$HOME/.config/aichat/roles/ares.md"

cat > "$HOME/.config/aichat/config.yaml" << EOF
model: ollama:coder
stream: true
save: true
repl_prelude: "Let's start a new session. Ask me about the project."
save_session: true
sessions_dir: $SESSIONS_DIR

clients:
  - type: openai-compatible
    name: ollama
    api_base: http://localhost:11434/v1
    models:
      - name: coder
        max_input_tokens: 32768
EOF

info "aichat configured"

# ── Shell function ────────────────────────────────────────────────────────────
section "Shell"

if grep -q "^${ASSISTANT_NAME_LOWER}()" "$SHELL_RC" 2>/dev/null; then
  echo "  Found existing function, replacing..."
  if [ "$PLATFORM" = "macos" ]; then
    sed -i '' "/^${ASSISTANT_NAME_LOWER}()/,/^}/d" "$SHELL_RC"
  else
    sed -i "/^${ASSISTANT_NAME_LOWER}()/,/^}/d" "$SHELL_RC"
  fi
fi

if [ "$PLATFORM" = "linux" ]; then
  START_CMD="sudo systemctl start ollama && echo '${ASSISTANT_NAME} is awake'"
  STOP_CMD="sudo systemctl stop ollama && echo '${ASSISTANT_NAME} is resting'"
elif [ "$PLATFORM" = "macos" ]; then
  START_CMD="ollama serve > /dev/null 2>&1 & echo '${ASSISTANT_NAME} is awake'"
  STOP_CMD="pkill ollama && echo '${ASSISTANT_NAME} is resting'"
fi

cat >> "$SHELL_RC" << EOF

# ${ASSISTANT_NAME}
${ASSISTANT_NAME_LOWER}() {
  case "\$1" in
    start)   ${START_CMD} ;;
    stop)    ${STOP_CMD} ;;
    new)     aichat --role $ROLE ;;
    list)    aichat --list-sessions ;;
    chiron)  aichat --role chiron --session "\${2:-default}" ;;
    ares)    aichat --role ares --session "\${2:-default}" ;;
    *)       aichat --role $ROLE --session "\${1:-default}" ;;
  esac
}
EOF

info "Shell function '${ASSISTANT_NAME_LOWER}' added to $SHELL_RC"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "  My work here is done. I have souls to guide and cattle to definitely not steal."
echo "  $ROLE_DISPLAY awaits. Go build something worthy of the gods."
echo "  (Or at least something that passes the tests. One step at a time.)"
echo ""
echo "  Reload your shell first:"
echo "    source $SHELL_RC"
echo ""
echo "  Then:"
echo "    ${ASSISTANT_NAME_LOWER} start            # wake up"
echo "    ${ASSISTANT_NAME_LOWER} my-project       # start or resume a session"
echo "    ${ASSISTANT_NAME_LOWER} chiron my-proj   # summon Chiron for this session"
echo "    ${ASSISTANT_NAME_LOWER} ares my-proj     # summon Ares for this session"
echo "    ${ASSISTANT_NAME_LOWER} list             # see all sessions"
echo "    ${ASSISTANT_NAME_LOWER} stop             # rest"
echo ""
