--
-- mySciTE's Lua Startup Script 2017 Marcedo@HabMalNeFrage.de
--
--~~~~~~~~~~~~~

-- Windows requires this for us to immediately see all lua output.
io.stdout:setvbuf("no")

myHome = props["SciteUserHome"].."\\user"
defaultHome = props["SciteDefaultHome"]
package.path = package.path ..";"..myHome.."\\Addons\\lua\\?.lua" .. ";"..myHome.."\\Addons\\lua\\?.lua;"
package.path = package.path .. ";"..myHome.."\\Addons\\mod-extman\\?.lua;"
package.cpath = package.cpath .. ";"..myHome.."\\Addons\\lua\\c\\?.dll;"

dirSep, GTK = props['PLAT_GTK']
if GTK then dirSep = '/' else dirSep = '\\' end

--lua >=5.2.x renamed functions:
local unpack = table.unpack or unpack
math.mod = math.fmod or math.mod
string.gfind = string.gmatch or string.gfind
--lua >=5.2.x replaced table.getn(x) with #x
--~~~~~~~~~~~~~

-- track the amount of lua allocated memory
_G.session_used_memory=collectgarbage("count")*1024
	
-- Load extman.lua
-- This will automatically run any lua script located in \User\Addons\lua\lua
dofile(myHome..'\\Addons\\mod-extman\\extman.lua')

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
