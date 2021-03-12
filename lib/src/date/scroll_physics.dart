import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'date_page_view.dart';

// Inspired by [PageScrollPhysics]
class DateScrollPhysics extends ScrollPhysics {
  const DateScrollPhysics(this.controller, {ScrollPhysics? parent})
      : super(parent: parent);

  final DateController controller;

  @override
  DateScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return DateScrollPhysics(controller, parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position is! MultiDateScrollPosition) {
      throw ArgumentError(
        'DateScrollPhysics must be used with MultiDateScrollPosition.',
      );
    }

    // If we're out of range and not headed back in range, defer to the parent
    // ballistics, which should put us back in range at a page boundary.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final pixelsToPages =
        controller.visibleRange.visibleDayCount / position.viewportDimension;
    final targetPage = controller.visibleRange.getTargetPageForCurrent(
      position.page,
      controller.firstDayOfWeek,
      velocity: velocity * pixelsToPages,
      tolerance: Tolerance(
        distance: tolerance.distance * pixelsToPages,
        time: tolerance.time,
        velocity: tolerance.velocity * pixelsToPages,
      ),
    );
    final target = position.pageToPixels(targetPage);

    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
