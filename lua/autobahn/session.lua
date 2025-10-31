local M = {}

local state = {
  sessions = {},
  next_id = 1,
}

M.SessionStatus = {
  IDLE = "idle",
  RUNNING = "running",
  PAUSED = "paused",
  COMPLETED = "completed",
  ERROR = "error",
}

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
    created_at = os.time(),
    updated_at = os.time(),
    cost_usd = 0,
    output = {},
  }

  state.sessions[session_id] = session
  return session
end

function M.get(session_id)
  return state.sessions[session_id]
end

function M.get_all()
  return state.sessions
end

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

function M.delete(session_id)
  local session = state.sessions[session_id]
  state.sessions[session_id] = nil
  return session
end

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

function M.clear_state()
  state.sessions = {}
  M.save_state()
end

return M
