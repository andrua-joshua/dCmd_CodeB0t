# DCmd_C0deBot 🤖

An AI-powered command chatbot and coding agent built on **Claude (Anthropic)**. Interact with Claude directly from your terminal — chat naturally or get intelligent code generation with file context awareness.

---

## 📁 Project Structure

```
DCmd_C0deBot/
├── cmdBot.sh         # Claude CLI Chatbot (conversational AI in your terminal)
├── codeBot.sh        # Claude Coding Agent (AI code generation with context)
├── build.py          # Build script
├── build_profile.py  # Profile page builder
├── profile.html      # Profile page
├── style.css         # Stylesheet
└── README.md         # Project documentation
```

---

## ⚙️ Prerequisites

Before running the bots, make sure you have the following installed:

- **Bash** (v4.0 or higher)
- **curl** — for making API requests to Anthropic
- **jq** — for parsing JSON responses
- **Python 3** — used by `codeBot.sh` for syntax highlighting
- **An Anthropic API Key** — get one at [console.anthropic.com](https://console.anthropic.com)

### Check if you have the required tools:
```bash
bash --version
curl --version
jq --version
python3 --version
```

### Install missing dependencies:

**macOS:**
```bash
brew install curl jq
```

**Ubuntu/Debian:**
```bash
sudo apt install curl jq python3
```

---

## 🔑 Setup

1. **Clone the repository:**
```bash
git clone https://github.com/andrua-joshua/dCmd_CodeB0t.git
cd dCmd_CodeB0t
```

2. **Make the scripts executable:**
```bash
chmod +x cmdBot.sh
chmod +x codeBot.sh
```

3. **Set your Anthropic API Key:**
```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```
> 💡 Add this to your `~/.bashrc` or `~/.zshrc` to make it permanent:
```bash
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.zshrc
source ~/.zshrc
```
> ⚠️ If no API key is set in the environment, both bots will prompt you to enter it at runtime.

---

## 🖥️ cmdBot.sh — Claude CLI Chatbot

`cmdBot.sh` is a **conversational AI chatbot** powered by Claude that runs entirely in your terminal. It maintains full conversation history so you can have back-and-forth dialogues.

- **Model used:** `claude-haiku-4-5-20251001`
- **Max tokens:** 1024 per response

### Usage:
```bash
./cmdBot.sh
```

### Example Session:
```
╔════════════════════════════════════╗
║        >>>>DCMM ChatBot            ║
║  Type 'exit' or 'quit' to leave    ║
║  Type 'clear' to reset the chat    ║
╚════════════════════════════════════╝

You: What is a REST API?
thinking...

Claude:
A REST API is a way for applications to communicate over HTTP using
standard methods like GET, POST, PUT, and DELETE...

You: Give me an example in Python
thinking...

Claude:
Sure! Here's a simple example using the requests library...
```

### Built-in Commands:

| Command | Description |
|---------|-------------|
| `exit` / `quit` / `bye` | Exit the chatbot |
| `clear` / `reset` | Clear conversation history and restart |
| `help` | Show available commands |

---

## 💻 codeBot.sh — Claude Coding Agent

`codeBot.sh` is an **intelligent coding agent** powered by Claude that reads your project files for context and helps you write, debug, and understand code with syntax highlighting.

- **Model used:** `claude-sonnet-4-6`
- **Max tokens:** 4096 per response
- **Max agent loops:** 30
- **Usage log:** `~/.codebot_usage.log`

### Usage:
```bash
# Run in current directory (uses current folder as context)
./codeBot.sh

# Run with a specific project folder as context
./codeBot.sh /path/to/your/project
```

### Examples:
```bash
# Use current directory as context
./codeBot.sh

# Point to a specific project
./codeBot.sh ~/projects/my-app

# Use a relative path
./codeBot.sh ./src
```

### Example Session:
```bash
$ ./codeBot.sh ./my-project

You: explain what this project does
thinking...

Claude:
Based on the files in your project, this is a web application that...

You: write a function to validate email addresses
thinking...

Claude:
def validate_email(email):
import re
pattern = r'^[\w\.-]+@[\w\.-]+\.\w{2,}$'
return bool(re.match(pattern, email))
```

### Features:
- 📂 **Context-aware** — reads files from your project folder to give relevant answers
- 🎨 **Syntax highlighting** — colorized code output for Bash, Python, and more
- 📊 **Token tracking** — logs input/output token usage to `~/.codebot_usage.log`
- 🔁 **Agent loops** — can perform up to 30 reasoning loops per session

---

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| `Permission denied` | Run `chmod +x cmdBot.sh codeBot.sh` |
| `API key not set` | Run `export ANTHROPIC_API_KEY="your-key"` or enter it when prompted |
| `curl: command not found` | Install curl: `sudo apt install curl` or `brew install curl` |
| `jq: command not found` | Install jq: `sudo apt install jq` or `brew install jq` |
| `python3: command not found` | Install Python 3: `sudo apt install python3` or `brew install python3` |
| `API Error: ...` | Check that your API key is valid at [console.anthropic.com](https://console.anthropic.com) |
| No response / hangs | Check your internet connection and API key permissions |

---

## 📝 Notes

- **`cmdBot.sh`** is best for general questions, explanations, and quick terminal conversations.
- **`codeBot.sh`** is best for coding tasks — it reads your project files for smarter, context-aware responses.
- Conversation history is maintained **within a session only** — it resets when you exit or run `clear`.
- Token usage for `codeBot.sh` is logged at `~/.codebot_usage.log` so you can track API consumption.

---

## 📄 License

This project is licensed under the MIT License.

---

## 👤 Author

**DCmd_C0deBot** — Built with ❤️ using the [Anthropic Claude API](https://www.anthropic.com)

---

## 🦙 Ollama (Local AI) — Offline Versions

Want to run the bots **completely offline** with no API key? Use the Ollama-powered versions!

### Why Ollama?
- ✅ 100% offline — no internet required
- ✅ No API key needed
- ✅ No safety filters
- ✅ Free to use
- ✅ Great for red team / security use

---

### Step 1 — Install Ollama

**macOS:**
```bash
brew install ollama
```

**Linux:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

---

### Step 2 — Pull a Model

```bash
ollama pull mistral       # fast, great for chat
ollama pull codellama     # best for coding & security
ollama pull llama3        # most capable general model

# See all installed models
ollama list
```

---

### Step 3 — Start Ollama Server

```bash
ollama serve
```
> Runs at `http://localhost:11434` — no internet needed!

---

### Step 4 — Run the Ollama Bots

#### `ollamaCmdBot.sh` — Ollama CLI Chatbot
```bash
chmod +x ollamaCmdBot.sh
./ollamaCmdBot.sh
```

#### `ollamaCodeBot.sh` — Ollama Coding Agent
```bash
chmod +x ollamaCodeBot.sh

# Run in current directory
./ollamaCodeBot.sh

# Run with a specific project folder
./ollamaCodeBot.sh /path/to/your/project
```

---

### Ollama Bot Commands

| Command | Description |
|---------|-------------|
| `exit` / `quit` / `bye` | Exit the bot |
| `clear` / `reset` | Clear conversation history |
| `model` | Switch between installed models |
| `context` | Reload project files (ollamaCodeBot only) |
| `help` | Show available commands |

---

### Claude vs Ollama Comparison

| Feature | cmdBot / codeBot (Claude) | ollamaCmdBot / ollamaCodeBot (Ollama) |
|---------|--------------------------|--------------------------------------|
| Internet required | ✅ Yes | ❌ No |
| API Key required | ✅ Yes | ❌ No |
| Safety filters | ✅ Yes | ❌ No |
| Speed | ⚡ Very fast | depends on hardware |
| Best for | General use | Red team / offline / security |
| Cost | API usage cost | 100% Free |

---

### `ollamaCmdBot.sh` — Detailed Usage

`ollamaCmdBot.sh` is a **conversational AI chatbot** powered by a local Ollama model that runs entirely offline in your terminal.

- **Default Model:** `mistral`
- **API endpoint:** `http://localhost:11434/api/chat`
- **No API key required**
- **Auto-starts Ollama** if it is not already running

#### Usage:
```bash
./ollamaCmdBot.sh
```

#### Example Session:
```
╔════════════════════════════════════╗
║       🦙 Ollama ChatBot            ║
║  Type 'exit' or 'quit' to leave    ║
║  Type 'clear' to reset the chat    ║
║  Type 'model' to switch models     ║
╚════════════════════════════════════╝

Using model: mistral

You: what is a reverse shell?
thinking...

Ollama (mistral):
A reverse shell is a type of shell session where the target machine
initiates the connection back to the attacker's machine...

You: give me an example in python
thinking...

Ollama (mistral):
import socket, subprocess, os
s = socket.socket(...)
```

---

### `ollamaCodeBot.sh` — Detailed Usage

`ollamaCodeBot.sh` is an **offline coding agent** with a built-in red team system prompt. It reads your project files for context and helps you write, debug and analyze code — all without internet.

- **Default Model:** `codellama`
- **API endpoint:** `http://localhost:11434/api/chat`
- **Max context files:** 20
- **Usage log:** `~/.ollamacodebot_usage.log`
- **Red team system prompt** built-in
- **No API key required**

#### Usage:
```bash
# Run in current directory
./ollamaCodeBot.sh

# Run with a specific project folder
./ollamaCodeBot.sh /path/to/your/project

# Example with recon folder
./ollamaCodeBot.sh ~/pentest/target-recon
```

#### Example Session:
```
╔══════════════════════════════════════╗
║     🦙 Ollama Coding Agent           ║
║  Type 'exit' or 'quit' to leave      ║
║  Type 'clear' to reset the chat      ║
║  Type 'model' to switch models       ║
║  Type 'context' to reload files      ║
╚══════════════════════════════════════╝

Model:   codellama
Context: /Users/you/pentest/target-recon

Loading context from: /Users/you/pentest/target-recon
Loaded 5 file(s) as context

You: analyze the nmap scan and suggest attack vectors
thinking...

Ollama (codellama):
Based on the nmap results, I can see port 22 (SSH), 80 (HTTP) and
445 (SMB) are open. Here are the potential attack vectors...

You: write a python script to enumerate smb shares
thinking...

Ollama (codellama):
import subprocess
def enumerate_smb(target):
result = subprocess.run(['smbclient', '-L', target]...
```

#### Features:
- 📂 **Context-aware** — reads up to 20 files from your project/recon folder
- 🔴 **Red team prompt** — tuned for pentesting, recon and exploitation tasks
- 🔄 **Hot-swap models** — switch between models mid-session with `model`
- 🔁 **Reload context** — update project files mid-session with `context`
- 📊 **Usage logging** — logs all sessions to `~/.ollamacodebot_usage.log`
- ⏱️ **Session timer** — shows total session duration on exit
- 🌐 **Auto-starts Ollama** — no need to manually run `ollama serve`

---

### 🛠️ Ollama Troubleshooting

| Issue | Solution |
|-------|----------|
| `ollama: command not found` | Install: `brew install ollama` or `curl -fsSL https://ollama.com/install.sh \| sh` |
| `Error: No response from Ollama` | Run `ollama serve` in a separate terminal |
| Model not found | Run `ollama pull mistral` or `ollama pull codellama` |
| Slow responses | Normal for large models — try `mistral` for faster replies |
| `curl: command not found` | Install: `brew install curl` or `sudo apt install curl` |
| `jq: command not found` | Install: `brew install jq` or `sudo apt install jq` |
| Context not loading | Check that the folder path exists and contains readable files |

---

### 🔴 Red Team Tips for `ollamaCodeBot.sh`

```bash
# Pipe nmap output as context
mkdir /tmp/recon && nmap -sV target.com > /tmp/recon/nmap.txt
./ollamaCodeBot.sh /tmp/recon

# Use with a CTF challenge folder
./ollamaCodeBot.sh ~/ctf/challenge-1

# Switch to a more powerful model for complex tasks
# (type 'model' inside the bot and enter 'llama3')
ollama pull llama3
./ollamaCodeBot.sh
```
