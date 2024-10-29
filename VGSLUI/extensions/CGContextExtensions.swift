// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics

import VGSLFundamentals

extension CGContext {
  public func inSeparateGState(_ block: Action) {
    saveGState()
    block()
    restoreGState()
  }

  /// Draws a non-convex polygon with rounded corners and fills it with a specified color.
  ///
  /// This method takes a series of points defining a non-convex polygon and renders it onto the
  /// current graphics context
  /// with rounded corners. The corners are rounded with the specified radius, and the entire shape
  /// is filled with the provided color.
  ///
  /// - Parameters:
  ///   - points: An array of `CGPoint` representing the vertices of the non-convex polygon. The
  /// points should be ordered in a
  ///             way that consecutive points define the edges of the polygon. The polygon is
  /// automatically closed from the
  ///             last point back to the first.
  ///   - cornerRadius: A `CGFloat` indicating the radius for rounding the corners of the polygon.
  /// The radius should not exceed
  ///                   half the length of the shortest edge to avoid overlapping arcs.
  ///   - backgroundColor: A `Color` to use for filling the polygon. This color will be applied to
  /// the entire interior
  ///                      of the shape, following the rounding of the corners.
  public func drawCloud(
    points: [CGPoint],
    cornerRadius: CGFloat,
    backgroundColor: Color
  ) {
    guard points.count >= 3 else { return }

    let path = BezierPath()

    for i in 0..<(points.count) {
      let currentPoint = points[i]
      let nextPoint = points[(i + 1) % (points.count)]
      let afterNextPoint = points[(i + 2) % (points.count)]

      guard !arePointsCollinear(p1: currentPoint, p2: nextPoint, p3: afterNextPoint) else {
        continue
      }
      // In the code below, we make a rounded line from a right angle. To do this, we find the
      // maximum possible radius, the point lying on the angle bisector, and the angles for the
      // corresponding rounding.
      let vector1 = CGVector(currentPoint, nextPoint)
      let vector2 = CGVector(nextPoint, afterNextPoint)

      let cornerRadius: CGFloat = min(cornerRadius, vector1.length / 2, vector2.length / 2)
      let lineEnd = CGPoint(
        x: nextPoint.x - vector1.normalized.dx * cornerRadius,
        y: nextPoint.y - vector1.normalized.dy * cornerRadius
      )
      path.addLine(to: lineEnd)
      let cornerCenter = calculatePointOnBisector(
        vertex: nextPoint,
        pointOnLine1: currentPoint,
        pointOnLine2: afterNextPoint,
        dx: cornerRadius,
        dy: cornerRadius
      )

      let clockwise = vector1.isClockwised(vector2)
      let startAngle =
        if vector1.dy.isApproximatelyEqualTo(0, withAccuracy: 1e-3) {
          if cornerCenter.y > currentPoint.y {
            -Double.pi / 2
          } else {
            Double.pi / 2
          }
        } else {
          if cornerCenter.x > currentPoint.x {
            -Double.pi
          } else {
            0.0
          }
        }
      var endAngle: Double = (startAngle + Double.pi * 2 + (clockwise ? .pi / 2 : -.pi / 2))
        .truncatingRemainder(dividingBy: Double.pi * 2)
      endAngle = endAngle > .pi ? endAngle - 2 * .pi : endAngle

      #if os(iOS)
      path.addArc(
        withCenter: cornerCenter,
        radius: cornerRadius,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: clockwise
      )
      #endif
    }
    addPath(path.cgPath)
    setFillColor(backgroundColor.cgColor)
    fillPath()
  }
}

func calculatePointOnBisector(
  vertex: CGPoint,
  pointOnLine1: CGPoint,
  pointOnLine2: CGPoint,
  dx: CGFloat,
  dy: CGFloat
) -> CGPoint {
  let vector1 = CGVector(vertex, pointOnLine1).normalized
  let vector2 = CGVector(vertex, pointOnLine2).normalized

  return CGPoint(
    x: vertex.x + vector1.dx * dx + vector2.dx * dy,
    y: vertex.y + vector1.dy * dx + vector2.dy * dy
  )
}

func arePointsCollinear(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Bool {
  let vector1 = CGVector(p1, p2)
  let vector2 = CGVector(p2, p3)
  return vector1.crossProductMagnitude(vector2).isApproximatelyEqualTo(0)
}
