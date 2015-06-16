local component = require("component")
local s = require("serialization")
local event = require("event")
local shell = require("shell")
local mod = component.modem

local rcv_port = 4902
local snd_port = 4901
mod.open(rcv_port)

local selectors = {}
local args, options = shell.parse(...)

function handleModem(ev, to, from, port, distance, command, parameter)
  if command == "selectors" then
    selectors = s.unserialize(parameter)
    for k,v in pairs(selectors) do
      print(k..") "..v)
      --print(v)
    end
  end
end

if #args == 0 then
  mod.broadcast(snd_port, "getSelectors", 1)
  local ev, to, from, port, distance, command, parameter = event.pull(5, "modem_message")
  handleModem(ev, to, from, port, distance, command, parameter)
elseif args[1] == "set" then
  mod.broadcast(snd_port, "select", tonumber(args[2]))
elseif args[1] == "rescan" then
  mod.broadcast(snd_port, "rescan", 1)
elseif args[1] == "get" then
  mod.broadcast(snd_port, "extract", tonumber(args[2]))
elseif args[1] == "quit" then
  mod.broadcast(snd_port, "quit", 1)
end