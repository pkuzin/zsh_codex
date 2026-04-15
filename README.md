# 🐑 Zsh Ollama AI

Pure Zsh plugin for Ollama-powered command hints. No Python, no dependencies — just `curl` and `jq`.

Based on [zsh_codex](https://github.com/tom-doerr/zsh_codex) by Tom Dörr. Completely rewritten for local Ollama.

## Install

```bash
# Ollama required
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5-coder:3b

# Plugin
git clone https://github.com/YOURNAME/zsh_ollama_ai.git \
  ~/.oh-my-zsh/custom/plugins/zsh_ollama_ai
```

Add to `~/.zshrc`:
```zsh
plugins=(zsh_ollama_ai)
```

## Usage

- `Ctrl+X` — toggle AI mode on/off (shown in RPROMPT)
- `Ctrl+O` — get AI hint for current command

## Config

Optional: `~/.config/zsh_codex.ini`
```ini
[ollama]
model=qwen2.5-coder:3b
host=http://localhost:11434
```

## Requirements

- Zsh
- [Ollama](https://ollama.com)
- `curl`, `jq`

## License

MIT - see [LICENSE](LICENSE)
