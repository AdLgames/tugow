class_name TableProjection
extends RefCounted
## Maps the throw model's unit disc onto the screen the way the design's
## camera sees it: a standing player looking down at an oval table.
##
## The design mock builds this with a CSS 3D plane (perspective 1450px,
## rotateX, origin bottom centre). A rotated circle is an ellipse, so rather
## than port the matrix this projects points through a pinhole camera — which
## gets the same silhouette and, unlike the CSS, lets a die at landing
## position (r, angle) land where the throw resolver actually put it.
##
## `pitch_degrees` keeps the mock's meaning: 90 is edge-on, 58 is the value
## the build brief settled on. (The shipped HTML still had 144, which is past
## edge-on and renders the table inside-out — known issue #1 in the brief.)

var pitch_degrees: float = 58.0
## Camera distance and height, in table radii.
var distance: float = 2.05
var height: float = 1.42
## Focal length in pixels.
var focal: float = 2600.0
## Where the table's centre sits on screen.
var origin: Vector2 = Vector2(960, 760)


func elevation_radians() -> float:
	# The mock's pitch is measured from face-on; the camera's tilt above the
	# table plane is the complement.
	return deg_to_rad(90.0 - pitch_degrees)


## Project a point on the table plane (unit disc, +y away from the viewer)
## to screen space.
func project(point: Vector2) -> Vector2:
	var phi := elevation_radians()
	var sin_phi := sin(phi)
	var cos_phi := cos(phi)
	var y := point.y + distance
	var depth := y * cos_phi + height * sin_phi
	if depth < 0.05:
		depth = 0.05
	var vertical := y * sin_phi - height * cos_phi
	return origin + Vector2(focal * point.x / depth, -focal * vertical / depth)


## How much a die at this position should be scaled: nearer is larger.
func scale_at(point: Vector2) -> float:
	var phi := elevation_radians()
	var depth := (point.y + distance) * cos(phi) + height * sin(phi)
	if depth < 0.05:
		depth = 0.05
	return (focal / depth) / 1000.0


## A projected circle of the given radius, as a closed point list.
func ring(radius: float, segments: int = 96) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(project(Vector2(cos(a), sin(a)) * radius))
	return points


## Same ring, inset or outset by a pixel amount after projection.
func ring_scaled(radius: float, segments: int = 96) -> PackedVector2Array:
	return ring(radius, segments)
