-- go@ dofile $(FilePath)
-- ^^tell the 'go' command to use Scite's internal Lua interpreter. (optional - requires micromode.lua)

--[[

	Debugging lua Scripts ran within Scites Lua Subsystem required a second instance and a helper script like RemDebug or MobDebug.
	The Solution below uses Gunnar Zötls lua clib called dbghelper paired with Scott Lembke's debugger.lua to debug lua scripts using (SciTE's) internal lua instance only.
	
	Status:  - prototype_20210125 - Thorsten Kani (Marcedo@HabMalNeFrage.de) - BSD-3Clause
	References:	http://tset.de/dbghelper/index.html https://github.com/slembcke/debugger.lua
	
	10.01.2021 - Initial version converted to a lua "class"
	14.01.2021 - cmd_go, cmd_step_over, cmd_breakpoint, init_dbge
	24.01.2020 - cmd_locals, scite interactive mode, corner case fixes
	
--]]

package.path = package.path .. ";./?.lua"
if not pcall(require,"dbghelper") then error("\n   ## Sorry - Need lua module dbghelper.dll to run ## ") end
local DBG_INTERACTIVE, SCITE_EXTMAN, SCITE_LUA, VANILLA_LUA
local dbgPrompt="coDebug> "
local dbgBreakpoints={} -- {idx{file=LineNo}}
local dbg_cr, dbg_info, status -- Debugging Coroutine
local dbgMetatable = {}
local dbgMethods = {}
local dbgPath=debug.getinfo(1).source:match("@(.*[\\/]).+$") 	-- Path to current Files Dir with a trailing slash.  
dbgMetatable.__index = dbgMethods
if scite~=nil then SCITE_LUA=true else VANILLA_LUA=true end
if scite_MenuCommand~=nil then SCITE_EXTMAN=true end --  Only DBG_Interactive requires "extman" 

-- debuggers io
-- Defined as non local so io functions can be redefined by the caller. 
function dbg_write(str)
	-- Exception: cannot use io.write in SciTE so opt in for "trace" instead.
	if SCITE_LUA then trace(str) else io.write(str) end
end

function dbg_read(prompt)
	dbg_write(prompt)
	return io.read()
end

-- Class Constructor
function newDebugger(luafile,interactive)
    local debg={}
  	 status="down"
	 setmetatable(debg,dbgMetatable)
	 debg:init(luafile,interactive)
    return debg
end

-- Member functions

function dbgMethods:write(str)
	if SCITE_LUA and DBG_INTERACTIVE then trace(str) else dbg_write(str) end
end

function dbgMethods:writeln(...)	
  	local nargs = select("#", ...)
	
	for x=1,nargs do 
		self:write(select(x, ... ).."\n" or "<NULL>")
	end
end

-- perform a single step (until next line/call or return) within the debugged srcfile.
function dbgMethods:cr_step(mask,count,dest)
	local ok, what, x = debug.resumeuntil(dbg_cr, mask)

	dbg_info=debug.getinfo(dbg_cr, 0, "lnS") or {}
	if not dbg_info.linedefined then 
		status="down"
		self:writeln "Returned from debugee"
	else
		--trace(ok,what,x,dbg_info.currentline)
	end
	return ok
end

-- single step functionality
function dbgMethods:cmd_step()
	if not dbg_info.linedefined then return false end
	ok=self:cr_step("l")
	self:writeln(self:format_stack_frame_info(dbg_info))
	return true
end

-- step Over / step out functionality
function dbgMethods:cmd_stepOver()
	if not dbg_info.linedefined then return false end
	ok=self:cr_step("r")
	self:writeln(self:format_stack_frame_info(dbg_info))
	return true
end

-- go functionality - simple Wrapper around cr_step
function dbgMethods:cmd_go()
	if not dbg_info.linedefined then return false end
	local lineHasBp=false
	local currfile = dbg_info.source:match("@(.*)") 
	
	self:writeln("Go:")
	while (not lineHasBp and dbg_info.currentline~=nil and ok~=false) do
		ok=self:cr_step("l")
		for idx,hash in pairs(dbgBreakpoints) do
			for bpfile,bpline in pairs(hash) do
				if (bpfile==currfile and bpline==dbg_info.currentline) then 
					lineHasBp=true
					self:writeln ("Reached Breakpoint ("..currfile.." => ".. bpline..")")
				end
			end
		end
	end
	return true
end

-- Prints a Backtrace
function dbgMethods:cmd_trace()
	if not dbg_info.linedefined then return false end
	local location = self:format_stack_frame_info(dbg_info)
	local str=debug.traceback(dbg_cr) or ""
	
	if location and str then
		self:writeln(location)
		self:writeln(str)
	end
	return true
end

-- Print current linenr and filename
function dbgMethods:format_stack_frame_info()
	if not dbg_info.linedefined then return false end
	local path = dbg_info.source:sub(2)
	local fname = (dbg_info.name or string.format("<%s:%d>", path, dbg_info.currentline))	
	return string.format("%s:%d", path, dbg_info.currentline, fname)
end

-- Where functionality
local SOURCE_CACHE = {["<unknown filename>"] = {}}
function dbgMethods:where(dbg_info, context_lines)
	local key = dbg_info.source or "<unknown filename>"
	local source = SOURCE_CACHE[key]

	if not source then
		source = {}
		local filename = dbg_info.source:match("@(.*)")
		--self:writeln (filename)
		if filename then
			for line in io.lines(filename) do table.insert(source, line) end 
		else
			for line in dbg_info.source:gmatch("(.-)\n") do table.insert(source, line) end
		end
		SOURCE_CACHE[key] = source
	end
	if dbg_info.currentline < 1 then dbg_info.currentline =  dbg_info.linedefined end
	if source[dbg_info.currentline] then
		for i = dbg_info.currentline - context_lines, dbg_info.currentline + context_lines do
			local caret = (i == dbg_info.currentline and " => " or "    ")
			local line = source[i]
			if line then self:writeln(i.." "..caret.." "..line) end
		end
	else
		self:writeln("Error: Source file '%s' not found.", dbg_info.source);
	end
	
	return true
end

-- Where Functionallity
-- Print lines from current debugged sourcefile. Defaults to 5 Lines
function dbgMethods:cmd_where(context_lines)
	if not dbg_info then return false end
	return (dbg_info and self:where(debug.getinfo(dbg_cr,0,"nlS"), tonumber(context_lines) or 5))
end

-- Locals functionality - Create a table of all the locally accessible variables.
-- Globals are not included when running the locals command.
function dbgMethods:local_bindings(dbg_cr,offset, include_globals)
	local level = 0
	local func = debug.getinfo(dbg_cr,level).func
	local bindings = {}
	
	-- Retrieve the upvalues
	do local i = 1; while true do
		local name, value = debug.getupvalue(func, i)
		if not name then break end
		bindings[name] = value
		i = i + 1
	end end
	-- Retrieve the locals (overwriting any upvalues)
	do local i = 1; while true do
		local name, value = debug.getlocal(dbg_cr,level, i)
		if not name then break end
		bindings[name] = value
		i = i + 1
	end end
	-- Retrieve the varargs (works in Lua 5.2 and LuaJIT)
	local varargs = {}
	do local i = 1; while true do
		local name, value = debug.getlocal(dbg_cr,level, -i)
		if not name then break end
		self:writeln (varargs[i], value)
		varargs[i] = value
		i = i + 1
	end end
	if #varargs > 0 then bindings["..."] = varargs end
	if include_globals then
		-- In Lua 5.2, you have to get the environment table from the function's locals.
		local env = (_VERSION <= "Lua 5.1" and getfenv(func) or bindings._ENV)
		return setmetatable(bindings, {__index = env or _G})
	else
		return bindings
	end
end

-- Print objects
function dbgMethods:pretty(obj, max_depth)
	if max_depth == nil then max_depth = 4 end
	
	-- Returns true if a table has a __tostring metamethod.
	local function coerceable(tbl)
		local meta = getmetatable(tbl)
		return (meta and meta.__tostring)
	end
	local function recurse(obj, depth)
		if type(obj) == "string" then
			-- Dump the string so that escape sequences are printed.
			return string.format("%q", obj)
		elseif type(obj) == "table" and depth < max_depth and not coerceable(obj) then
			local str = "{"
			for k, v in pairs(obj) do
				local pair = pretty(k, 0).." = "..recurse(v, depth + 1)
				str = str..(str == "{" and pair or ", "..pair)
			end
			return str.."}"
		else
			-- tostring() can fail if there is an error in a __tostring metamethod.
			local success, value = pcall(function() return tostring(obj) end)
			return (success and value or "<!!error in __tostring metamethod!!>")
		end
	end
	
	return recurse(obj, 0)
end

-- Modify vars
function dbgMethods:mutate_bindings(name, value)
	local level = 0 -- Always Zero because its running in the cr.
	-- Set a local.
	do local i = 1; repeat
		local var,val = debug.getlocal(dbg_cr, level, i)
		if name == var then
			self:writeln("Set local ("..name.."="..value..") was ("..name.."="..val..")" )
			return debug.setlocal(dbg_cr, level, i, value)
		end
		i = i + 1
	until var == nil end
	-- Set an upvalue.
	local func = debug.getinfo(dbg_cr,level).func
	do local i = 1; repeat
		local var,val = debug.getupvalue(func, i)
		if name == var then
			self:writeln("Set upvalue ("..name.."="..value..")  was ("..name.."="..val..")")
			return debug.setupvalue(func, i, value)
		end
		i = i + 1
	until var == nil end
	self:writeln("Could not set ("..name.."="..value..")")
	return false
end

-- Show / Edit local variables
function dbgMethods:cmd_locals(options)
	if not dbg_info.linedefined then return false end
	local var_name,var_value=string.match(options or "", "(.*)=(.*)")
	
	self:writeln("Locals:")	
	if var_name then self:mutate_bindings(var_name, var_value) end
	local bindings = self:local_bindings(dbg_cr,0, true)
	-- Get all the variable binding names and sort them
	local keys = {}
	for k, _ in pairs(bindings) do table.insert(keys, k) end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = bindings[k]
		-- Skip the debugger object itself, "(*internal)" values, and Lua 5.2's _ENV object.
		if not rawequal(v, self) and k ~= "_ENV" and not k:match("%(.*%)") then
        	self:writeln(k.." => "..self:pretty(v))
		end
	end
	
	return true
end

-- Specify or remove breakpoints. 
function dbgMethods:cmd_breakpoint(options)
	local action,line_no,file=string.match(options or "", "(%w)%s*([%d%*]*)([%a.%c]*)")
	local currfile = dbg_info.source:match("@(.*)")
	if (action == "a" and file=="") then 
		-- Add a breakpoint to current debugged file
		dbgBreakpoints[#dbgBreakpoints+1]={[currfile]=tonumber(line_no)}
		self:writeln("Added Breakpoint for file ("..currfile.." Line ".. line_no ..")")
	elseif (action == "a" and file~=nil) then
		-- Add a breakpoint to a specific file
		dbgBreakpoints[#dbgBreakpoints+1]={[file]=tonumber(line_no)}
		self:writeln("Added Breakpoint for file ("..file.." Line ".. line_no..")")
	elseif	(action == "c" and line_no=='*') then
		-- Clear all dbgBreakpoints
		dbgBreakpoints={}
		self:writeln("Cleared all Breakpoints")
	elseif (action == "c" and line_no~=nil and file~="") then
		-- Clear a file specific Breakpoint
		for idx,hash in pairs(dbgBreakpoints) do
			for bpfile,bpline in pairs(hash) do
				if (bpfile==file and bpline==tonumber(line_no)) then dbgBreakpoints[idx]=nil; found=true end
			end
		end
		if found then 
			self:writeln("Breakpoint ("..file.." => ".. line_no..") cleared"); found=nil
				else
			self:writeln ("Breakpoint ("..file.." => ".. line_no..") not found")
		end
	elseif (action == "c" and line_no~=nil and file=="") then
		-- clear a breakpoint in current debugged file
		for idx,hash in pairs(dbgBreakpoints) do
			for bpfile,bpline in pairs(hash) do
				if (bpfile==currfile and bpline==tonumber(line_no)) then dbgBreakpoints[idx]=nil; found=true end
			end	
		end
		if found then 
			self:writeln("Breakpoint for file ("..currfile.." => ".. line_no..") cleared"); found=nil
				else
			self:writeln ("Breakpoint ("..currfile.." => ".. line_no..") not found")
		end
	elseif	(action == "l") then
		-- print all breakpoints
		self:writeln ("dbgBreakpoints:")
		for idx,hash in pairs(dbgBreakpoints) do
			for file,line in pairs(hash) do self:writeln (file.." => "..line) end
		end
	end

	return true
end

function dbgMethods:writehelp()
	print("(I) Init{luafile}\n(w) where\n(l) locals{var=val}\n(b) Breakpoint{a|c *|line|file}\n(t) trace\n(s) step\n(S) Step over\n(g) Go \n(q) quit")
end

local function cmd_handler(cmd,param)
	local ok
	if status=="down" and not cmd:match("^[Ihq%.].*$") then return -2 end
	if cmd then 
		if cmd=='t' then dbgMethods:cmd_trace() end
		if cmd=='w' then dbgMethods:cmd_where(5) end
		if cmd=='l' then dbgMethods:cmd_locals(param) end
		if cmd=='q' then ok=-1; status="down" end
		if cmd=='h' then dbgMethods:writehelp() end
		if cmd=='I' then dbgMethods:cmd_init(param) end
		if cmd=='B' then dbgMethods:cmd_breakpoint(param) end
		if cmd=='g' then dbgMethods:cmd_go() end		
		if cmd=='s' then ok=dbgMethods:cr_step("l") end
		if cmd=='S' then ok=dbgMethods:cr_step("r") end
	end
	return ok
end

-- ScitE related code
local function onOutputLn(str,strb)
	local ok
	if type(strb)=="string" then str=strb end
	str=string.sub(str,#dbgPrompt+1)
	local cmd, param=str:match("^([AtIwlsSgq%h])(.*)$")	-- supported Commands
	if cmd then
		ok=cmd_handler(cmd,param)
	elseif not string.match(str,"error") then
		dbgMethods:writeln("Unknown Command: "..str)
	end
	if (ok==-1) then
		dbgMethods:writeln("Quitting")
		scite_OnOutputLine(onOutputLn,true,true)
		return
	elseif(ok==-2) or (ok==false) then
		dbgMethods:writeln("Please Re(I)nit debuggee or (q)uit debugger")
		status="down"	
	elseif (ok==true) and cmd:match("^([sS])(.*)$") then
		dbgMethods:writeln("\n"..dbgMethods:format_stack_frame_info(dbg_info))
	end
	dbgMethods:write (dbgPrompt)
	return(true)
end

function dbgMethods:cmd_init(options)
	luafile=string.match(options, "%s*(.*)")
	if luafile=="" then
		self:writeln("Current Status: "..status)
		self:writeln("Current Debuggee: "..dbg_info.source:sub(2))
		self:writeln("You can specify a lua file here to be used as a debuggee") 
		return false
	end
	self:init(luafile,true)
	return tru
end

-- Init debugee at its first line
function dbgMethods:init(luafile,interactive)
	DBG_INTERACTIVE=interactive or false
	if DBG_INTERACTIVE and not (SCITE_EXTMAN and SCITE_LUA) then
		self:writeln("Enabling interactive Mode requires Extman")
		return false
	end
	self:writeln("Init: Setting debuggee to '"..luafile.."'")
	-- check for Debuggee, use codebugs Path if none has been given 
	if not string.find(luafile,"\\") then luafile=dbgPath..luafile end
	if not os.rename(luafile,luafile) then 
		status="down"
			self:writeln("Init: Debuggee not found '"..luafile.."'")
		return false
	else
		dbg_cr = coroutine.create(loadfile(luafile))
		ok= self:cr_step("crl")
		if status ~= "up" and DBG_INTERACTIVE then
			status="up" ; dbgMethods:write(dbgPrompt)
			-- Interactive: Delegate io to the editors OnOutputLine Callback. 
			if SCITE_LUA and DBG_INTERACTIVE then
			scite_OnOutputLine (onOutputLn)
			end
		end
	end
	return true
end
 
local myDbg = newDebugger("dbge.lua",true) -- true = interactive Mode
--myDbg:cmd_step()
--myDbg:cmd_trace()
--myDbg:cmd_step()
--myDbg:cmd_where()
--myDbg:cmd_locals("marker=35")
--myDbg:cmd_breakpoint("a2bla.lua")
--myDbg:cmd_breakpoint("c2bla.lua")
--myDbg:cmd_breakpoint("a9")
--myDbg:cmd_breakpoint("c9")
--myDbg:cmd_breakpoint(l)
--myDbg:cmd_step()
--myDbg:cmd_trace()
--myDbg:cmd_go()
--myDbg:cmd_locals()
