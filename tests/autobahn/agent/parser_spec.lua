local parser = require("autobahn.agent.parser")
local fixtures = require("tests.autobahn.agent.fixtures.stream_json_samples")

describe("parser", function()
  before_each(function()
    parser.reset_state()
  end)

  describe("parse_stream_json", function()
    it("parses valid JSON", function()
      local result = parser.parse_stream_json('{"type":"assistant"}')
      assert.are.same({type = "assistant"}, result)
    end)

    it("returns nil for empty input", function()
      assert.is_nil(parser.parse_stream_json(""))
      assert.is_nil(parser.parse_stream_json(nil))
    end)

    it("returns nil for malformed JSON", function()
      assert.is_nil(parser.parse_stream_json("{invalid}"))
      assert.is_nil(parser.parse_stream_json("not json at all"))
    end)

    it("handles complex nested JSON", function()
      local json_str = vim.json.encode(fixtures.assistant_with_tool_use)
      local result = parser.parse_stream_json(json_str)
      assert.are.same(fixtures.assistant_with_tool_use, result)
    end)
  end)

  describe("reset_state", function()
    it("clears internal state", function()
      parser.format_output(fixtures.system_init, "test-session")
      parser.reset_state()
      local result = parser.format_output(fixtures.system_init, "test-session")
      assert.is_not_nil(result)
    end)
  end)

  describe("format_session_header", function()
    it("creates header with session metadata", function()
      local session = {
        id = "test-123",
        agent_type = "claude-code",
        branch = "main",
        workspace_path = "/repo/.autobahn/main",
        created_at = 1699000000
      }

      local lines = parser.format_session_header(session)

      assert.is_table(lines)
      assert.is_true(#lines > 0)
      assert.is_true(vim.tbl_contains(lines, function(line)
        return line:match("Autobahn")
      end, {predicate = true}))

      local has_session_id = false
      for _, line in ipairs(lines) do
        if line:match("test%-123") then
          has_session_id = true
          break
        end
      end
      assert.is_true(has_session_id)
    end)

    it("detects git workspace", function()
      local session = {
        id = "test-123",
        workspace_path = "/repo/.autobahn/feature-branch",
        created_at = os.time()
      }

      local lines = parser.format_session_header(session)
      local content = table.concat(lines, "\n")

      assert.is_true(content:match("git") ~= nil)
    end)

    it("detects jujutsu workspace", function()
      local session = {
        id = "test-123",
        workspace_path = "/repo/jj-workspace",
        created_at = os.time()
      }

      local lines = parser.format_session_header(session)
      local content = table.concat(lines, "\n")

      assert.is_true(content:match("jujutsu") ~= nil)
    end)
  end)

  describe("format_user_message", function()
    it("formats message without timestamp", function()
      local lines = parser.format_user_message("Hello world")

      assert.is_table(lines)
      assert.is_true(vim.tbl_contains(lines, "Hello world"))
      assert.is_true(vim.tbl_contains(lines, function(line)
        return line:match("User")
      end, {predicate = true}))
    end)

    it("formats message with timestamp", function()
      local timestamp = os.time()
      local lines = parser.format_user_message("Hello world", timestamp)

      assert.is_table(lines)
      assert.is_true(vim.tbl_contains(lines, "Hello world"))

      local has_timestamp = false
      for _, line in ipairs(lines) do
        if line:match("%d%d%d%d%-%d%d%-%d%d") then
          has_timestamp = true
          break
        end
      end
      assert.is_true(has_timestamp)
    end)
  end)

  describe("format_output", function()
    it("formats system init message", function()
      local lines = parser.format_output(fixtures.system_init, "test-session")

      assert.is_table(lines)
      assert.is_true(#lines > 0)

      local content = table.concat(lines, "\n")
      assert.is_true(content:find(fixtures.system_init.session_id, 1, true) ~= nil)
      assert.is_true(content:find(fixtures.system_init.model, 1, true) ~= nil)
    end)

    it("does not show session metadata twice", function()
      local lines1 = parser.format_output(fixtures.system_init, "test-session")
      local lines2 = parser.format_output(fixtures.system_init, "test-session")

      assert.is_table(lines1)
      assert.is_nil(lines2)
    end)

    it("formats assistant text message", function()
      local lines = parser.format_output(fixtures.assistant_text, "test-session")

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("I'll help you with that task") ~= nil)
    end)

    it("formats assistant message with timestamp", function()
      local timestamp = os.time()
      local lines = parser.format_output(fixtures.assistant_text, "test-session", timestamp)

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("%d%d%d%d%-%d%d%-%d%d") ~= nil)
    end)

    it("formats assistant message with cost delta", function()
      local lines = parser.format_output(fixtures.assistant_text, "test-session", os.time(), 0.05)

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("%$0%.0500") ~= nil)
    end)

    it("formats tool use with JSON input", function()
      local lines = parser.format_output(fixtures.assistant_with_tool_use, "test-session")

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("Tool:") ~= nil)
      assert.is_true(content:match("Read") ~= nil)
      assert.is_true(content:match("details") ~= nil)
    end)

    it("handles content_block_start", function()
      local result = parser.format_output(fixtures.content_block_start_text, "test-session")
      assert.is_nil(result)
    end)

    it("formats content_block_delta text", function()
      parser.format_output(fixtures.content_block_start_text, "test-session")
      local lines = parser.format_output(fixtures.content_block_delta_text, "test-session")

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("Let me help you") ~= nil)
    end)

    it("accumulates thinking deltas", function()
      parser.format_output(fixtures.content_block_start_thinking, "test-session")
      local delta_result = parser.format_output(fixtures.content_block_delta_thinking, "test-session")
      assert.is_nil(delta_result)
    end)

    it("formats thinking block on content_block_stop", function()
      parser.format_output(fixtures.content_block_start_thinking, "test-session")
      parser.format_output(fixtures.content_block_delta_thinking, "test-session")
      local lines = parser.format_output(fixtures.content_block_stop, "test-session")

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("Thinking") ~= nil)
      assert.is_true(content:match("details") ~= nil)
      assert.is_true(content:match("I need to analyze") ~= nil)
    end)

    it("formats tool result", function()
      local lines = parser.format_output(fixtures.tool_result, "test-session")

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("Tool Result") ~= nil)
      assert.is_true(content:match("Read") ~= nil)
      assert.is_true(content:match("File contents") ~= nil)
    end)

    it("formats simple text message", function()
      local lines = parser.format_output(fixtures.text_message, "test-session")

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("Simple text response") ~= nil)
    end)

    it("formats error message", function()
      local lines = parser.format_output(fixtures.error_message, "test-session")

      assert.is_table(lines)
      local content = table.concat(lines, "\n")
      assert.is_true(content:match("Error") ~= nil)
      assert.is_true(content:match("File not found") ~= nil)
    end)

    it("returns nil for result message", function()
      local result = parser.format_output(fixtures.result_message, "test-session")
      assert.is_nil(result)
    end)

    it("returns nil for nil input", function()
      local result = parser.format_output(nil, "test-session")
      assert.is_nil(result)
    end)
  end)

  describe("format_thinking_placeholder", function()
    it("returns placeholder text", function()
      local lines = parser.format_thinking_placeholder()
      assert.is_table(lines)
      assert.are.equal(1, #lines)
      assert.are.equal("thinking...", lines[1])
    end)
  end)
end)
