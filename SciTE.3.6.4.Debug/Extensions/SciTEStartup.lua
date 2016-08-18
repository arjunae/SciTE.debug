
defaultHome=props["SciteDefaultHome"]
package.path =  package.path ..";"..defaultHome.."\\Extensions\\?.lua;"
package.path = package.path .. ";"..defaultHome.."\\Extensions\\scite-lua\\?.lua;"
package.cpath = package.cpath .. ";"..defaultHome.."\\Extensions\\lib\\?.dll;"

-- Windows requires this for us to immediately see all lua output.
io.stdout:setvbuf("no")

-- Extman
dofile(props["SciteDefaultHome"]..'\\Extensions\\extman.lua')

