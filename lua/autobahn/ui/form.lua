local Input = require("nui.input")
local Menu = require("nui.menu")
local vcs = require("autobahn.vcs")
local config = require("autobahn.config")

local M = {}

local function select_with_menu(items, opts, callback)
  local menu_items = {}
  for _, item in ipairs(items) do
    table.insert(menu_items, Menu.item(item))
  end

  local menu = Menu({
    position = "50%",
    size = {
      width = opts.width or 60,
      height = math.min(#menu_items, opts.height or 15),
    },
    border = {
      style = "rounded",
      text = {
        top = opts.title or "Select",
        top_align = "center",
      },
    },
  }, {
    lines = menu_items,
    on_submit = function(item)
      callback(item.text)
    end,
  })

  menu:mount()

  menu:map("n", "<Esc>", function()
    menu:unmount()
    if opts.on_cancel then
      opts.on_cancel()
    end
  end)

  menu:map("n", "q", function()
    menu:unmount()
    if opts.on_cancel then
      opts.on_cancel()
    end
  end)
end

local function has_telescope()
  local ok = pcall(require, "telescope")
  return ok
end

local function select_branch(callback)
  local branches = vcs.get_branches()

  if #branches == 0 then
    vim.notify("No branches found", vim.log.levels.WARN)
    return
  end

  if has_telescope() then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers
      .new({}, {
        prompt_title = "Select Branch",
        finder = finders.new_table({
          results = branches,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            callback(selection[1])
          end)
          return true
        end,
      })
      :find()
  else
    select_with_menu(branches, {
      title = "Select Branch",
      width = 60,
      height = 15,
    }, callback)
  end
end

local function prompt_task(callback)
  local input = Input({
    position = "50%",
    size = {
      width = 80,
      height = 3,
    },
    border = {
      style = "rounded",
      text = {
        top = " Task Description ",
        top_align = "center",
      },
    },
  }, {
    prompt = "> ",
    on_submit = function(value)
      if value and value ~= "" then
        callback(value)
      else
        vim.notify("Task cannot be empty", vim.log.levels.WARN)
      end
    end,
  })

  input:mount()

  input:map("n", "<Esc>", function()
    input:unmount()
  end)
end

local function prompt_auto_accept(callback)
  local opts = config.get()
  local default = opts.agents[opts.default_agent].auto_accept

  select_with_menu({ "Yes", "No" }, {
    title = "Auto-accept agent actions?",
    width = 40,
    height = 4,
  }, function(choice)
    callback(choice == "Yes")
  end)
end

function M.show()
  prompt_task(function(task)
    select_branch(function(branch)
      prompt_auto_accept(function(auto_accept)
        local autobahn = require("autobahn")
        local new_session = autobahn.create_session({
          task = task,
          branch = branch,
          auto_accept = auto_accept,
          start_immediately = true,
        })

        if new_session then
          vim.notify(
            string.format("Session %s created", new_session.id),
            vim.log.levels.INFO
          )
        end
      end)
    end)
  end)
end

return M
