-- Use of this source code is governed by the Apache 2.0 license; see COPYING.

module(...,package.seeall)

local shm = require("core.shm")
local interlink = require("lib.interlink")

local Receiver = {name="apps.interlink.Receiver"}

function Receiver:new (_, name)
   packet.enable_group_freelist()
   local self = {}
   self.shm_name = "group/interlink/"..name..".interlink"
   self.backlink = "interlink/receiver/"..name..".interlink"
   self.interlink = interlink.attach_receiver(self.shm_name)
   shm.alias(self.backlink, self.shm_name)
   return setmetatable(self, {__index=Receiver})
end

function Receiver:pull ()
   local o, r, n = self.output.output, self.interlink, 0
   if not o then return end -- don’t forward packets until connected
   while not interlink.empty(r) and n < engine.pull_npackets do
      link.transmit(o, interlink.extract(r))
      n = n + 1
   end
   interlink.pull(r)
end

function Receiver:stop ()
   interlink.detach_receiver(self.interlink, self.shm_name)
   shm.unlink(self.backlink)
end

-- Detach receivers to prevent leaking interlinks opened by pid.
--
-- This is an internal API function provided for cleanup during
-- process termination.
function Receiver.shutdown (pid)
   for _, name in ipairs(shm.children("/"..pid.."/interlink/receiver")) do
      local backlink = "/"..pid.."/interlink/receiver/"..name..".interlink"
      local shm_name = "/"..pid.."/group/interlink/"..name..".interlink"
      -- Call protected in case /<pid>/group is already unlinked.
      local ok, r = pcall(interlink.open, shm_name)
      if ok then interlink.detach_receiver(r, shm_name) end
      shm.unlink(backlink)
   end
end

return Receiver
