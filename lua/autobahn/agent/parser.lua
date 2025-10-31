local M = {}

function M.parse_stream_json(line)
  if not line or line == "" then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, line)
  if not ok then
    return nil
  end

  return decoded
end

function M.format_output(data)
  if not data then
    return nil
  end

  local lines = {}

  if data.type == "text" then
    table.insert(lines, data.result or "")
  elseif data.type == "tool_use" then
    local tool_name = data.subtype or "unknown"
    table.insert(lines, string.format("[Tool: %s]", tool_name))
    if data.result then
      table.insert(lines, data.result)
    end
  elseif data.type == "result" then
    if data.cost_usd then
      table.insert(lines, string.format("Cost: $%.4f", data.cost_usd))
    end
    if data.duration_ms then
      table.insert(lines, string.format("Duration: %.2fs", data.duration_ms / 1000))
    end
  elseif data.type == "error" then
    table.insert(lines, string.format("Error: %s", data.result or "Unknown error"))
  end

  return lines
end

return M
