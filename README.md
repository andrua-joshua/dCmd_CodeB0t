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
git clone https://github.com/yourusername/DCmd_C0deBot.git
cd DCmd_C0deBot
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
