---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local COMMANDS = {}
local COMMAND_HISTORY = {}
local CURR_CMD_INDEX = 1

local function BashExec(script)
  return {
    { BashExec = script },
  }
end

local function BashExecSilently(script)
  return {
    { BashExecSilently = script },
  }
end

local function map(mode, key, name)
  local cmd = COMMANDS[name]
  if cmd then
    local messages = { "PopMode" }

    if cmd.silent then
      table.insert(messages, { CallLuaSilently = "custom.command_mode.fn." .. name })
    else
      table.insert(messages, { CallLua = "custom.command_mode.fn." .. name })
    end

    xplr.config.modes.builtin[mode].key_bindings.on_key[key] = {
      help = cmd.help,
      messages = messages,
    }
  end
end

local function cmd(name, help)
  return function(fn)
    xplr.fn.custom.command_mode.fn[name] = fn
    COMMANDS[name] = { help = help, fn = fn, silent = false }
  end
end

local function silent_cmd(name, help)
  return function(fn)
    xplr.fn.custom.command_mode.fn[name] = fn
    COMMANDS[name] = { help = help, fn = fn, silent = true }
  end
end

local function setup(args)
  -- Parse args
  args = args or {}
  args.mode = args.mode or "default"
  args.key = args.key or ":"
  args.remap_action_mode_to = args.remap_action_mode_to
    or { mode = "default", key = ";" }

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
      },
      default = {
        messages = {
          "UpdateInputBufferFromKey",
        },
      },
    },
  }

  xplr.fn.custom.command_mode = {
    map = map,
    cmd = cmd,
    silent_cmd = silent_cmd,
    fn = {},
  }

  xplr.fn.custom.command_mode.execute = function(app)
    local name = app.input_buffer
    if name then
      local command = COMMANDS[name]
      if command then
        if COMMAND_HISTORY[CURR_CMD_INDEX] ~= command then
          table.insert(COMMAND_HISTORY, name)
          CURR_CMD_INDEX = CURR_CMD_INDEX + 1
        end

        if command.silent then
          return command.fn(app)
        else
          return {
            { CallLua = "custom.command_mode.fn." .. name },
          }
        end
      end
    end
  end

  xplr.fn.custom.command_mode.try_complete = function(app)
    local input = app.input_buffer or ""
    local match = nil

    for name, _ in pairs(COMMANDS) do
      if string.sub(name, 1, string.len(input)) == input then
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
    for name, command in pairs(COMMANDS) do
      local help = command.help or ""
      text = text .. name
      for _ = 0, maxlen - string.len(name), 1 do
        text = text .. " "
      end

      text = text .. "\t" .. help .. "\n"
    end

    print(text)
    io.write("[Press ENTER to continue]")
    _ = io.read()
  end

  xplr.fn.custom.command_mode.prev_command = function(_)
    if CURR_CMD_INDEX > 1 then
      CURR_CMD_INDEX = CURR_CMD_INDEX - 1
    else
      for i, _ in ipairs(COMMAND_HISTORY) do
        CURR_CMD_INDEX = i + 1
      end
    end
    local command = COMMAND_HISTORY[CURR_CMD_INDEX]

    if command then
      return {
        { SetInputBuffer = command },
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

    local command = COMMAND_HISTORY[CURR_CMD_INDEX]
    if command then
      return {
        { SetInputBuffer = command },
      }
    end
  end
end

return {
  setup = setup,
  cmd = cmd,
  silent_cmd = silent_cmd,
  map = map,
  BashExec = BashExec,
  BashExecSilently = BashExecSilently,
}
