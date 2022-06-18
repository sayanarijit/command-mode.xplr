---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local COMMANDS = {}
local COMMAND_HISTORY = {}
local CURR_CMD_INDEX = 1
local MAX_LEN = 0

local function matches_all(str, cmds)
  for _, p in ipairs(cmds) do
    if string.sub(p, 1, #str) ~= str then
      return false
    end
  end
  return true
end

local function BashExec(script)
  return function(_)
    return {
      { BashExec = script },
    }
  end
end

local function BashExecSilently(script)
  return function(_)
    return {
      { BashExecSilently = script },
    }
  end
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

local function define(name, help, silent)
  return function(fn)
    xplr.fn.custom.command_mode.fn[name] = fn
    COMMANDS[name] = { help = help, fn = fn, silent = silent }

    local len = string.len(name)
    if len > MAX_LEN then
      MAX_LEN = len
    end
  end
end

local function cmd(name, help)
  return define(name, help, false)
end

local function silent_cmd(name, help)
  return define(name, help, true)
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
      { SetInputPrompt = ":" },
    },
  }

  xplr.config.modes.custom.command_mode = {
    name = "command mode",
    layout = {
      Horizontal = {
        config = {
          constraints = {
            { Percentage = 70 },
            { Percentage = 30 },
          },
        },
        splits = {
          {
            Vertical = {
              config = {
                constraints = {
                  { Min = 1 },
                  { Length = 3 },
                },
              },
              splits = {
                {
                  CustomContent = {
                    title = "Commands",
                    body = {
                      DynamicList = { render = "custom.command_mode.render" },
                    },
                  },
                },
                "InputAndLogs",
              },
            },
          },
          {
            Vertical = {
              config = {
                constraints = {
                  { Percentage = 50 },
                  { Percentage = 50 },
                },
              },
              splits = {
                "Selection",
                "HelpMenu",
              },
            },
          },
        },
      },
    },

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
    if not app.input_buffer then
      return
    end

    local input = app.input_buffer
    local found = {}

    for name, _ in pairs(COMMANDS) do
      if string.sub(name, 1, #input) == input then
        table.insert(found, name)
      end
    end

    local count = #found

    if count == 0 then
      return
    elseif count == 1 then
      return {
        { SetInputBuffer = found[1] },
      }
    else
      local first = found[1]
      while #first > #input and matches_all(input, found) do
        input = string.sub(found[1], 1, #input + 1)
      end

      if matches_all(input, found) then
        return {
          { SetInputBuffer = input },
        }
      end

      return {
        { SetInputBuffer = string.sub(input, 1, #input - 1) },
      }
    end
  end

  xplr.fn.custom.command_mode.list = function(_)
    local list = {}
    for name, command in pairs(COMMANDS) do
      local help = command.help or ""
      local text = name
      for _ = #name, MAX_LEN, 1 do
        text = text .. " "
      end

      table.insert(list, text .. " " .. help)
    end

    table.sort(list)

    local pager = os.getenv("PAGER") or "less"
    local p = assert(io.popen(pager, "w"))
    p:write(table.concat(list, "\n"))
    p:flush()
    p:close()
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

  xplr.fn.custom.command_mode.render = function(ctx)
    local input = ctx.app.input_buffer or ""
    local ui = {}

    for name, _ in pairs(COMMANDS) do
      if string.sub(name, 1, #input) == input then
        local color = "\x1b[1m"

        if input == name then
          color = "\x1b[1;7m"
        end

        local line = color .. " " .. name .. " \x1b[0m"

        for _ = #name, MAX_LEN, 1 do
          line = line .. " "
        end

        line = line .. COMMANDS[name].help

        if input == name then
          line = "\x1b[1;7m" .. line .. "\x1b[0m"
        end

        table.insert(ui, line)
      end
    end

    table.sort(ui)
    table.insert(ui, 1, " ")

    return ui
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
