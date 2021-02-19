
  --==coDebug a "dofile" compatible Debugger that will be loosly enhanced over time==--
   Although the inital idea was to run it within SciTe, it does not depend on it.
  
  It circumvents two problem of scites Luaextension.
    First: Its running in the same Thread. So its not possible to continously loop without blocking scite.
    Second: Currently scite has no equivalent to either io.read() or os.exit()
    Also: It does not require an additional external lua instance and runs within a 'dofile' call.
    How:  A clib called dbghelper injects a lua yield call within Luas internal debug table.
          That way, the debuggee will be yielded on debug events such releasing control back to the steering lua script.
          dbghelper: (http://tset.de/dbghelper/index.html) (Gunnar Zötl <gz@tset.de>)
    With: Scott Lembkes debugger.lua available at https://github.com/slembcke/debugger.lua
           
   Status: Test Prototype - 
   Commands available:
    coDebug> h
    (I) Init{luafile}
    (w) where
    (l) locals{var=val}
    (b) Breakpoint{a|c *|line|file}
    (t) trace
    (s) step
    (S) Step over
    (g) Go 
    (q) quit
    
--------------------
Original dbghelper Readme
--------------------
dbghelper is a module for lua >= 5.1  to aid debugging of lua programs.
It injects a function resumeuntil into the debug table, which can resume a coroutine until a debug event occurs or the coroutine yields or returns.

Documentation
Usage
require "dbghelper"

cr = coroutine.create(function_to_debug)
ok, what = debug.resumeuntil(cr, mask, count, ...) 

Arguments

cr
    coroutine to debug
mask, count
    as for debug.sethook
...
    extra arguments to pass to the coroutine resume function (only use if the coroutine has yielded or on the first call)

Return values

ok
    true if the coroutine can be resumed, false if not
what
    event that caused resumeuntil to return, can be any one of

        'line', 'count', 'call', 'tail call', 'return', 'tail return' or 'yield' if ok is true,
        'return' or 'error' if ok is false.

Notes

    the mask and count arguments can be nil. If both are nil, resumeuntil will just resume the coroutine until it returns, yields or throws an error.
    if an error occurred, the error message is returned as the third return value from resumeuntil
    if ok and what are true and 'yield', the debugged function has yielded and arguments passed to yield are returned as third and following return values from resumeuntil
    if ok and what are false and 'return', the debugged function has returned and any return values are returned as third and following return values from resumeuntil
    if ok is true and what is anything but 'yield', this signals that the corresponding debug hook has been invoked.
    only lua 5.1 will return 'tail return', only lua 5.2 will return 'tail call'.

Look at the included dbg_test.lua for some examples.