local mydoro = require("mydoro")
local textdoro = { mt = {} }
local beautiful = require("beautiful")
local gears 	= require("gears")

local wi = require("wibox")

local properties_defaults = {
    width = 60,
    height = 100,
    short_rest_fg_color = "#00FF00",
    focus_fg_color = "#FF0000",
    long_rest_fg_color = "#0000FF",
    bg_color = "#FFFFFF",
}


function textdoro.new(args)
    local text = {
        {
        widget = wi.widget.textbox,
        font = args.font or "IBM Plex Mono 12",
        },
        widget = wi.container.background,
        bg = args.bg_color or beautiful.bg_normal,
    }

    -- Inherit from mydoro
    local mydoro_obj = mydoro.new(args)
    setmetatable(text, { __index = mydoro_obj })

    text.timer:connect_signal("timeout", function()
        text:update()
    end)

    return text
end

function text:update()

end


return setmetatable(textdoro, textdoro.mt)
