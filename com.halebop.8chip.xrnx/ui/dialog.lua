-- ui/dialog.lua
-- Main dialog: tabbed container for all 8chip panels.
-- Exposes the global function show_8chip_dialog().

require("ui.waveform_panel")
require("ui.presets_panel")
require("ui.arp_panel")
require("ui.pitch_panel")
require("ui.percussion_panel")
require("ui.modulation_panel")
require("ui.probability_panel")

local dialog = nil  -- holds the open dialog reference

-- Tab labels (index matches panel creation order below)
local TAB_LABELS = {
  "Waveforms",
  "Presets",
  "Arp",
  "Pitch",
  "Drums",
  "Mod",
  "Probability",
}

function show_8chip_dialog()
  -- If already open, bring to front
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  local vb = renoise.ViewBuilder()

  -- Build each panel (all created, only one visible at a time)
  local waveform_panel    = create_waveform_panel(vb)
  local presets_panel     = create_presets_panel(vb)
  local arp_panel         = create_arp_panel(vb)
  local pitch_panel       = create_pitch_panel(vb)
  local percussion_panel  = create_percussion_panel(vb)
  local modulation_panel  = create_modulation_panel(vb)
  local probability_panel = create_probability_panel(vb)

  local panels = {
    waveform_panel,
    presets_panel,
    arp_panel,
    pitch_panel,
    percussion_panel,
    modulation_panel,
    probability_panel,
  }

  -- Show the panel at index idx, hide the rest
  local function show_tab(idx)
    for i, panel in ipairs(panels) do
      panel.visible = (i == idx)
    end
  end

  -- Tab switch bar
  local tab_switch = vb:switch {
    id       = "main_tab_switch",
    width    = 480,
    items    = TAB_LABELS,
    value    = 1,
    notifier = show_tab,
  }

  local content = vb:column {
    margin  = 6,
    spacing = 4,
    tab_switch,
    vb:space { height = 2 },
    waveform_panel,
    presets_panel,
    arp_panel,
    pitch_panel,
    percussion_panel,
    modulation_panel,
    probability_panel,
  }

  dialog = renoise.app():show_custom_dialog("8chip", content)
end
