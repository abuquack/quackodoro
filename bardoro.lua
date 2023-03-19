local mydoro = require("mydoro")
local bardoro = { mt = {} }
local beautiful = require("beautiful")
local naughty   = require("naughty")
local gears 	= require("gears")

local wi = require("wibox")

local properties_defaults = {
    forced_width = 60,
    forced_height = 100,
    short_rest_bg_color = "#00FF00",
    focus_bg_color = "#FF0000",
    long_rest_bg_color = "#0000FF",
    fg_color = "#FFFFFF",
}

local function update(bar, stage_remaining, stage_duration, stage)
    bar:set_value(stage_remaining)
    print("Value set to " .. stage_remaining)
    print("Max value set to " .. stage_duration)
    local background_color
    if stage == "focus" then
        background_color = bar.focus_bg_color
    elseif stage == "short_rest" then
        background_color = bar.short_rest_bg_color
    else
        background_color = bar.long_rest_bg_color
    end
    bar:set_background_color(background_color)
    print("Background color set to " .. background_color)
    -- Does lua have switch statements?
    -- Answer: no
    bar:set_max_value(stage_duration)
    -- bg
    bar:emit_signal("widget::redraw_needed")
end


function bardoro.new(args)
    local bar = wi.widget.progressbar {
        forced_width = args.width or properties_defaults.width,
        forced_height = args.height or properties_defaults.height,
        color = "white",
    }
    for property, default in pairs(properties_defaults) do
        bar[property] = args[property] or default
    end
    -- Inherit from mydoro
    print("Elapsed" .. args.elapsed)
    local mydoro_obj = mydoro.new(args)

    setmetatable(bar, { __index = mydoro_obj })

    bar:toggle()
    mydoro_obj:connect_signal("mydoro::update_values", function(_, stage_remaining, stage_duration, stage)
        update(bar, stage_remaining, stage_duration, stage)
    end)
    for _, signal in ipairs({"mydoro::focus", "mydoro::short_rest", "mydoro::long_rest"}) do
        mydoro_obj:connect_signal(signal, function(...)
            bar:emit_signal(signal, ...)
        end)
    end


    return bar
end

function bardoro.mt.__call(...)
    return bardoro.new(...)
end

return setmetatable(bardoro, bardoro.mt)
