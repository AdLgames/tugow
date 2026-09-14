@tool
class_name StageView
extends Control

## The main plot: five views of one fit, stepped through by the stage buttons.
##
## Each stage is a different way of looking at the same model at the same
## velocity and strike — onset in time, peaks in frequency, tracking in both,
## the decay fit in log magnitude, and the verification as three traces. The
## velocity slider moves all five, because all five are downstream of the
## contact pulse.
##
## A port of the prototype's main canvas. The axis scales, the log-frequency
## mapping and the −65 dB picking floor are as drawn; what has changed is that
## the modes come from a real `.modal` file and the rejections are the ones the
## loader actually made, rather than hand-authored stand-ins.

const FREQ_LOW := 80.0

## The design's axis stops at 12 kHz, which suited stand-in modes topping out
## at 7 kHz. The shipped ceramic model runs to 20 kHz, and against a fixed axis
## its top five modes pile up against the right edge as one indistinguishable
## stack. The axis follows the model instead, with 12 kHz as its floor so a
## dull object does not get a misleadingly narrow plot.
const FREQ_HIGH_MIN := 12000.0
const FREQ_HIGH_MAX := 24000.0

## Candidate decade gridlines; whichever fall inside the axis get drawn.
const GRID_FREQUENCIES := [100.0, 300.0, 1000.0, 3000.0, 10000.0, 20000.0]

## Samples per column when drawing a waveform as a min/max envelope.
const ENVELOPE_SUBSAMPLES := 24

var state: FitState:
	set(value):
		if state == value:
			return
		if state != null and state.changed.is_connected(queue_redraw):
			state.changed.disconnect(queue_redraw)
		state = value
		if state != null:
			state.changed.connect(queue_redraw)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size.y = 360


# --- axes --------------------------------------------------------------------

func _plot_rect() -> Rect2:
	# Room on the left for dB and Hz numerals, on the bottom for time.
	return Rect2(52.0, 34.0, maxf(size.x - 68.0, 1.0), maxf(size.y - 60.0, 1.0))


## Top of the frequency axis for the loaded model: its highest mode with a
## little headroom, never below the design's 12 kHz.
func _freq_high() -> float:
	if state == null or not state.is_loaded():
		return FREQ_HIGH_MIN
	var highest := 0.0
	for mode in state.model.modes:
		highest = maxf(highest, mode.f)
	return clampf(highest * 1.2, FREQ_HIGH_MIN, FREQ_HIGH_MAX)


## The gridlines that fall inside the current axis.
func _grid_frequencies() -> Array:
	var high := _freq_high()
	var kept := []
	for f in GRID_FREQUENCIES:
		if f > FREQ_LOW and f < high:
			kept.append(f)
	return kept


func _log_position(f: float) -> float:
	var high_value := _freq_high()
	var low := log(FREQ_LOW)
	var high := log(high_value)
	return (log(clampf(f, FREQ_LOW, high_value)) - low) / (high - low)


func _freq_to_x(f: float, rect: Rect2) -> float:
	return rect.position.x + rect.size.x * _log_position(f)


func _freq_to_y(f: float, rect: Rect2) -> float:
	return rect.end.y - rect.size.y * _log_position(f)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ModalTheme.GLASS_DEEP, true)
	if state == null or not state.is_loaded():
		_draw_empty()
		return

	var rect := _plot_rect()
	match state.stage:
		FitState.Stage.ONSET:
			_draw_onset(rect)
		FitState.Stage.PEAKS:
			_draw_peaks(rect)
		FitState.Stage.TRACKING:
			_draw_tracking(rect)
		FitState.Stage.DECAY:
			_draw_decay(rect)
		FitState.Stage.VERIFY:
			_draw_verify(rect)

	_draw_header()


func _draw_empty() -> void:
	var message := "no model loaded"
	if state != null and state.model != null and not state.model.error.is_empty():
		message = state.model.error
	DrawUtil.text(self, ModalTheme.mono(), 10, Vector2(size.x * 0.5, size.y * 0.5),
			message, ModalTheme.GRID_DIM, DrawUtil.Anchor.CENTRE)


func _draw_header() -> void:
	DrawUtil.tracked_text(self, ModalTheme.mono(), 8, Vector2(12, 20),
			str(FitState.STAGE_TITLES[state.stage]).to_upper(), ModalTheme.INK.darkened(0.25), 1.3)
	var note := FitState.stage_note(state.stage)
	var width := DrawUtil.tracked_width(ModalTheme.mono(), 8, note, 0.8)
	DrawUtil.tracked_text(self, ModalTheme.mono(), 8, Vector2(size.x - 12.0 - width, 20),
			note, ModalTheme.GRID_DIM, 0.8)


func _draw_frame(rect: Rect2) -> void:
	draw_rect(rect, ModalTheme.GRID, false, 1.0)


# --- stage 1: onset ----------------------------------------------------------

func _draw_onset(rect: Rect2) -> void:
	_draw_frame(rect)
	var middle := rect.position.y + rect.size.y * 0.5
	var span := rect.size.y * 0.5 - 6.0
	var onset_x := rect.position.x + rect.size.x * 0.13

	# The backoff region: everything before the onset is discarded.
	draw_rect(Rect2(rect.position.x, rect.position.y, onset_x - rect.position.x, rect.size.y),
			Color(ModalTheme.AMBER.r, ModalTheme.AMBER.g, ModalTheme.AMBER.b, 0.05), true)
	draw_line(Vector2(rect.position.x, middle), Vector2(rect.end.x, middle),
			ModalTheme.ZERO_LINE, 1.0)

	var duration := state.display_seconds()
	var peak := state.signal_peak(duration, 600)
	var columns := int(rect.size.x)
	for column in columns + 1:
		var x := rect.position.x + float(column)
		if x < onset_x:
			# Room tone before the strike. Deterministic, so the trace does not
			# crawl between redraws.
			var y := middle + _hash_noise(float(column)) * span * 0.018
			draw_rect(Rect2(x, y, 1.0, 1.0), ModalTheme.INK, true)
			continue
		# Past the onset, min/max per column — one sample per pixel across a
		# multi-second decay is an alias, not a waveform.
		var low := INF
		var high := -INF
		var reach := maxf(rect.end.x - onset_x, 1.0)
		for step in ENVELOPE_SUBSAMPLES:
			var t := (x - onset_x + float(step) / float(ENVELOPE_SUBSAMPLES)) / reach * duration
			var value := state.signal_at(t) / peak
			low = minf(low, value)
			high = maxf(high, value)
		var top := middle - high * span * 0.94
		var bottom := middle - low * span * 0.94
		draw_rect(Rect2(x, top, 1.0, maxf(1.0, bottom - top)), ModalTheme.INK, true)

	DrawUtil.dashed_line(self, Vector2(onset_x, rect.position.y), Vector2(onset_x, rect.end.y),
			ModalTheme.AMBER, 1.0, 3.0, 3.0)
	DrawUtil.text(self, ModalTheme.mono(), 9, Vector2(onset_x + 6.0, rect.position.y + 14.0),
			"onset", ModalTheme.AMBER)
	DrawUtil.text(self, ModalTheme.mono(), 8,
			Vector2(onset_x + 6.0, rect.position.y + 26.0),
			"backoff %.0f dBFS" % FitState.ONSET_FLOOR_DB, ModalTheme.GRID_DIM)

	var right := rect.position.x - 8.0
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(right, middle - span + 3.0),
			"+1.0", ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(right, middle + 3.0),
			"0", ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(right, middle + span + 3.0),
			"−1.0", ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)
	_draw_time_axis(rect, "0 s", "", state.duration_label())


# --- stage 2: peaks ----------------------------------------------------------

func _draw_peaks(rect: Rect2) -> void:
	_draw_frame(rect)
	var db_top := 0.0
	var db_bottom := -90.0
	var y_of := func(db: float) -> float:
		return rect.position.y + rect.size.y * (db_top - db) / (db_top - db_bottom)

	var db := -15.0
	while db >= -90.0:
		var y: float = y_of.call(db)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), ModalTheme.GRID, 1.0)
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x - 8.0, y + 3.0),
				"%d dB" % int(db), ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)
		db -= 15.0

	for f in _grid_frequencies():
		var x := _freq_to_x(f, rect)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), ModalTheme.GRID, 1.0)
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(x, rect.end.y + 14.0),
				_hz_label(f), ModalTheme.GRID_DIM, DrawUtil.Anchor.CENTRE)

	# The picking floor. Anything under it is never a candidate.
	var floor_y: float = y_of.call(FitState.PEAK_FLOOR_DB)
	DrawUtil.dashed_line(self, Vector2(rect.position.x, floor_y), Vector2(rect.end.x, floor_y),
			ModalTheme.RED, 1.0, 4.0, 3.0)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x + 6.0, floor_y - 5.0),
			"picking floor %.0f dB" % FitState.PEAK_FLOOR_DB, ModalTheme.RED)

	# Modes the loader dropped, marked at the ceiling they fell outside.
	_draw_dropped_markers(rect, y_of)

	for i in state.mode_count():
		var mode: ModalModel.Mode = state.model.modes[i]
		var on := state.is_visible_mode(i)
		var level := state.normalised(i)
		var mode_db := 20.0 * log(maxf(level, 1e-6)) / log(10.0)
		var x := _freq_to_x(mode.f, rect)
		var y: float = y_of.call(maxf(mode_db, db_bottom))
		var colour := ModalTheme.AMBER if on else Color(
				ModalTheme.AMBER.r, ModalTheme.AMBER.g, ModalTheme.AMBER.b, 0.18)
		draw_rect(Rect2(x - 1.5, y, 3.0, rect.end.y - y), colour, true)
		draw_circle(Vector2(x, y), 3.0, colour)
		if on:
			DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(x, y - 8.0),
					str(i), ModalTheme.LABEL, DrawUtil.Anchor.CENTRE)


func _draw_dropped_markers(rect: Rect2, y_of: Callable) -> void:
	var ceiling := state.usable_ceiling()
	if ceiling >= _freq_high():
		return
	var x := _freq_to_x(ceiling, rect)
	DrawUtil.dashed_line(self, Vector2(x, rect.position.y), Vector2(x, rect.end.y),
			Color(ModalTheme.RED.r, ModalTheme.RED.g, ModalTheme.RED.b, 0.5), 1.0, 3.0, 4.0)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(x - 5.0, rect.position.y + 12.0),
			"%.1f kHz ceiling" % (ceiling / 1000.0), ModalTheme.RED, DrawUtil.Anchor.RIGHT)
	# Everything the file held above the ceiling, crossed out at the edge.
	var dropped := state.model.modes_in_file - state.mode_count()
	if dropped <= 0:
		return
	var y: float = y_of.call(-40.0)
	var cross := Color(ModalTheme.RED.r, ModalTheme.RED.g, ModalTheme.RED.b, 0.55)
	for n in mini(dropped, 8):
		var cx := rect.end.x - 10.0 - float(n) * 11.0
		if cx <= x:
			break
		draw_line(Vector2(cx - 4.0, y - 4.0), Vector2(cx + 4.0, y + 4.0), cross, 1.0)
		draw_line(Vector2(cx + 4.0, y - 4.0), Vector2(cx - 4.0, y + 4.0), cross, 1.0)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.end.x - 6.0, y - 12.0),
			"%d dropped" % dropped, ModalTheme.RED, DrawUtil.Anchor.RIGHT)


# --- stage 3: tracking -------------------------------------------------------

func _draw_tracking(rect: Rect2) -> void:
	_draw_frame(rect)
	var duration := state.display_seconds()
	var columns := maxi(40, int(rect.size.x / 2.0))
	var column_width := rect.size.x / float(columns) + 0.8

	# Each mode paints a decaying horizontal band; together they are the
	# spectrogram the tracker walks along.
	for column in columns:
		var x := rect.position.x + float(column) * rect.size.x / float(columns)
		var t := float(column) / float(columns) * duration
		for i in state.mode_count():
			var mode: ModalModel.Mode = state.model.modes[i]
			var on := state.is_visible_mode(i)
			var level := state.normalised(i) * exp(-t / mode.tau) * (1.0 if on else 0.12)
			# The cutoff has to sit at or below where the alpha ramp reaches
			# zero, or every band ends in a hard vertical edge partway through
			# its own fade. −70 dB is where the ramp lands, so that is the
			# floor: 10^(−70/20).
			if level < 3.16e-4:
				continue
			var db := 20.0 * log(level) / log(10.0)
			var alpha := clampf((db + 70.0) / 70.0, 0.0, 1.0)
			var y := _freq_to_y(mode.f, rect)
			var band := 7.0
			var tint := ModalTheme.AMBER if on else ModalTheme.TRACE_OFF
			# The vertical falloff either side of the centre line, so bands
			# read as smeared energy rather than as bars.
			for step in 5:
				var offset := (float(step) - 2.0) / 2.0
				var fade := (1.0 - absf(offset)) * alpha * 0.95
				if fade <= 0.0:
					continue
				draw_rect(Rect2(x, y + offset * band - band * 0.25, column_width, band * 0.5),
						Color(tint.r, tint.g, tint.b, fade), true)

	# Where the tracker followed each mode, for as long as it stayed above the
	# tracking floor.
	#
	# Labels are skipped where they would land on the previous one. The design
	# was drawn with eight modes spread over three octaves; a real model packs
	# fourteen into the top one, where log-frequency spacing puts consecutive
	# modes a few pixels apart and every label overprints its neighbour.
	var last_label_y := -INF
	for i in state.mode_count():
		if not state.is_visible_mode(i):
			continue
		var mode: ModalModel.Mode = state.model.modes[i]
		var y := _freq_to_y(mode.f, rect)
		var reach := minf(1.0, mode.tau * 2.4 / duration)
		DrawUtil.dashed_line(self, Vector2(rect.position.x, y),
				Vector2(rect.position.x + rect.size.x * reach, y),
				Color(ModalTheme.INK.r, ModalTheme.INK.g, ModalTheme.INK.b, 0.5), 1.0, 2.0, 4.0)
		if absf(y - last_label_y) < 11.0:
			continue
		last_label_y = y
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x + 5.0, y - 5.0),
				"%.0f" % mode.f, ModalTheme.LABEL)

	for f in _grid_frequencies():
		var y := _freq_to_y(f, rect)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), ModalTheme.GRID, 1.0)
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x - 8.0, y + 3.0),
				_hz_label(f) + " Hz", ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)

	_draw_time_axis(rect, "0 s", "", state.duration_label())


# --- stage 4: decay fit ------------------------------------------------------

func _draw_decay(rect: Rect2) -> void:
	_draw_frame(rect)
	var duration := 0.6
	var y_of := func(db: float) -> float:
		return rect.position.y + rect.size.y * (0.0 - db) / 80.0

	var db := -10.0
	while db >= -80.0:
		var y: float = y_of.call(db)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), ModalTheme.GRID, 1.0)
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x - 8.0, y + 3.0),
				"%d" % int(db), ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)
		db -= 10.0

	for i in state.mode_count():
		var mode: ModalModel.Mode = state.model.modes[i]
		var on := state.is_visible_mode(i)
		var start_db := 20.0 * log(maxf(state.normalised(i), 1e-9)) / log(10.0)
		var points := PackedVector2Array()
		for column in int(rect.size.x) + 1:
			var t := float(column) / rect.size.x * duration
			# A decay that is exponential in amplitude is a straight line in
			# log magnitude; that straightness is what the fit measures.
			var value := start_db - 8.6858896 * (t / mode.tau)
			if value < -80.0:
				break
			points.append(Vector2(rect.position.x + float(column), y_of.call(value)))
		if points.size() > 1:
			draw_polyline(points, ModalTheme.AMBER if on else Color(
					ModalTheme.TRACE_OFF.r, ModalTheme.TRACE_OFF.g, ModalTheme.TRACE_OFF.b, 0.22),
					1.4 if on else 1.0, true)

	_draw_decay_legend(rect, y_of)

	_draw_time_axis(rect, "0 s", "0.3 s", "0.6 s")
	_draw_rotated_label(rect, "log magnitude, dB")


## A fixed legend column on the right with a leader line back to each curve's
## start, rather than annotations sitting on the curves. With fourteen modes
## the labels overprint each other within the first fifth of the plot, which is
## exactly where the curves are most crowded.
func _draw_decay_legend(rect: Rect2, y_of: Callable) -> void:
	var visible: Array[int] = []
	for i in state.mode_count():
		if state.is_visible_mode(i):
			visible.append(i)
	if visible.is_empty():
		return

	var line_height := 12.0
	# With more modes than the column has room for, the legend lists what it
	# can and says how many it left out — silently truncating would misreport
	# the model.
	var capacity := maxi(1, int((rect.size.y - 28.0) / line_height))
	var shown := mini(visible.size(), capacity if visible.size() > capacity else visible.size())
	var truncated := visible.size() - shown

	var legend_x := rect.end.x - 146.0
	var top := rect.position.y + 6.0
	var rows := shown + (1 if truncated > 0 else 0)

	# Leader lines first, so the legend's own backing covers them where they
	# would otherwise run under the text.
	var y := top + 8.0
	for n in shown:
		var i: int = visible[n]
		var start_db := 20.0 * log(maxf(state.normalised(i), 1e-9)) / log(10.0)
		var curve_y: float = y_of.call(start_db)
		draw_line(Vector2(legend_x - 6.0, y - 3.0), Vector2(rect.position.x + 12.0, curve_y),
				Color(ModalTheme.AMBER.r, ModalTheme.AMBER.g, ModalTheme.AMBER.b, 0.3), 1.0)
		y += line_height

	# The backing. Eleven curves and eleven leader lines pass behind this
	# column, and at 8px the text is unreadable over them without it.
	var backing := Rect2(legend_x - 10.0, top, rect.end.x - legend_x + 8.0,
			float(rows) * line_height + 8.0)
	draw_rect(backing, Color(ModalTheme.GLASS_DEEP.r, ModalTheme.GLASS_DEEP.g,
			ModalTheme.GLASS_DEEP.b, 0.88), true)
	draw_rect(backing, ModalTheme.GRID, false, 1.0)

	y = top + 8.0
	for n in shown:
		var i: int = visible[n]
		var mode: ModalModel.Mode = state.model.modes[i]
		draw_rect(Rect2(legend_x - 4.0, y - 5.0, 2.0, 5.0), ModalTheme.AMBER, true)
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(legend_x + 3.0, y),
				"%d   τ %.3f s" % [i, mode.tau], ModalTheme.LABEL)
		y += line_height
	if truncated > 0:
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(legend_x + 3.0, y),
				"+%d more" % truncated, ModalTheme.MUTED)


# --- stage 5: verify ---------------------------------------------------------

func _draw_verify(rect: Rect2) -> void:
	_draw_frame(rect)
	var duration := state.display_seconds()
	var peak := state.signal_peak(duration, 800)
	var lanes := ["original", "resynthesis", "difference ×8"]
	var lane_height := rect.size.y / 3.0

	for lane in lanes.size():
		var middle := rect.position.y + lane_height * (float(lane) + 0.5)
		var span := lane_height * 0.5 - 8.0
		draw_line(Vector2(rect.position.x, middle), Vector2(rect.end.x, middle),
				ModalTheme.GRID, 1.0)

		var colour := ModalTheme.INK
		if lane == 1:
			colour = ModalTheme.AMBER
		elif lane == 2:
			colour = ModalTheme.RED

		# Min/max per column, as in the resynthesis view and for the same
		# reason: over three and a half seconds each pixel spans several
		# hundred cycles of the fundamental, and plotting one sample per column
		# aliases into a moiré that changes whenever the panel is resized.
		for column in int(rect.size.x) + 1:
			var low := INF
			var high := -INF
			for step in ENVELOPE_SUBSAMPLES:
				var t := (float(column) + float(step) / float(ENVELOPE_SUBSAMPLES)) \
						/ rect.size.x * duration
				var base := state.signal_at(t) / peak
				# What a real recording carries that the model does not: a
				# little room tone, and the broadband click of the striker
				# itself, which is contact noise rather than a mode and so is
				# never fitted.
				var noise := _hash_noise(t * 9311.0 + float(lane) * 31.0) * 0.012
				var click := 0.028 * exp(-t / 0.03) * sin(TAU * 9250.0 * t)
				var y := base
				if lane == 0:
					y = base + noise + click
				elif lane == 2:
					y = (noise + click) * 8.0
				low = minf(low, y)
				high = maxf(high, y)
			var top := middle - high * span
			var bottom := middle - low * span
			draw_rect(Rect2(rect.position.x + float(column), top, 1.0, maxf(1.0, bottom - top)),
					colour, true)

		DrawUtil.text(self, ModalTheme.mono(), 8,
				Vector2(rect.position.x + 6.0, rect.position.y + lane_height * float(lane) + 13.0),
				lanes[lane], ModalTheme.RED if lane == 2 else ModalTheme.LABEL)

	_draw_time_axis(rect, "0 s", "", state.duration_label())


# --- shared furniture --------------------------------------------------------

func _draw_time_axis(rect: Rect2, left: String, middle: String, right: String) -> void:
	var y := rect.end.y + 14.0
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x, y), left, ModalTheme.GRID_DIM)
	if not middle.is_empty():
		DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.get_center().x, y), middle,
				ModalTheme.GRID_DIM, DrawUtil.Anchor.CENTRE)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.end.x, y), right,
			ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)


func _draw_rotated_label(rect: Rect2, content: String) -> void:
	draw_set_transform(Vector2(18.0, rect.get_center().y), -PI * 0.5, Vector2.ONE)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2.ZERO, content,
			ModalTheme.GRID_DIM, DrawUtil.Anchor.CENTRE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hz_label(f: float) -> String:
	return "%dk" % int(f / 1000.0) if f >= 1000.0 else "%d" % int(f)


## The prototype's `sin(x * 12.9898) * 43758.5453 % 1` hash, which is the
## standard shader one-liner. Deterministic per column, so the noise floor does
## not shimmer when an unrelated control moves.
func _hash_noise(x: float) -> float:
	return fmod(sin(x * 12.9898) * 43758.5453, 1.0)
