local M = {}

local callbacks = {}

M.EventType = {
  SESSION_CREATED = "session_created",
  SESSION_STARTED = "session_started",
  SESSION_COMPLETED = "session_completed",
  SESSION_ERROR = "session_error",
  SESSION_DELETED = "session_deleted",
  STATUS_CHANGED = "status_changed",
}

function M.on(event_type, callback)
  if not callbacks[event_type] then
    callbacks[event_type] = {}
  end
  table.insert(callbacks[event_type], callback)
end

function M.emit(event_type, data)
  if not callbacks[event_type] then
    return
  end

  for _, callback in ipairs(callbacks[event_type]) do
    vim.schedule(function()
      local ok, err = pcall(callback, data)
      if not ok then
        vim.notify(
          string.format("Event callback error: %s", err),
          vim.log.levels.ERROR
        )
      end
    end)
  end
end

return M
