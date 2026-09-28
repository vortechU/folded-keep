class_name FoldMath
## Pure fold geometry. Grab point G, pointer P → fold line is the perpendicular bisector of G–P.
## The normal points toward the flap (the side containing G).


static func line_point(g: Vector2, p: Vector2) -> Vector2:
	return (g + p) * 0.5


static func normal(g: Vector2, p: Vector2) -> Vector2:
	return (g - p).normalized()


## > 0 on the flap side, <= 0 on the landing side.
static func side(x: Vector2, m: Vector2, n: Vector2) -> float:
	return (x - m).dot(n)


static func mirror(x: Vector2, m: Vector2, n: Vector2) -> Vector2:
	return x - 2.0 * (x - m).dot(n) * n
