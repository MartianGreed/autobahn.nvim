local M = {}

M.system_init = {
  type = "system",
  subtype = "init",
  session_id = "70d841bb-3ffa-49b7-b26a-aeacff4b6f61",
  model = "claude-sonnet-4-5-20250929"
}

M.assistant_text = {
  type = "assistant",
  message = {
    role = "assistant",
    content = {
      {
        type = "text",
        text = "I'll help you with that task."
      }
    }
  }
}

M.content_block_start_text = {
  type = "content_block_start",
  index = 0,
  content_block = {
    type = "text"
  }
}

M.content_block_start_thinking = {
  type = "content_block_start",
  index = 0,
  content_block = {
    type = "thinking"
  }
}

M.content_block_start_tool = {
  type = "content_block_start",
  index = 1,
  content_block = {
    type = "tool_use",
    name = "Read",
    id = "tool_123"
  }
}

M.content_block_delta_text = {
  type = "content_block_delta",
  index = 0,
  delta = {
    type = "text_delta",
    text = "Let me help you "
  }
}

M.content_block_delta_thinking = {
  type = "content_block_delta",
  index = 0,
  delta = {
    type = "thinking_delta",
    thinking = "I need to analyze this carefully..."
  }
}

M.content_block_delta_json = {
  type = "content_block_delta",
  index = 1,
  delta = {
    type = "input_json_delta",
    partial_json = '{"file_path":"/path/to/file.lua"'
  }
}

M.content_block_stop = {
  type = "content_block_stop",
  index = 0
}

M.tool_use = {
  type = "tool_use",
  subtype = "Read",
  result = "Successfully read file"
}

M.tool_result = {
  type = "tool_result",
  tool_name = "Read",
  content = {
    {
      type = "text",
      text = "File contents here..."
    }
  }
}

M.text_message = {
  type = "text",
  result = "Simple text response"
}

M.error_message = {
  type = "error",
  result = "File not found"
}

M.result_message = {
  type = "result"
}

M.message_with_cost = {
  type = "assistant",
  total_cost_usd = 0.05,
  message = {
    role = "assistant",
    content = {
      {
        type = "text",
        text = "Response with cost tracking"
      }
    }
  }
}

M.assistant_with_tool_use = {
  type = "assistant",
  message = {
    role = "assistant",
    content = {
      {
        type = "text",
        text = "I'll read the file for you."
      },
      {
        type = "tool_use",
        id = "tool_abc123",
        name = "Read",
        input = {
          file_path = "/Users/test/file.lua"
        }
      }
    }
  }
}

return M
