--- debugee test
local marker=23
gl_var=42
local a=35
local g=46

local function dgfn(h)
   local x=234
   print(x)
   return(h)
end

print("a="..a)
print("dbgfn:".. dgfn(88))
print("globalvar:"..gl_var)
print("g="..g)
print("marker="..marker)