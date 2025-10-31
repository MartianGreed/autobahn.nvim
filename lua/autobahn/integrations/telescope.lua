local M = {}

function M.is_available()
  local ok = pcall(require, "telescope")
  return ok
end

function M.setup()
  if not M.is_available() then
    return
  end

  local telescope = require("telescope")

  telescope.load_extension("autobahn")
end

function M.sessions_picker()
  if not M.is_available() then
    vim.notify("Telescope not available", vim.log.levels.WARN)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local session = require("autobahn.session")

  local sessions = session.get_all()
  local results = {}

  for id, s in pairs(sessions) do
    table.insert(results, {
      id = id,
      display = string.format("[%s] %s - %s", s.status, id, s.task),
      ordinal = id .. " " .. s.task,
      session = s,
    })
  end

  pickers
    .new({}, {
      prompt_title = "Autobahn Sessions",
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.ordinal,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          require("autobahn.ui").show_session_output(selection.value.id)
        end)

        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          require("autobahn").delete_session(selection.value.id)
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          current_picker:refresh(finders.new_table({
            results = vim
              .iter(session.get_all())
              :map(function(id, s)
                return {
                  id = id,
                  display = string.format("[%s] %s - %s", s.status, id, s.task),
                  ordinal = id .. " " .. s.task,
                  session = s,
                }
              end)
              :totable(),
            entry_maker = function(entry)
              return {
                value = entry,
                display = entry.display,
                ordinal = entry.ordinal,
              }
            end,
          }))
        end)

        return true
      end,
    })
    :find()
end

return M
