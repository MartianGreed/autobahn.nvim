local vcs = require("autobahn.vcs")
local config = require("autobahn.config")

local M = {}

local function has_snacks()
  local ok = pcall(require, "snacks")
  return ok
end

local function select_branch(callback)
  local detected_vcs = vcs.detect()
  if not detected_vcs then
    vim.notify("No VCS detected (git or jj). Open Neovim in a git/jj repository.", vim.log.levels.ERROR)
    return
  end

  local branches = vcs.get_branches()

  if #branches == 0 then
    vim.notify(string.format("No branches found in %s repository", detected_vcs), vim.log.levels.WARN)
    return
  end

  if has_snacks() then
    local snacks = require("snacks")
    local items = {}
    for i, branch in ipairs(branches) do
      table.insert(items, {
        idx = i,
        text = branch,
        score = 0,
        branch = branch,
      })
    end

    snacks.picker.pick({
      items = items,
      prompt = " Select Branch ",
      format = "text",
      layout = {
        preview = false,
      },
      confirm = function(picker, item)
        if item then
          picker:close()
          callback(item.branch)
        end
      end,
    })

    vim.schedule(function()
      vim.cmd("startinsert")
    end)
  else
    vim.ui.select(branches, {
      prompt = "Select Branch:",
    }, function(choice)
      if choice then
        callback(choice)
      end
    end)
  end
end

local function prompt_task(callback)
  vim.ui.input({
    prompt = " Task Description: ",
    default = "",
  }, function(input)
    if input and input ~= "" then
      callback(input)
    else
      vim.notify("Task cannot be empty", vim.log.levels.WARN)
    end
  end)
end

local function prompt_auto_accept(callback)
  if has_snacks() then
    local snacks = require("snacks")
    snacks.picker.pick({
      items = {
        { idx = 1, text = "Yes - Auto-accept all actions", score = 0, value = true },
        { idx = 2, text = "No  - Review each action", score = 0, value = false },
      },
      prompt = " Auto-accept agent actions? ",
      format = "text",
      layout = {
        preview = false,
      },
      confirm = function(picker, item)
        if item then
          picker:close()
          callback(item.value)
        end
      end,
    })

    vim.schedule(function()
      vim.cmd("startinsert")
    end)
  else
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Auto-accept agent actions?",
    }, function(choice)
      if choice then
        callback(choice == "Yes")
      end
    end)
  end
end

local function prompt_interactive(callback)
  if has_snacks() then
    local snacks = require("snacks")
    snacks.picker.pick({
      items = {
        { idx = 1, text = "󰊢 Interactive - Continuous conversation", score = 0, value = true },
        { idx = 2, text = "󱕘 One-shot  - Execute task and exit", score = 0, value = false },
      },
      prompt = " Session Mode ",
      format = "text",
      layout = {
        preview = false,
      },
      confirm = function(picker, item)
        if item then
          picker:close()
          callback(item.value)
        end
      end,
    })

    vim.schedule(function()
      vim.cmd("startinsert")
    end)
  else
    vim.ui.select({ "Interactive", "One-shot" }, {
      prompt = "Session mode?",
    }, function(choice)
      if choice then
        callback(choice == "Interactive")
      end
    end)
  end
end

local function prompt_plan_mode(callback)
  if has_snacks() then
    local snacks = require("snacks")
    snacks.picker.pick({
      items = {
        { idx = 1, text = " Build  - Execute changes", score = 0, value = false },
        { idx = 2, text = " Plan   - Research only", score = 0, value = true },
      },
      prompt = " Agent Mode ",
      format = "text",
      layout = {
        preview = false,
      },
      confirm = function(picker, item)
        if item then
          picker:close()
          callback(item.value)
        end
      end,
    })

    vim.schedule(function()
      vim.cmd("startinsert")
    end)
  else
    vim.ui.select({ "Build", "Plan" }, {
      prompt = "Agent mode?",
    }, function(choice)
      if choice then
        callback(choice == "Plan")
      end
    end)
  end
end

function M.show()
  prompt_task(function(task)
    select_branch(function(branch)
      prompt_auto_accept(function(auto_accept)
        prompt_interactive(function(interactive)
          prompt_plan_mode(function(plan_mode)
            local autobahn = require("autobahn")
            local new_session = autobahn.create_session({
              task = task,
              branch = branch,
              auto_accept = auto_accept,
              interactive = interactive,
              plan_mode = plan_mode,
              start_immediately = true,
            })

            if new_session then
              vim.notify(
                string.format(
                  "Session %s created (%s, %s)",
                  new_session.id,
                  interactive and "interactive" or "one-shot",
                  plan_mode and "plan" or "build"
                ),
                vim.log.levels.INFO
              )
            end
          end)
        end)
      end)
    end)
  end)
end

return M
