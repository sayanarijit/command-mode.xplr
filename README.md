https://user-images.githubusercontent.com/11632726/174449444-2e13c1d7-7c1b-4dea-a2a8-13f193d8df8d.mp4

# command-mode.xplr

This plugin acts like a library to help you define custom commands to perform
actions.

## Why

[xplr](https://github.com/sayanarijit/xplr) has no concept of commands. By default, it requires us to map keys directly to a list of [messages](https://arijitbasu.in/xplr/en/message.html).
While for the most part this works just fine, sometimes it gets difficult to remember which action is mapped to which key inside which mode. Also, not every action needs to be bound to some key.

In short, sometimes, it's much more convenient to define and enter commands to perform certain actions than trying to remember key bindings.

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  local home = os.getenv("HOME")
  package.path = home
  .. "/.config/xplr/plugins/?/init.lua;"
  .. home
  .. "/.config/xplr/plugins/?.lua;"
  .. package.path
  ```

- Clone the plugin

  ```bash
  mkdir -p ~/.config/xplr/plugins

  git clone https://github.com/sayanarijit/command-mode.xplr ~/.config/xplr/plugins/command-mode
  ```

- Require the module in `~/.config/xplr/init.lua`

  ```lua
  require("command-mode").setup()

  -- Or

  require("command-mode").setup{
    mode = "default",
    key = ":",
    remap_action_mode_to = {
      mode = "default",
      key = ";",
    }
  }

  -- Type `:` to enter command mode
  ```

## Usage

Examples are taken from [here](https://xplr.dev/en/environment-variables-and-pipes#example-using-environment-variables-and-pipes) and [here](https://xplr.dev/en/lua-function-calls#example-using-lua-function-calls).

```lua
-- Assuming you have installed and setup the plugin

local m = require("command-mode")

-- Setup with default settings
m.setup()

-- Type `:hello-lua` and press enter to know your location
local hello_lua = m.cmd("hello-lua", "Enter name and know location")(function(app)
  print("What's your name?")

  local name = io.read()
  local greeting = "Hello " .. name .. "!"
  local message = greeting .. " You are inside " .. app.pwd

  return {
    { LogSuccess = message },
  }
end)

-- Type `:hello-bash` and press enter to know your location
local hello_bash = m.silent_cmd("hello-bash", "Enter name and know location")(
  m.BashExec [===[
    echo "What's your name?"

    read name
    greeting="Hello $name!"
    message="$greeting You are inside $PWD"

    echo LogSuccess: '"'$message'"' >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

-- map `h` to command `hello-lua`
xplr.config.modes.builtin.default.key_bindings.on_key.h = hello_lua.action

-- map `H` to command `hello-bash`
xplr.config.modes.builtin.default.key_bindings.on_key.H = hello_bash.action
```

**NOTE:** To define non-interactive commands, use `silent_cmd` to avoid the flickering of screen.

## Features

- Tab completion
- Command history navigation
- Press `?` to list commands
- Press `!` to spawn shell
- Easily map keys to commands
- Shortcut for `BashExec` and `BashExecSilently` messages.
- Interactive UI
