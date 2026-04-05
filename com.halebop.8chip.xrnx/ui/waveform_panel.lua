-- ui/waveform_panel.lua
-- Module 1: Waveform Studio
-- Generates mathematical waveforms into the selected instrument's sample slot.

local gen = require("waveforms.generators")

local WAVEFORM_NAMES = {
  "Sine", "Square (50%)", "Pulse", "Sawtooth", "Triangle", "Noise", "FM"
}
local SAMPLE_RATES       = { 8000, 11025, 22050, 44100 }
local SAMPLE_RATE_LABELS = { "8000 Hz (lo-fi)", "11025 Hz", "22050 Hz", "44100 Hz (full)" }
local BIT_DEPTHS         = { 8, 16, 32 }
local BIT_DEPTH_LABELS   = { "8-bit", "16-bit", "32-bit" }
local LOOP_MODES         = { "forward", "ping_pong", "off" }
local LOOP_MODE_LABELS   = { "Forward", "Ping-Pong", "Off" }

-- Panel width constant used for layout
local W = 480

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function get_prefs()
  return renoise.tool().preferences
end

local function build_frames(prefs)
  local t  = prefs.waveform_type.value
  local nf = prefs.num_frames.value
  if t == 1 then
    return gen.generate_sine(nf)
  elseif t == 2 then
    return gen.generate_square(nf)
  elseif t == 3 then
    return gen.generate_pulse(nf, prefs.duty_pct.value / 100.0)
  elseif t == 4 then
    return gen.generate_sawtooth(nf)
  elseif t == 5 then
    return gen.generate_triangle(nf)
  elseif t == 6 then
    return gen.generate_noise(nf)
  elseif t == 7 then
    return gen.generate_fm(nf,
      prefs.fm_ratio_x10.value / 10.0,
      prefs.fm_mod_x10.value   / 10.0)
  end
end

local preview_note_active = false

local function stop_preview_note(instr_idx, sample_idx, track_idx)
  if preview_note_active then
    pcall(function()
      renoise.song():trigger_sample_note_off(instr_idx, sample_idx, track_idx, 48)
    end)
    preview_note_active = false
  end
end

-- ---------------------------------------------------------------------------
-- Public: create_waveform_panel(vb)
-- Returns a column view ready to be embedded in the main dialog.
-- ---------------------------------------------------------------------------
function create_waveform_panel(vb)
  local prefs = get_prefs()

  -- Clamp all stored indices to valid popup/chooser ranges
  if prefs.waveform_type.value < 1 or prefs.waveform_type.value > #WAVEFORM_NAMES then
    prefs.waveform_type.value = 1
  end
  if prefs.sample_rate_idx.value < 1 or prefs.sample_rate_idx.value > #SAMPLE_RATES then
    prefs.sample_rate_idx.value = 4
  end
  if prefs.bit_depth_idx.value < 1 or prefs.bit_depth_idx.value > #BIT_DEPTHS then
    prefs.bit_depth_idx.value = 3
  end
  if prefs.loop_mode_idx.value < 1 or prefs.loop_mode_idx.value > #LOOP_MODES then
    prefs.loop_mode_idx.value = 1
  end

  -- Track which rows need show/hide based on waveform type
  local function refresh_visibility()
    local t        = prefs.waveform_type.value
    local is_pulse = (t == 3)
    local is_fm    = (t == 7)
    vb.views["wf_duty_row"].visible = is_pulse
    vb.views["wf_fm_row"].visible   = is_fm
  end

  -- Generate frames and write into instrument slot 1
  local function do_generate()
    local song  = renoise.song()
    local instr = song.selected_instrument
    if not instr then
      renoise.app():show_error("8chip: No instrument selected.")
      return
    end
    gen.ensure_sample_slot(instr)
    local sr      = SAMPLE_RATES[prefs.sample_rate_idx.value]
    local bd      = BIT_DEPTHS[prefs.bit_depth_idx.value]
    local lm      = LOOP_MODES[prefs.loop_mode_idx.value]
    local frames  = build_frames(prefs)
    local name    = WAVEFORM_NAMES[prefs.waveform_type.value]
    instr.samples[1].name = "8chip  -  " .. name
    gen.write_to_buffer(instr, 1, sr, bd, lm, frames)
  end

  -- Generate into slot 1 silently, then trigger a preview note
  local function do_preview()
    local song      = renoise.song()
    local instr     = song.selected_instrument
    local instr_idx = song.selected_instrument_index
    if not instr then return end

    gen.ensure_sample_slot(instr)
    local sr     = SAMPLE_RATES[prefs.sample_rate_idx.value]
    local frames = build_frames(prefs)
    -- Write at 32-bit for preview regardless of UI setting (quality)
    gen.write_to_buffer(instr, 1, sr, 32, "forward", frames)

    local track_idx = gen.find_sequencer_track()

    -- Stop any previous preview note first
    stop_preview_note(instr_idx, 1, track_idx)

    preview_note_active = true
    renoise.song():trigger_sample_note_on(instr_idx, 1, track_idx, 48, 1.0, false)

    -- Schedule note-off after 1.5 s (timer fires once, then removes itself)
    local function note_off_timer()
      stop_preview_note(instr_idx, 1, track_idx)
      renoise.tool():remove_timer(note_off_timer)
    end
    renoise.tool():add_timer(note_off_timer, 1500)
  end

  -- ---------------------------------------------------------------------------
  -- Build the view
  -- ---------------------------------------------------------------------------
  local panel = vb:column {
    id      = "panel_waveform",
    width   = W,
    spacing = 6,
    margin  = 8,

    -- Section header
    vb:text {
      text  = "Waveform Studio",
      font  = "bold",
      style = "strong",
    },
    vb:text {
      text  = "Generate a mathematical waveform into the selected instrument (sample slot 1).",
      style = "disabled",
    },

    vb:space { height = 4 },

    -- Waveform type
    vb:row {
      spacing = 8,
      vb:text  { text = "Waveform", width = 90 },
      vb:popup {
        id    = "wf_type_popup",
        width = 180,
        items = WAVEFORM_NAMES,
        value = prefs.waveform_type.value,
        notifier = function(idx)
          prefs.waveform_type.value = idx
          refresh_visibility()
        end,
      },
    },

    -- Duty cycle row (Pulse only)
    vb:row {
      id      = "wf_duty_row",
      visible = (prefs.waveform_type.value == 3),
      spacing = 8,
      vb:text { text = "Duty Cycle", width = 90 },
      vb:slider {
        id    = "wf_duty_slider",
        width = 160,
        min   = 5,
        max   = 95,
        value = prefs.duty_pct.value,
        notifier = function(v)
          prefs.duty_pct.value = math.floor(v)
          vb.views["wf_duty_label"].text = tostring(math.floor(v)) .. "%"
        end,
      },
      vb:text { id = "wf_duty_label", text = prefs.duty_pct.value .. "%" },
    },

    -- FM controls row (FM only)
    vb:column {
      id      = "wf_fm_row",
      visible = (prefs.waveform_type.value == 7),
      spacing = 4,
      vb:row {
        spacing = 8,
        vb:text { text = "Op Ratio", width = 90 },
        vb:slider {
          id    = "wf_fm_ratio_slider",
          width = 160,
          min   = 5,
          max   = 160,
          value = prefs.fm_ratio_x10.value,
          notifier = function(v)
            prefs.fm_ratio_x10.value = math.floor(v)
            vb.views["wf_fm_ratio_label"].text =
              string.format("%.1f", math.floor(v) / 10.0)
          end,
        },
        vb:text {
          id   = "wf_fm_ratio_label",
          text = string.format("%.1f", prefs.fm_ratio_x10.value / 10.0),
        },
        vb:text { text = "(mod/carrier ratio)", style = "disabled" },
      },
      vb:row {
        spacing = 8,
        vb:text { text = "Mod Index", width = 90 },
        vb:slider {
          id    = "wf_fm_mod_slider",
          width = 160,
          min   = 0,
          max   = 100,
          value = prefs.fm_mod_x10.value,
          notifier = function(v)
            prefs.fm_mod_x10.value = math.floor(v)
            vb.views["wf_fm_mod_label"].text =
              string.format("%.1f", math.floor(v) / 10.0)
          end,
        },
        vb:text {
          id   = "wf_fm_mod_label",
          text = string.format("%.1f", prefs.fm_mod_x10.value / 10.0),
        },
        vb:text { text = "(0=sine, higher=richer)", style = "disabled" },
      },
    },

    vb:space { height = 2 },

    -- Sample rate
    vb:row {
      spacing = 8,
      vb:text  { text = "Sample Rate", width = 90 },
      vb:popup {
        id    = "wf_sr_popup",
        width = 180,
        items = SAMPLE_RATE_LABELS,
        value = prefs.sample_rate_idx.value,
        notifier = function(idx)
          prefs.sample_rate_idx.value = idx
        end,
      },
    },

    -- Bit depth
    vb:row {
      spacing = 8,
      vb:text    { text = "Bit Depth", width = 90 },
      vb:chooser {
        id    = "wf_bd_chooser",
        items = BIT_DEPTH_LABELS,
        value = prefs.bit_depth_idx.value,
        notifier = function(idx)
          prefs.bit_depth_idx.value = idx
        end,
      },
    },

    -- Loop mode
    vb:row {
      spacing = 8,
      vb:text    { text = "Loop Mode", width = 90 },
      vb:chooser {
        id    = "wf_loop_chooser",
        items = LOOP_MODE_LABELS,
        value = prefs.loop_mode_idx.value,
        notifier = function(idx)
          prefs.loop_mode_idx.value = idx
        end,
      },
    },

    -- Frame count
    vb:row {
      spacing = 8,
      vb:text     { text = "Frames", width = 90 },
      vb:valuebox {
        id    = "wf_frames_box",
        min   = 2,
        max   = 65536,
        value = prefs.num_frames.value,
        notifier = function(v)
          prefs.num_frames.value = v
        end,
      },
      vb:text {
        text  = "  pow-of-2 recommended  -  256 ~ C4 at 68kHz",
        style = "disabled",
      },
    },

    vb:space { height = 6 },

    -- Action buttons
    vb:row {
      spacing = 8,
      vb:button {
        text   = "Preview",
        width  = 110,
        notifier = do_preview,
      },
      vb:button {
        text   = "Generate into Selected Instrument",
        width  = 260,
        notifier = do_generate,
      },
    },

    vb:text {
      text  = "Preview plays C4 for 1.5 s via the first sequencer track.",
      style = "disabled",
    },

    -- -----------------------------------------------------------------------
    -- NES Authentic Samples section
    -- Loads real APU recordings bundled in data/nes_samples/.
    -- -----------------------------------------------------------------------
    vb:space { height = 10 },
    vb:text { text = "NES Authentic Samples", font = "bold", style = "strong" },
    vb:text {
      text  = "Load actual single-cycle waveforms recorded from NES APU hardware.\n"
           .. "These replace the math generator and set the correct loop + base note.",
      style = "disabled",
    },
    vb:space { height = 4 },

    vb:row {
      spacing = 8,
      vb:text { text = "Waveform", width = 90 },
      vb:popup {
        id    = "wf_nes_chooser",
        width = 200,
        items = {
          "Square (50% duty)",
          "Pulse 25%",
          "Pulse 12.5%  (thinnest)",
          "Triangle (staircase)",
          "Noise (LFSR loop)",
        },
        value = 1,
      },
    },
    vb:row {
      spacing = 8,
      vb:button {
        text  = "Load NES Sample into Selected Instrument",
        width = 300,
        notifier = function()
          local song  = renoise.song()
          local instr = song.selected_instrument
          if not instr then
            renoise.app():show_error("8chip: No instrument selected.")
            return
          end
          local NES_KEYS = {
            "nes_square", "nes_pulse_25", "nes_pulse_12",
            "nes_triangle", "nes_noise",
          }
          local idx = vb.views["wf_nes_chooser"].value
          local key = NES_KEYS[idx]
          if gen.load_nes_sample(instr, key) then
            renoise.app():show_status("8chip: NES authentic sample loaded.")
          end
        end,
      },
    },
  }

  return panel
end
