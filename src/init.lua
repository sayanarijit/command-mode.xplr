local function setup(args)
  local xplr = xplr

  local COMMANDS = {}
  local COMMAND_HISTORY = {}
  local CURR_CMD_INDEX = 1

  -- Parse args
  args = args or {}
  args.mode = args.mode or "default"
  args.key = args.key or ":"
  args.remap_action_mode_to = args.remap_action_mode_to
    or { mode = "default", key = "a" }

  xplr.config.modes.builtin[args.remap_action_mode_to.mode].key_bindings.on_key[args.remap_action_mode_to.key] =
    xplr.config.modes.builtin.default.key_bindings.on_key[":"]

  xplr.config.modes.builtin[args.mode].key_bindings.on_key[args.key] = {
    help = "command mode",
    messages = {
      "PopMode",
      { SwitchModeCustom = "command_mode" },
      { SetInputBuffer = "" },
    },
  }

  xplr.config.modes.custom.command_mode = {
    name = "command mode",
    key_bindings = {
      on_key = {
        enter = {
          help = "execute",
          messages = {
            { CallLuaSilently = "custom.command_mode.execute" },
            "PopMode",
          },
        },
        esc = {
          help = "cancel",
          messages = { "PopMode" },
        },
        tab = {
          help = "try complete",
          messages = {
            { CallLuaSilently = "custom.command_mode.try_complete" },
          },
        },
        up = {
          help = "prev",
          messages = {
            { CallLuaSilently = "custom.command_mode.prev_command" },
          },
        },
        down = {
          help = "next",
          messages = {
            { CallLuaSilently = "custom.command_mode.next_command" },
          },
        },
        ["!"] = {
          help = "shell",
          messages = {
            { Call = { command = "bash", args = { "-i" } } },
            "ExplorePwdAsync",
            "PopMode",
          },
        },
        ["?"] = {
          help = "list commands",
          messages = {
            { CallLua = "custom.command_mode.list" },
          },
        },
        ["-"] = {
          messages = {
            "BufferInputFromKey",
          },
        },
        ["ctrl-c"] = {
          help = "terminate",
          messages = { "Terminate" },
        },
        backspace = {
          messages = { "RemoveInputBufferLastCharacter" },
        },
        ["ctrl-u"] = {
          messages = {
            { SetInputBuffer = "" },
          },
        },
        ["ctrl-w"] = {
          messages = { "RemoveInputBufferLastWord" },
        },
      },

      on_alphabet = {
        messages = {
          "BufferInputFromKey",
        },
      },
      on_number = {
        messages = {
          "BufferInputFromKey",
        },
      },
      default = {
        messages = {},
      },
    },
  }

  xplr.fn.custom.command_mode = {}
  xplr.fn.custom.command_mode.fn = {}

  -- Define an interactive command
  xplr.fn.custom.command_mode.cmd = function(name, help)
    return function(fn)
      xplr.fn.custom.command_mode.fn[name] = fn
      COMMANDS[name] = { help = help, fn = fn, silent = false }
    end
  end

  -- Define a silent command
  xplr.fn.custom.command_mode.silent_cmd = function(name, help)
    return function(fn)
      xplr.fn.custom.command_mode.fn[name] = fn
      COMMANDS[name] = { help = help, fn = fn, silent = true }
    end
  end

  xplr.fn.custom.command_mode.execute = function(app)
    local name = app.input_buffer
    if name then
      local cmd = COMMANDS[name]
      if cmd then
        if COMMAND_HISTORY[CURR_CMD_INDEX] ~= cmd then
          table.insert(COMMAND_HISTORY, name)
          CURR_CMD_INDEX = CURR_CMD_INDEX + 1
        end

        if cmd.silent then
          return cmd.fn(app)
        else
          return {
            { CallLua = "custom.command_mode.fn." .. name },
          }
        end
      end
    end
  end

  xplr.fn.custom.command_mode.try_complete = function(app)
    local cmd = app.input_buffer or ""
    local match = nil

    for name, _ in pairs(COMMANDS) do
      if string.sub(name, 1, string.len(cmd)) == cmd then
        if match then
          match = nil
        else
          match = name
        end
      end
    end

    if match then
      return {
        { SetInputBuffer = match },
      }
    end
  end

  xplr.fn.custom.command_mode.list = function(_)
    local maxlen = 0
    for name, _ in pairs(COMMANDS) do
      local len = string.len(name)
      if len > maxlen then
        maxlen = len
      end
    end

    local text = ""
    for name, cmd in pairs(COMMANDS) do
      local help = cmd.help or ""
      text = text .. name
      for _ = 0, maxlen - string.len(name), 1 do
        text = text .. " "
      end

      text = text .. "\t" .. help .. "\n"
    end

    print(text)
    io.write("[Press ENTER to continue]")
    io.read()
  end

  xplr.fn.custom.command_mode.prev_command = function(_)
    if CURR_CMD_INDEX > 1 then
      CURR_CMD_INDEX = CURR_CMD_INDEX - 1
    else
      for i, _ in ipairs(COMMAND_HISTORY) do
        CURR_CMD_INDEX = i + 1
      end
    end
    local cmd = COMMAND_HISTORY[CURR_CMD_INDEX]

    if cmd then
      return {
        { SetInputBuffer = cmd },
      }
    end
  end

  xplr.fn.custom.command_mode.next_command = function(_)
    local len = 0
    for i, _ in ipairs(COMMAND_HISTORY) do
      len = i
    end

    if CURR_CMD_INDEX >= len then
      CURR_CMD_INDEX = 1
    else
      CURR_CMD_INDEX = CURR_CMD_INDEX + 1
    end

    local cmd = COMMAND_HISTORY[CURR_CMD_INDEX]
    if cmd then
      return {
        { SetInputBuffer = cmd },
      }
    end
  end

  xplr.fn.custom.command_mode.map = function(mode, key, name)
    local cmd = COMMANDS[name]
    if cmd then
      local messages = { "PopMode" }

      if cmd.silent then
        table.insert(
          messages,
          { CallLuaSilently = "custom.command_mode.fn." .. name }
        )
      else
        table.insert(messages, { CallLua = "custom.command_mode.fn." .. name })
      end

      xplr.config.modes.builtin[mode].key_bindings.on_key[key] = {
        help = cmd.help,
        messages = messages,
      }
    end
  end
end

return { setup = setup }
