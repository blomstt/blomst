hl.config({
    animations = {
        enabled = true,
    },
})

-- Curves
hl.curve("emphDecel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1.0} } })   -- fast start, long soft landing (things appearing)
hl.curve("emphAccel", { type = "bezier", points = { {0.3, 0.0}, {0.8, 0.15} } })   -- slow start, quick exit (things leaving)
hl.curve("standard",  { type = "bezier", points = { {0.2, 0.0}, {0.0, 1.0} } })    -- general movement
hl.curve("overshot",  { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.06} } })  -- slight bounce past the target
hl.curve("linear",    { type = "bezier", points = { {0.0, 0.0}, {1.0, 1.0} } })

-- Windows
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "overshot", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "emphAccel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "standard" })

-- Layers (eww, rofi, notifications)
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "emphDecel", style = "popin 92%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "emphAccel", style = "popin 95%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "emphDecel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1, bezier = "emphAccel" })

-- Fades
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2, bezier = "emphDecel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "emphAccel" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 2, bezier = "standard" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 2, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2, bezier = "standard" })

-- Border
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "standard" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 60, bezier = "linear", style = "loop" })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "emphDecel", style = "slidefadevert 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "emphDecel", style = "slidefadevert 15%" })
