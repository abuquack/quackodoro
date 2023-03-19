-- In this file, we'll have the logic only
local setmetatable = setmetatable
local gears = require("gears")
local mydoro = { mt = {} }

local local_data = {}

local default_properties = {
    focus_duration = 60*60,
    short_rest_duration = 10*60,
    long_rest_duration = 20*60,
    rounds = 3,
    elapsed = 0,
}

local function update(self)
    -- Config
    local focus_duration = local_data.focus_duration
    local short_rest_duration = local_data.short_rest_duration
    local long_rest_duration = local_data.long_rest_duration
    -- local state = self.state

    local function notify(stage)
        if local_data.last_noti ~= stage then
            local_data.last_noti = stage
            self:emit_signal("mydoro::"..stage)
            print("Emitted signal: mydoro::"..stage)
        end
    end
    local stage_remaining = self:remaining()
    local easier_remaining = self:easier_remaining()
    local stages =  {
        { stage_remaining < long_rest_duration,
            "long_rest",
            function()
                return { stage_remaining+1, long_rest_duration }
            end
        },
        { self:easier_remaining()%(short_rest_duration+focus_duration) >= short_rest_duration,
            "focus",
            function()
                return {easier_remaining%(short_rest_duration+focus_duration)-short_rest_duration , focus_duration}
            end },
        { true,
            "short_rest",
            function()
                return {easier_remaining%(short_rest_duration+focus_duration)+1 , short_rest_duration}
            end },
    }
    for _, stage in ipairs(stages) do
        if stage[1] then
            local values = stage[3]()
            self:emit_signal("mydoro::update_values",values[1], values[2], stage[2])
            notify(stage[2])
            return
        else
            -- print("We're not in this stage called "..stage[2])
        end
    end

    print("Hi")
    if stage_remaining < long_rest_duration then
        notify("long_rest")
    else
        if true then
            notify("focus")
        else
            notify("short_rest")
        end
    end
    -- Why did we do this?
    -- the if statements are ugly, and elseif is uglier
end

-- Skip N seconds
function mydoro:pass(N)
    local_data.elapsed = local_data.elapsed+N
    update(self)
end

function mydoro:pass_stage()
    -- self:pass(self:remaining()+1)
    self:pass(self:easier_remaining()+1)
    self.timer:again()
end

function mydoro:remaining()
    local stage_duration = (local_data.focus_duration + local_data.short_rest_duration)*local_data.rounds-local_data.short_rest_duration+local_data.long_rest_duration
    local elapsed = local_data.elapsed or 0
    local total_elapsed = os.time() - local_data.started_at + elapsed
    return stage_duration - total_elapsed%stage_duration
end

function mydoro:easier_remaining()
    if self:remaining() < local_data.long_rest_duration then
        return self:remaining()
    end
    local easier_remaining = self:remaining()-local_data.long_rest_duration+local_data.short_rest_duration
    return easier_remaining%(local_data.short_rest_duration+local_data.focus_duration)
end

function mydoro:toggle()
    local state = local_data.state
    if state ~= 'running' then
        local_data.state = 'running'
        local_data.started_at = os.time()
        self.timer:start()
    else
        local_data.state = 'paused'
        local_data.elapsed = os.time() - local_data.started_at + local_data.elapsed
        self.timer:stop()
    end
end


function mydoro:reset()
    local_data.elapsed = 0
    local_data.started_at = nil
    self.timer:stop()
end

function mydoro.mt:__call(...)
    mydoro.new(...)
end

function mydoro.new(args)
    -- create base widget
    local o = gears.object({
        enable_properties = true,
        enable_auto_signals = true,
        class=mydoro
    })

    -- either arg or default
    print("Creating a new mydoro object")
    for property, default in pairs(default_properties) do
        if args[property] == nil then
            print("Using default value for "..property)
        end
        local_data[property] = args[property] or default
        o[property] = args[property] or default
    end

    print("Elapsed: "..args.elapsed)

    o.state = 'paused'
    o.timer = gears.timer { timeout = 1 }
    o.timer:stop()
    o.timer:connect_signal("timeout", function() update(o) end)
    return o
end

return setmetatable(mydoro, mydoro.mt)
