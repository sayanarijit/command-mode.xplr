command-mode.xplr
=================

This plugin acts like a library to help you define custom commands to perform
actions.


Why
---

[xplr](https://github.com/sayanarijit/xplr) has no concept of commands. By default, it requires us to map keys directly to a list of [messages](https://arijitbasu.in/xplr/en/message.html).
While for the most part this works just fine, sometimes it gets difficult to remember which action is mapped to which key inside which mode. Also, not every action needs to be bound to some key.

In short, sometimes, it's much more convenient to define and enter commands to perform certain actions than trying to remember key bindings.


Installation
------------

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  package.path = os.getenv("HOME") .. '/.config/xplr/plugins/?/src/init.lua'
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
      key = "a",
    }
  }

  -- Type `:` to enter command mode
  ```


Usage
-----

Examples are taken from [here](https://arijitbasu.in/xplr/en/message.html#example-using-lua-function-calls) and [here](https://arijitbasu.in/xplr/en/message.html#example-using-environment-variables-and-pipes).

```lua
-- Assuming you have installed and setup the plugin

local cmd = xplr.fn.custom.command_mode.cmd
local silent_cmd = xplr.fn.custom.command_mode.silent_cmd
local map = xplr.fn.custom.command_mode.map

-- Type `:hello-lua` and press enter to know your location
cmd("hello-lua", "Enter name and know location")(function(app)
  print("What's your name?")

  local name = io.read()
  local greeting = "Hello " .. name .. "!"
  local message = greeting .. " You are inside " .. app.pwd

  return {
    { LogSuccess = message },
  }
end)

-- Type `:hello-bash` and press enter to know your location
silent_cmd("hello-bash", "Enter name and know location")(function(app)
  return {
    {
      BashExec = [===[
        echo "What's your name?"

        read name
        greeting="Hello $name!"
        message="$greeting You are inside $PWD"
      
        echo LogSuccess: '"'$message'"' >> "${XPLR_PIPE_MSG_IN:?}"
      ]===],
    },
  }
end)

-- map `h` to command `hello-lua`
map("default", "h", "hello-lua")

-- map `H` to command `hello-bash`
map("default", "H", "hello-bash")
```

**NOTE:** To define non-interactive commands, use `xplr.fn.custom.command_mode.silent_cmd` to avoid the flickering of screen.


Features
--------

- Command completion
- Command history navigation
- Press `?` to list commands
- Press `!` to spawn shell
- Easily map keys to commands


TODO
----

- [ ] Fuzzy search commands
