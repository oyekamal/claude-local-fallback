# claude-local-fallback

Keep using the `claude` command when your Claude session runs out.

Claude Code stops cold when your session expires, you hit the usage limit, or you never had a subscription. This is a small bash script that sits in front of `claude`. When Claude refuses with an auth or quota error, it sends the same request to a model running through [Ollama](https://ollama.com), and you get an answer instead of an error.

It is also a cheap way to try Claude Code if you can't pay for it yet. Install Claude Code (free), install Ollama (free), and the same `claude` command works on a free model, so you learn the workflow before you spend anything.

```
you ──> claude ──> real Claude Code ──> answer
            │
            └─ 401 / "hit your limit" / not logged in
                     │
                     ├─> Ollama cloud model, full Claude Code with tools   (fast, needs internet + free ollama account)
                     └─> local model on your laptop, plain chat            (works offline, downloads itself on first use)
```

## Install

You need bash (Linux, macOS, or WSL on Windows) and Ollama.

```bash
# 1. Ollama (skip if you have it)
curl -fsSL https://ollama.com/install.sh | sh        # Linux. macOS/Windows: https://ollama.com/download

# 2. this script
curl -fsSL https://raw.githubusercontent.com/oyekamal/claude-local-fallback/main/install.sh | bash

# 3. optional, for the fast cloud fallback (free account)
ollama signin
```

Open a new terminal, then check it:

```bash
claude --local -p "say hi"
```

The installer copies one file to `~/.claude-fallback/bin/claude` and adds that folder to the front of your PATH in `~/.bashrc` / `~/.zshrc`. Your real Claude Code install is not touched. To remove it:

```bash
curl -fsSL https://raw.githubusercontent.com/oyekamal/claude-local-fallback/main/uninstall.sh | bash
```

## What happens when you type `claude`

`claude -p "..."` (scripts, cron jobs, bots): the real Claude runs first. If it exits with an auth or quota error, the script replays the same prompt, including anything you piped in on stdin, to the first working model in the chain. Any other error passes through unchanged, so real bugs don't get hidden.

`claude` (interactive): Claude Code can't switch models halfway through a session. So the script checks before starting. If you're logged out, or a `-p` call hit the limit in the last 30 minutes, it opens the fallback right away.

The model chain is `gemma4:31b-cloud llama3.2` by default.

1. Models whose name ends in `cloud` run on Ollama's servers. They run inside Claude Code with all its tools, so reading files, editing and running commands still work. A reply takes about 3 seconds.
2. Other models run on your machine. If one is missing, the script downloads it on first use. It also copies the model as `cf-<name>` with an 8K context window, because Ollama's default is too small. By default local models answer as plain chat with no tools. The next section explains why.

## Pick a local model for your laptop

Claude Code sends a large prompt with every request (its tool definitions alone are around 15K tokens). A small model on a small GPU takes minutes just to read it. I measured this on a laptop with a 4 GB Quadro T2000 and 32 GB RAM.

| Model | Inside Claude Code (with tools) | Plain chat |
|---|---|---|
| `qwen3:4b` | over 10 minutes per turn, 42% of it on CPU | 7.6 tokens/s, thinks out loud |
| `llama3.2` (3B) | not tried | 31 tokens/s, 85% on GPU |
| `gemma4:31b-cloud` | about 3 s per turn, tools work | n/a |

So the rule of thumb:

| Your GPU memory | Put in `CLAUDE_FALLBACK_MODELS` | Tools offline? |
|---|---|---|
| none or 4 GB | `llama3.2` or `qwen3:1.7b` | no, keep the default plain chat |
| 8 GB | `qwen3:8b`, `glm-4.7-flash` | maybe, try `CLAUDE_FALLBACK_LOCAL_TOOLS=1` |
| 16 GB+ or a 32 GB+ Mac | `gpt-oss:20b`, `qwen3-coder:30b` | yes, set `CLAUDE_FALLBACK_LOCAL_TOOLS=1` |

The 8 GB and 16 GB rows come from other people's reports, not my own tests. Try a model on a throwaway folder before you trust it with real work. If you have a good result on your hardware, open an issue with the numbers and I'll add them to the table.

## Settings

Put these in your shell rc file, or set them for one command.

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_FALLBACK_MODELS` | `gemma4:31b-cloud llama3.2` | Models to try, in order. First one that responds wins. |
| `CLAUDE_FALLBACK_LOCAL_TOOLS` | `0` | `1` runs local models inside Claude Code with tools instead of plain chat. |
| `CLAUDE_FALLBACK_CTX` | `8192` | Context window for local models. More needs more memory. |
| `CLAUDE_FALLBACK_OFF` | unset | Set to anything to skip the script and run the real `claude`. |
| `CLAUDE_FALLBACK_OLLAMA_URL` | `http://localhost:11434` | Where Ollama listens. |
| `CLAUDE_FALLBACK_REAL` | auto | Path to the real `claude`, if auto-detection picks the wrong one. |

`claude --local ...` forces the fallback for one command, which is handy for practice or for testing a model.

## Known limits

- If you hit the limit in the middle of an interactive session, the script can't catch it. Exit and run `claude` again and it will start on the fallback.
- In plain-chat mode the answer comes back as text. A script that asked for `--output-format json` gets text instead.
- Local models get your project's `CLAUDE.md` added to the prompt, but not hooks or plugins. The fallback runs Claude Code with `--bare`, which skips them because they can add minutes of startup.
- Cloud models need internet and an Ollama account, and Ollama's free tier has its own limits.
- Claude Code prints a few warnings when it talks to Ollama, such as "isn't described by this version's model catalog". They're harmless.
- Error detection matches the messages Claude Code prints today (`Failed to authenticate`, `hit your limit`, and similar). If Anthropic changes the wording, update `FAIL_RE` at the top of the script.

## How it works

Ollama 0.14 and later accepts the same API that Claude Code speaks ([docs](https://docs.ollama.com/api/anthropic-compatibility)), so no proxy is needed. The fallback is Claude Code with three environment variables changed:

```bash
ANTHROPIC_BASE_URL=http://localhost:11434 ANTHROPIC_API_KEY=ollama claude --bare --model gemma4:31b-cloud
```

The script adds the parts that make it automatic. It detects the failure, replays stdin, walks the model chain, downloads missing models, and remembers a recent limit so interactive sessions skip straight to the fallback.

If you want Claude first and a fallback on *every* error, including rate limits and outages, look at a [LiteLLM proxy with fallbacks](https://medium.com/@niklas-palm/claude-code-with-litellm-24b3fb115911). This project only falls back on auth and quota errors, and needs no server.

## Test

```bash
bash tests/test.sh
```

It uses fake `claude`, `ollama` and `curl` binaries, so it runs offline in under a second.

## License

MIT
