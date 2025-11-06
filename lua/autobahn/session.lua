--- Session state management
--- @module autobahn.session
local M = {}

local state = {
  sessions = {},
  next_id = 1,
}

--- Session status constants
--- @enum SessionStatus
M.SessionStatus = {
  IDLE = "idle",
  RUNNING = "running",
  PAUSED = "paused",
  COMPLETED = "completed",
  ERROR = "error",
}

--- Create a new session
--- @param opts table Session options
--- @field agent_type string|nil Agent type (default: "claude-code")
--- @field workspace_path string Workspace path
--- @field task string|nil Task description
--- @field branch string|nil Branch name
--- @field auto_accept boolean|nil Auto-accept mode
--- @field interactive boolean|nil Interactive mode
--- @return table session Session object
function M.create(opts)
  local session_id = "session_" .. state.next_id
  state.next_id = state.next_id + 1

  local session = {
    id = session_id,
    agent_type = opts.agent_type or "claude-code",
    job_id = nil,
    workspace_path = opts.workspace_path,
    buffer_id = nil,
    status = M.SessionStatus.IDLE,
    task = opts.task or "",
    branch = opts.branch,
    auto_accept = opts.auto_accept,
    interactive = opts.interactive or false,
    created_at = os.time(),
    updated_at = os.time(),
    cost_usd = 0,
    output = {},
    messages = {},
    last_cost = 0,
  }

  state.sessions[session_id] = session
  return session
end

--- Get session by ID
--- @param session_id string Session identifier
--- @return table|nil session Session object or nil
function M.get(session_id)
  return state.sessions[session_id]
end

--- Get all sessions
--- @return table sessions Dictionary of session_id -> session
function M.get_all()
  return state.sessions
end

--- Update session properties
--- @param session_id string Session identifier
--- @param updates table Key-value pairs to update
--- @return table|nil session Updated session or nil
function M.update(session_id, updates)
  local session = state.sessions[session_id]
  if not session then
    return nil
  end

  for key, value in pairs(updates) do
    session[key] = value
  end
  session.updated_at = os.time()

  return session
end

--- Delete a session
--- @param session_id string Session identifier
--- @return table|nil session Deleted session or nil
function M.delete(session_id)
  local session = state.sessions[session_id]
  state.sessions[session_id] = nil
  return session
end

--- Save session state to disk
function M.save_state()
  local config = require("autobahn.config")
  if not config.get().persist then
    return
  end

  local state_path = vim.fn.stdpath("data") .. "/autobahn-sessions.json"
  local serializable_state = {
    sessions = {},
    next_id = state.next_id,
  }

  for id, session in pairs(state.sessions) do
    local s = vim.deepcopy(session)
    s.job_id = nil
    s.buffer_id = nil
    serializable_state.sessions[id] = s
  end

  local json = vim.json.encode(serializable_state)
  local file = io.open(state_path, "w")
  if file then
    file:write(json)
    file:close()
  end
end

--- Load session state from disk
--- @return boolean success True if state was loaded
function M.load_state()
  local state_path = vim.fn.stdpath("data") .. "/autobahn-sessions.json"
  local file = io.open(state_path, "r")
  if not file then
    return false
  end

  local content = file:read("*all")
  file:close()

  local ok, loaded_state = pcall(vim.json.decode, content)
  if ok and loaded_state then
    state.sessions = loaded_state.sessions or {}
    state.next_id = loaded_state.next_id or 1
    return true
  end

  return false
end

--- Clear all sessions and save state
function M.clear_state()
  state.sessions = {}
  M.save_state()
end

return M
