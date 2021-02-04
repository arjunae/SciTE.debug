-- Windows requirement to immediately see all lua output.
io.stdout:setvbuf("no")
myHome = props["SciteDefaultHome"].."/user"
defaultHome = props["SciteDefaultHome"]
package.path = package.path ..";"..myHome.."\\?.lua" .. ";"..myHome.."\\lua-scite\\?.lua;"	-- scite related lua scripts
package.cpath = package.cpath .. ";"..myHome.."\\c\\?.dll;" -- common lua c libs
-- track the amount of lua allocated memory
_G.session_used_memory=collectgarbage("count")*1024
-- Convenience functions
dirSep, GTK = props['PLAT_GTK']
if GTK then dirSep = '/' else dirSep = '\\'; dirsep=dirSep end
-- Lua5.3 renamed functions
_G.unpack = table.unpack or unpack
_G.math.mod = math.fmod or math.mod
_G.string.gfind = string.gmatch or string.gfind
_G.os.exit= function() error("Catched os.exit from quitting SciTE.\n") end   
-- Load extman.lua - automatically runs any lua script located in \User\lua-scite
package.path = package.path .. ";"..myHome.."\\mod-extman\\?.lua;"
dofile(myHome..'\\mod-extman\\extman.lua')
-- Load debugger.lua
package.path = package.path .. ";"..myHome.."\\mod-scite-debug\\?.lua;"
dofile(myHome..'\\mod-scite-debug\\debugger.lua')
dofile(myHome..'\\lua-scite\\micromode.lua')

