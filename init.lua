-- Author: Copilot
-- local awful     = require("awful")
local naughty   = require("naughty")
-- local math      = require("math")
-- local string	= require("string")
-- local timer		= timer
local gears 	= require("gears")

local setmetatable = setmetatable
local base = require("wibox.widget.base")
local wi = require("wibox")
-- local cairo = require("lgi").cairo

-- module("awmodoro")
local mydoro = { mt = {} }
local data = setmetatable({}, { __mode = "k" })

local properties = { "width", "height", "short_rest_bg_color", "focus_bg_color", "long_rest_duration", "fg_color", "focus_duration", "short_rest_duration", "long_rest_duration", "rounds", "do_notify"}

local function update(doro)
    -- Config
    local rounds = data[doro].rounds
    local focus_duration = data[doro].focus_duration
    local short_rest_duration = data[doro].short_rest_duration
    local long_rest_duration = data[doro].long_rest_duration
    local state = data[doro].state

    -- Calculated values
    local stage_duration = (focus_duration + short_rest_duration)*rounds-short_rest_duration+long_rest_duration
    local bar = data[doro].bar
    local text = data[doro].text
    local elapsed = data[doro].elapsed or 0
    local total_elapsed = os.time() - data[doro].started_at + elapsed

    -- Early return is paused
    if state == 'paused' then
        data[doro].bar:set_value(elapsed)
        -- Pango markup
        data[doro].text:set_markup_silently("<span color='"..data[doro].fg_color.."'>"..elapsed.."</span>")
        return
    end

    local stage_remaining = stage_duration - total_elapsed%stage_duration
    local function notify(stage)
        if data[doro].last_noti ~= stage then
            if data[doro].do_notify then
                naughty.notify({text=stage.." time!"})
            end
            data[doro].last_noti = stage
            doro:emit_signal("mydoro::"..stage)
            print("Emitted signal: mydoro::"..stage)
        end
    end
    if stage_remaining < long_rest_duration then
        -- data[doro].background_color = data[doro].long_rest_bg_color
        bar:set_background_color(data[doro].long_rest_bg_color)
        stage_remaining = stage_remaining+1 -- Just so it starts at long_rest_duration (e.g. if long rest is 5 minutes, it will start at 5:00, not 4:59)
        bar:set_value(stage_remaining)
        -- Set markup to mm:ss format, color being same as bar background
        text:set_markup_silently("<span color='"..data[doro].long_rest_bg_color.."'>"..math.floor(stage_remaining/60)..":"..string.format("%02d", stage_remaining%60).."</span>")
        bar:set_max_value(long_rest_duration)
        notify("long_rest")
    else
        local easier_remaining = stage_remaining-long_rest_duration+short_rest_duration
        if easier_remaining%(short_rest_duration+focus_duration) >= short_rest_duration then
            -- For both bar and text, to reduce boilerplate, +1 so it starts at focus_duration (e.g. if focus is 25 minutes, it will start at 25:00, not 24:59)
            local shown_value = easier_remaining%(short_rest_duration+focus_duration)-short_rest_duration
            -- doro.color = data[doro].focus_bg_color
            -- data[doro].background_color = data[doro].focus_bg_color
            data[doro].bar:set_background_color(data[doro].focus_bg_color)
            bar:set_value(shown_value)
            -- Set markup to mm:ss format, color being same as bar background, - short_rest_duration to make it finish at 0
            text:set_markup_silently("<span color='"..data[doro].focus_bg_color.."'>"..math.floor(shown_value/60)..":"..string.format("%02d", shown_value%60).."</span>")
            bar:set_max_value(focus_duration)
            notify("focus")
        else
            -- For both bar and text, to reduce boilerplate, +1 so it starts at short_rest_duration (e.g. if short rest is 5 minutes, it will start at 5:00, not 4:59)
            local shown_value = easier_remaining%(short_rest_duration+focus_duration)+1
            -- set markup to mm:ss format, background being same as bar
            text:set_markup_silently("<span color='"..data[doro].short_rest_bg_color.."'>"..math.floor(shown_value/60)..":"..string.format("%02d", shown_value%60).."</span>")
            bar:set_value(shown_value)
            data[doro].bar:set_background_color(data[doro].short_rest_bg_color)
            bar:set_max_value(short_rest_duration)
            notify("short_rest")
        end
    end
    doro:emit_signal("widget::redraw_needed")
end

-- Skip N seconds
function mydoro:pass(N)
    data[self].elapsed = data[self].elapsed+N
    update(self)
end

function mydoro:pass_stage()
    -- Config
    local rounds = data[self].rounds
    local focus_duration = data[self].focus_duration
    local short_rest_duration = data[self].short_rest_duration
    local long_rest_duration = data[self].long_rest_duration
    local state = data[self].state

    -- Calculated values
    local stage_duration = (focus_duration + short_rest_duration)*rounds-short_rest_duration+long_rest_duration
    local bar = data[self].bar
    local text = data[self].text
    local elapsed = data[self].elapsed or 0
    local total_elapsed = os.time() - data[self].started_at + elapsed

    local stage_remaining = stage_duration - total_elapsed%stage_duration
    local easier_remaining = stage_remaining-long_rest_duration+short_rest_duration
    -- If it's focus, skip focus only, not the short rest, nor the long rest
    if stage_remaining < long_rest_duration then
        self:pass(stage_remaining+1)
    else
        local easier_remaining = stage_remaining-long_rest_duration+short_rest_duration
        if easier_remaining%(short_rest_duration+focus_duration) >= short_rest_duration then
            -- Focus
            self:pass(easier_remaining%(short_rest_duration+focus_duration)-short_rest_duration+1)
        else
            -- Short rest
            self:pass(easier_remaining%(short_rest_duration+focus_duration)+1)
        end
    end
    -- again() timer
    data[self].timer:again()
end

function mydoro.draw(doro, wibox, cr, width, height)
    -- cr is: cairo.Context
    -- wibox is: wibox
    -- width is: number, which resembles the width of the wibox
    -- height is: number, which resembles the height of the wibox
    if data[doro].what_to_draw == "text" then
        data[doro].text:draw(wibox, cr, width, height)
    else
        data[doro].bar:draw(wibox, cr, width, height)
    end
end


function mydoro.fit(doro)
    return data[doro].width, data[doro].height
end


function mydoro:remaining()
    local stage_duration = (data[self].focus_duration + data[self].short_rest_duration)*data[self].rounds-data[self].short_rest_duration+data[self].long_rest_duration
    local elapsed = data[self].elapsed or 0
    local total_elapsed = os.time() - data[self].started_at + elapsed
    return stage_duration - total_elapsed%stage_duration
end

function mydoro:easier_remaining()
    local stage_duration = (data[self].focus_duration + data[self].short_rest_duration)*data[self].rounds-data[self].short_rest_duration+data[self].long_rest_duration
    local elapsed = data[self].elapsed or 0
    local total_elapsed = os.time() - data[self].started_at + elapsed
    local stage_remaining = stage_duration - total_elapsed%stage_duration
    local easier_remaining = stage_remaining-data[self].long_rest_duration+data[self].short_rest_duration
    return easier_remaining%(data[self].short_rest_duration+data[self].focus_duration)
end

function mydoro:skip_stage(N)

end
function mydoro:toggle()
    local state = data[self].state
    if state ~= 'running' then
        data[self].state = 'running'
        data[self].started_at = os.time()
        data[self].timer:start()
    else
        data[self].state = 'paused'
        data[self].elapsed = os.time() - data[self].started_at + data[self].elapsed
        data[self].timer:stop()
    end
end

function mydoro:reset()
    data[self].elapsed = 0
    data[self].started_at = nil
    data[self].timer:stop()
end

-- A default for each property
local default_width = 60
local default_height = 100
-- Reddish focus bg color
-- Greenish short rest bg color
-- Blueish long rest bg color
local default_focus_bg_color = "#FF0000"
local default_short_rest_bg_color = "#00FF00"
local default_long_rest_bg_color = "#0000FF"
local default_fg_color = "#FFFFFF"
-- Set default seconds to 60 minutes
local default_focus_duration = 60 * 60
local default_short_rest_duration = 10 * 60
local default_long_rest_duration = 20 * 60
local default_rounds = 3
local default_do_notify = false


function mydoro.new(args)
    local args = args or {}
    local doro = base.make_widget()

    -- Set the default values or provided args values
    local width = args.width or default_width
    local height = args.height or default_height
    local focus_bg_color = args.focus_bg_color or default_focus_bg_color
    local short_rest_bg_color = args.short_rest_bg_color or default_short_rest_bg_color
    local long_rest_bg_color = args.long_rest_bg_color or default_long_rest_bg_color

    local fg_color = args.fg_color or default_fg_color
    local focus_duration = args.focus_duration or default_focus_duration
    local short_rest_duration = args.short_rest_duration or default_short_rest_duration
    local long_rest_duration = args.long_rest_duration or default_long_rest_duration
    local rounds = args.rounds or default_rounds
    local do_notify = args.do_notify or default_do_notify
    local what_to_draw = args.what_to_draw or "text"

    -- Set the widget's data
    local bar = wi.widget.progressbar.new({width=width, height=height})
    bar.color = "#ff93a0"
    local text = wi.widget.textbox()
    text.font = "IBM Plex Sans Bold 12"
    data[doro] = {
        width = width,
        height = height,
        focus_bg_color = focus_bg_color,
        short_rest_bg_color = short_rest_bg_color,
        long_rest_bg_color = long_rest_bg_color,
        fg_color = fg_color,
        focus_duration = focus_duration,
        short_rest_duration = short_rest_duration,
        long_rest_duration = long_rest_duration,
        rounds = rounds,
        do_notify = do_notify,
        bar = bar,
        text = text,
        what_to_draw = what_to_draw,
        timer = gears.timer { timeout = 1 },
        -- User interactions is an array of timestamps where the user either paused or resumed the timer
        elapsed = args.elapsed or 0,
        started_at = nil,
        state = 'stopped', -- Possible values for this property: running, paused, stopped
        last_noti = nil -- Could be focus, short or long
    }

    data[doro].timer:connect_signal("timeout", function()
        update(doro)
    end)
    doro.draw = mydoro.draw
    gears.debug.dump(bar.background_color)
    -- Set the widget's metatable
    setmetatable(doro, { __index = mydoro })

    return doro
end

function mydoro.mt:__call(...)
    mydoro.new(...)
end

return setmetatable(mydoro, mydoro.mt)
