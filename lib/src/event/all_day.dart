import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../utils.dart';
import 'builder.dart';
import 'event.dart';

typedef AllDayEventBuilder<E extends Event> = Widget Function(
  BuildContext context,
  E event,
  AllDayEventLayoutInfo info,
);

class DefaultAllDayEventBuilder<E extends Event> extends InheritedWidget {
  const DefaultAllDayEventBuilder({
    required this.builder,
    required Widget child,
  }) : super(child: child);

  final AllDayEventBuilder<E> builder;

  @override
  bool updateShouldNotify(DefaultAllDayEventBuilder oldWidget) =>
      builder != oldWidget.builder;

  static AllDayEventBuilder<E>? of<E extends Event>(BuildContext context) {
    final allDayEventBuilder = context
        .dependOnInheritedWidgetOfExactType<DefaultAllDayEventBuilder<E>>()
        ?.builder;
    if (allDayEventBuilder != null) return allDayEventBuilder;

    final eventBuilder = DefaultEventBuilder.of<E>(context);
    if (eventBuilder != null) {
      return (context, event, info) => eventBuilder(context, event);
    }

    return null;
  }
}

/// Information about how an all-day event was laid out.
@immutable
class AllDayEventLayoutInfo {
  const AllDayEventLayoutInfo({
    required this.hiddenStartDays,
    required this.hiddenEndDays,
  })   : assert(hiddenStartDays >= 0),
        assert(hiddenEndDays >= 0);

  final double hiddenStartDays;
  final double hiddenEndDays;

  @override
  bool operator ==(dynamic other) {
    return other is AllDayEventLayoutInfo &&
        hiddenStartDays == other.hiddenStartDays &&
        hiddenEndDays == other.hiddenEndDays;
  }

  @override
  int get hashCode => hashValues(hiddenStartDays, hiddenEndDays);
}

class AllDayEventBackgroundPainter extends CustomPainter {
  const AllDayEventBackgroundPainter({
    required this.info,
    required this.color,
    this.borderRadius = 0,
  });

  final AllDayEventLayoutInfo info;
  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _getPath(size, info, borderRadius),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant AllDayEventBackgroundPainter oldDelegate) {
    return info != oldDelegate.info ||
        color != oldDelegate.color ||
        borderRadius != oldDelegate.borderRadius;
  }
}

/// A modified [RoundedRectangleBorder] that morphs to triangular left and/or
/// right borders if not all of the event is currently visible.
class AllDayEventBorder extends ShapeBorder {
  const AllDayEventBorder({
    required this.info,
    this.side = BorderSide.none,
    this.borderRadius = 0,
  });

  final AllDayEventLayoutInfo info;
  final BorderSide side;
  final double borderRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return AllDayEventBorder(
      info: info,
      side: side.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(
      Size(rect.width - side.width * 2, rect.height - side.width * 2),
      info,
      borderRadius,
    ).shift(Offset(side.width, side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _getPath(rect.size, info, borderRadius);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // For some reason, when we paint the background in this shape directly, it
    // lags while scrolling. Hence, we only use it to provide the outer path
    // used for clipping.
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is AllDayEventBorder &&
        other.info == info &&
        other.side == side &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => hashValues(info, side, borderRadius);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'RoundedRectangleBorder')}($side, $borderRadius)';
}

Path _getPath(Size size, AllDayEventLayoutInfo info, double radius) {
  final maxTipWidth = size.height / 4;
  final leftTipWidth = info.hiddenStartDays.coerceAtMost(1) * maxTipWidth;
  final rightTipWidth = info.hiddenEndDays.coerceAtMost(1) * maxTipWidth;

  final leftTipBase = info.hiddenStartDays > 0
      ? math.min(leftTipWidth + radius, size.width - radius)
      : leftTipWidth + radius;
  final rightTipBase = info.hiddenEndDays > 0
      ? math.max(size.width - rightTipWidth - radius, radius)
      : size.width - rightTipWidth - radius;

  final tipSize = Size.square(radius * 2);

  // no tip:   0      ≈  0°
  // full tip: PI / 4 ≈ 45°
  final leftTipAngle = math.pi / 2 - math.atan2(size.height / 2, leftTipWidth);
  final rightTipAngle =
      math.pi / 2 - math.atan2(size.height / 2, rightTipWidth);

  return Path()
    ..moveTo(leftTipBase, 0)
    // Right top
    ..arcTo(
      Offset(rightTipBase - radius, 0) & tipSize,
      math.pi * 3 / 2,
      math.pi / 2 - rightTipAngle,
      false,
    )
    // Right tip
    ..arcTo(
      Offset(rightTipBase + rightTipWidth - radius, size.height / 2 - radius) &
          tipSize,
      -rightTipAngle,
      2 * rightTipAngle,
      false,
    )
    // Right bottom
    ..arcTo(
      Offset(rightTipBase - radius, size.height - radius * 2) & tipSize,
      rightTipAngle,
      math.pi / 2 - rightTipAngle,
      false,
    )
    // Left bottom
    ..arcTo(
      Offset(leftTipBase - radius, size.height - radius * 2) & tipSize,
      math.pi / 2,
      math.pi / 2 - leftTipAngle,
      false,
    )
    // Left tip
    ..arcTo(
      Offset(leftTipBase - leftTipWidth - radius, size.height / 2 - radius) &
          tipSize,
      math.pi - leftTipAngle,
      2 * leftTipAngle,
      false,
    )
    // Left top
    ..arcTo(
      Offset(leftTipBase - radius, 0) & tipSize,
      math.pi + leftTipAngle,
      math.pi / 2 - leftTipAngle,
      false,
    );
}