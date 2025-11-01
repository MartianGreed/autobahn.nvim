# Agent Module

Agent process management and output parsing for running coding agents.

## Architecture

```
agent/
├── init.lua     # Agent interface
├── process.lua  # Process spawning and lifecycle
└── parser.lua   # Output format parsing
```

## Usage

```lua
local agent = require("autobahn.agent")

-- Start an agent
agent.start(session_id, "Implement user authentication")

-- Stop an agent
agent.stop(session_id)

-- Check if running
if agent.is_running(session_id) then
  print("Agent is running")
end

-- Restart an agent
agent.restart(session_id, "New task")

-- Send message to interactive session
agent.send_message(session_id, "Can you also add error handling?")
```

## Process Module (`process.lua`)

### `spawn(session_id, task) -> number|nil`
Spawn an agent process for a session.

**Behavior:**
- Creates output buffer if needed
- Constructs command with appropriate flags
- Handles both one-shot and interactive modes
- Parses stream-json output in real-time
- Updates session state on completion
- Emits events for status changes

**Returns:** Job ID or nil on failure

### `send_message(session_id, message) -> boolean`
Send a message to an interactive session.

**Requirements:**
- Session must be in interactive mode
- Session must have initialized (has `claude_session_id`)
- Session must not be currently processing

**Returns:** True if message was sent

### `stop(session_id) -> boolean`
Stop a running agent process.

### `is_running(session_id) -> boolean`
Check if agent process is still running.

## Parser Module (`parser.lua`)

Parses Claude Code's `stream-json` output format.

### `parse_stream_json(line) -> table|nil`
Parse a single line of stream-json output.

**Returns:** Decoded JSON object or nil

### `format_output(data) -> table|nil`
Format parsed data for display in output buffer.

**Message Types:**
- `system`: Session initialization info
- `assistant`: Agent responses and tool usage
- `text`: Plain text output
- `tool_use`: Tool execution details
- `result`: Session completion summary
- `error`: Error messages

**Returns:** Array of formatted lines or nil

## Command Construction

The process module builds commands based on agent configuration and session settings:

```lua
-- Base command
{agent_config.cmd}

-- One-shot mode
{"-p", task}

-- Interactive mode (resume)
{"-p", task, "--resume", session.claude_session_id}

-- Output format
{"--output-format", "stream-json", "--verbose"}

-- Auto-accept
{"--dangerously-skip-permissions"}
-- or custom flags from agent config
```

## Session Modes

### One-shot Mode
- Single task execution
- Agent exits when complete
- Uses `-p` flag for non-interactive prompt

### Interactive Mode
- Persistent session across messages
- Uses `--resume` flag with session ID
- Requires `stream-json` output format
- Agent waits between messages

## Output Buffer

Each session has a dedicated buffer:

**Format:** `autobahn://<session_id>`

**Properties:**
- `buftype=nofile`: Not backed by a file
- `modifiable=false`: Read-only to users
- Persists across agent restarts in interactive mode

**Content:**
```
=== Autobahn Agent Session ===
Task: Implement user authentication
Workspace: /path/to/.autobahn/feature-auth

Session: abc123
Model: claude-sonnet-4-5

Agent response here...
[Tool: Write]
...

=== Session Complete ===
Total Cost: $0.1234
Duration: 45.67s
```

## Event Emission

The process module emits events during agent lifecycle:

- `SESSION_STARTED`: When process spawns
- `SESSION_COMPLETED`: On successful completion (exit code 0)
- `SESSION_ERROR`: On failure (exit code != 0)
- `STATUS_CHANGED`: When process stops

## Error Handling

- Invalid session: Notifies user and returns nil/false
- Process spawn failure: Deletes buffer and returns nil
- Interactive mode errors: Validates state before sending
- Exit code != 0: Emits error event and notifies user
