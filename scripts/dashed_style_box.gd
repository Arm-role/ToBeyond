@tool
class_name DashedStyleBox
extends StyleBox

## Rounded rectangle with a dashed border, like CSS `border: Npx dashed`.
## Used for the draft's dashed shop frame, tabs and empty slots.

@export var bg_color: Color = Color(0, 0, 0, 0)
@export var border_color: Color = Color.WHITE
@export var border_width: float = 3.0
@export var dash: float = 9.0
@export var gap: float = 0.0
@export var corner_radius: float = 12.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var half := border_width * 0.5
	var pts := _rounded_rect(rect.grow(-half), maxf(0.0, corner_radius - half))
	if bg_color.a > 0.0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([bg_color]))
	if border_width <= 0.0 or border_color.a <= 0.0:
		return
	var drawing := true
	var remain := dash
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var seg_len := a.distance_to(b)
		var t := 0.0
		while t < seg_len - 0.001:
			var step := minf(remain, seg_len - t)
			if drawing:
				RenderingServer.canvas_item_add_line(to_canvas_item, a.lerp(b, t / seg_len), a.lerp(b, (t + step) / seg_len), border_color, border_width)
			t += step
			remain -= step
			if remain <= 0.001:
				drawing = not drawing
				remain = dash if drawing else gap


func _rounded_rect(r: Rect2, radius: float) -> PackedVector2Array:
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(r.size.x - radius, radius), -PI * 0.5],
		[r.position + Vector2(r.size.x - radius, r.size.y - radius), 0.0],
		[r.position + Vector2(radius, r.size.y - radius), PI * 0.5],
		[r.position + Vector2(radius, radius), PI],
	]
	const STEPS := 6
	for c in corners:
		for s in STEPS + 1:
			var ang: float = c[1] + (PI * 0.5) * float(s) / float(STEPS)
			pts.append(c[0] + Vector2(cos(ang), sin(ang)) * radius)
	return pts
