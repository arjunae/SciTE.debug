-- go@ dofile $(FilePath)
-- ^^tell the 'go' command to use Scite's internal Lua interpreter. (requires micromode.lua)
-- Path to current Files Dir with a trailing slash. 
local filePath=debug.getinfo(1).source:match("@(.*[\\/]).+$") 
package.path = package.path .. ";"..filePath.."/?.lua"
require ("codebug")
--custom io
dbg_write =  function(str) trace("dbg:") trace (str) end
-- init Debugger
local myDbg=newDebugger("dbge.lua",false)
myDbg:cmd_where()
myDbg:cmd_go()
myDbg:cmd_quit()
