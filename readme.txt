
SciTE-Debug 
    was initially created in 2007 by Steve Donovan. It featured GDB and LUA Debugging components.
    Later on, it was extended by Todd Wegner /  David Nichols and others by quite some means and slept some time in the deeps.
    Since it works quite well i decided to patch it up for Lua53 and SciTE and provide it here for anyone interested.

Codebug
	Debugging lua Scripts ran within Scites Lua Subsystem required a second instance and a helper script
	like RemDebug or MobDebug.Codebug uses Gunnar Zötls lua clib called dbghelper paired with Scott Lembke's
	debugger.lua to debug lua scripts using (SciTE's) internal lua instance only with no other dependencies.
