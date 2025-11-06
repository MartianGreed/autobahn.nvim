#!/bin/bash
# Intercepts AskUserQuestion, sends to nvim, waits for answer

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL_NAME" != "AskUserQuestion" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Extract question data and escape for Lua
QUESTIONS=$(echo "$INPUT" | jq -c '.tool_input')
QUESTIONS_ESCAPED=$(echo "$QUESTIONS" | sed "s/'/\\\\'/g")
REQUEST_ID=$(uuidgen)
ANSWER_FILE="/tmp/claude-answer-$REQUEST_ID.json"

# Workspace is .autobahn/<branch>/, parent project is 2 levels up
WORKSPACE_DIR="$CLAUDE_PROJECT_DIR"
PARENT_PROJECT=$(cd "$WORKSPACE_DIR/../.." 2>/dev/null && pwd)

# Find nvim socket matching parent project
FOUND_SOCKET=""
shopt -s nullglob
for socket in /tmp/nvim*/0 "$XDG_RUNTIME_DIR"/nvim.*.0 "$TMPDIR"/nvim."$USER"/*/nvim.*.0; do
  [ -S "$socket" ] || continue
  cwd=$(nvim --server "$socket" --remote-expr "getcwd()" 2>/dev/null) || continue

  # Match parent project or workspace itself
  if [ "$cwd" = "$PARENT_PROJECT" ] || [ "$cwd" = "$WORKSPACE_DIR" ]; then
    FOUND_SOCKET="$socket"
    break
  fi
done

if [ -z "$FOUND_SOCKET" ]; then
  # No nvim found - allow tool to proceed normally
  echo '{"decision": "allow"}'
  exit 0
fi

# Call nvim RPC to show prompt
nvim --server "$FOUND_SOCKET" --remote-expr \
  "v:lua.require('autobahn.rpc').handle_question('$REQUEST_ID', '$QUESTIONS_ESCAPED')" 2>/dev/null

# Wait for answer file (timeout 5 minutes)
TIMEOUT=600
ELAPSED=0
while [ ! -f "$ANSWER_FILE" ] && [ $ELAPSED -lt $TIMEOUT ]; do
  sleep 0.5
  ELAPSED=$((ELAPSED + 1))
done

if [ -f "$ANSWER_FILE" ]; then
  ANSWER=$(cat "$ANSWER_FILE")
  rm -f "$ANSWER_FILE"
  # Return answer as tool input modification
  echo "{\"decision\": \"allow\", \"toolInput\": {\"answers\": $ANSWER}}"
else
  echo '{"decision": "deny", "reason": "Timeout waiting for user response"}'
fi
