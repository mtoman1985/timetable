import 'dart:ui';

import 'package:black_hole_flutter/black_hole_flutter.dart';
import 'package:flutter/material.dart' hide Interval;
import 'package:flutter/rendering.dart';

import '../all_day.dart';
import '../date/controller.dart';
import '../date/visible_date_range.dart';
import '../event.dart';
import '../event_provider.dart';
import '../utils.dart';

typedef MultiDateEventHeaderEventBuilder<E extends Event> = Widget Function(
  BuildContext context,
  E event,
  AllDayEventLayoutInfo info,
);

typedef MultiDateEventHeaderBackgroundTapCallback = void Function(
  DateTime date,
);

class MultiDateEventHeader<E extends Event> extends StatelessWidget {
  MultiDateEventHeader({
    Key? key,
    required this.controller,
    required EventProvider<E> eventProvider,
    required this.eventBuilder,
    this.onBackgroundTap,
    this.style = const MultiDateEventHeaderStyle(),
    this.padding = EdgeInsets.zero,
  })  : eventProvider = eventProvider.debugChecked,
        super(key: key);

  final DateController controller;
  final EventProvider<E> eventProvider;
  final MultiDateEventHeaderEventBuilder<E> eventBuilder;

  final MultiDateEventHeaderBackgroundTapCallback? onBackgroundTap;
  final MultiDateEventHeaderStyle style;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _buildContent(constraints.maxWidth),
        ),
      ),
    );
  }

  Widget _buildContent(double width) {
    return ValueListenableBuilder<Interval>(
      valueListenable: controller.map((it) {
        final interval = Interval(
          DateTimeTimetable.dateFromPage(controller.value.floor()),
          DateTimeTimetable.dateFromPage(
                (controller.value + controller.visibleRange.visibleDayCount)
                    .ceil(),
              ) -
              1.milliseconds,
        );
        assert(interval.isValidTimetableDateInterval);
        return interval;
      }),
      builder: (_, visibleDates, __) {
        return ValueListenableBuilder<double>(
          valueListenable: controller,
          builder: (context, page, __) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: onBackgroundTap != null
                ? (details) => _callOnBackgroundTap(details, page, width)
                : null,
            child: _buildEventLayout(context, visibleDates, page),
          ),
        );
      },
    );
  }

  void _callOnBackgroundTap(TapUpDetails details, double page, double width) {
    final tappedCell = details.localPosition.dx /
        width *
        controller.visibleRange.visibleDayCount;
    final date = DateTimeTimetable.dateFromPage((page + tappedCell).floor());
    onBackgroundTap!(date);
  }

  Widget _buildEventLayout(
    BuildContext context,
    Interval visibleDates,
    double page,
  ) {
    assert(visibleDates.isValidTimetableDateInterval);

    return _EventsWidget<E>(
      visibleRange: controller.visibleRange,
      currentlyVisibleDates: visibleDates,
      page: page,
      style: style,
      children: [
        for (final event in eventProvider(visibleDates))
          _EventParentDataWidget<E>(
            key: ValueKey(event.id),
            event: event,
            child: _buildEvent(context, event, page),
          ),
      ],
    );
  }

  Widget _buildEvent(BuildContext context, E event, double page) {
    final visibleDayCount = controller.visibleRange.visibleDayCount;
    final eventStartPage = event.start.page;
    final eventEndPage = event.end.page.ceil();
    final hiddenStartDays = (page - eventStartPage).coerceAtLeast(0);
    return eventBuilder(
      context,
      event,
      AllDayEventLayoutInfo(
        hiddenStartDays: hiddenStartDays,
        hiddenEndDays: (eventEndPage - page - visibleDayCount).coerceAtLeast(0),
      ),
    );
  }
}

/// Defines visual properties for [MultiDateEventHeader] and related widgets.
class MultiDateEventHeaderStyle {
  const MultiDateEventHeaderStyle({this.eventHeight = 24});

  /// Height of a single all-day event.
  final double eventHeight;

  @override
  int get hashCode => hashList([eventHeight]);
  @override
  bool operator ==(Object other) {
    return other is MultiDateEventHeaderStyle &&
        other.eventHeight == eventHeight;
  }
}

class _EventParentDataWidget<E extends Event>
    extends ParentDataWidget<_EventParentData<E>> {
  const _EventParentDataWidget({
    Key? key,
    required this.event,
    required Widget child,
  }) : super(key: key, child: child);

  final E event;

  @override
  Type get debugTypicalAncestorWidgetClass => _EventsWidget;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is _EventParentData<E>);
    final parentData = renderObject.parentData! as _EventParentData<E>;

    if (parentData.event == event) return;

    parentData.event = event;
    final targetParent = renderObject.parent;
    if (targetParent is RenderObject) targetParent.markNeedsLayout();
  }
}

class _EventsWidget<E extends Event> extends MultiChildRenderObjectWidget {
  _EventsWidget({
    required this.visibleRange,
    required this.currentlyVisibleDates,
    required this.page,
    this.style = const MultiDateEventHeaderStyle(),
    required List<_EventParentDataWidget<E>> children,
  }) : super(children: children);

  final VisibleDateRange visibleRange;
  final Interval currentlyVisibleDates;
  final double page;
  final MultiDateEventHeaderStyle style;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EventsLayout<E>(
      visibleRange: visibleRange,
      currentlyVisibleDates: currentlyVisibleDates,
      page: page,
      eventHeight: style.eventHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _EventsLayout<E> renderObject) {
    renderObject
      ..visibleRange = visibleRange
      ..currentlyVisibleDates = currentlyVisibleDates
      ..page = page
      ..eventHeight = style.eventHeight;
  }
}

class _EventParentData<E extends Event>
    extends ContainerBoxParentData<RenderBox> {
  E? event;
}

class _EventsLayout<E extends Event> extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EventParentData<E>>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EventParentData<E>> {
  _EventsLayout({
    required VisibleDateRange visibleRange,
    required Interval currentlyVisibleDates,
    required double page,
    required double eventHeight,
  })   : _visibleRange = visibleRange,
        assert(currentlyVisibleDates.isValidTimetableDateInterval),
        _currentlyVisibleDates = currentlyVisibleDates,
        _page = page,
        _eventHeight = eventHeight;

  VisibleDateRange _visibleRange;
  VisibleDateRange get visibleRange => _visibleRange;
  set visibleRange(VisibleDateRange value) {
    if (_visibleRange == value) return;

    _visibleRange = value;
    markNeedsLayout();
  }

  Interval _currentlyVisibleDates;
  Interval get currentlyVisibleDates => _currentlyVisibleDates;
  set currentlyVisibleDates(Interval value) {
    assert(value.isValidTimetableDateInterval);
    if (_currentlyVisibleDates == value) return;

    _currentlyVisibleDates = value;
    markNeedsLayout();
  }

  double _page;
  double get page => _page;
  set page(double value) {
    if (_page == value) return;

    _page = value;
    markNeedsLayout();
  }

  double _eventHeight;
  double get eventHeight => _eventHeight;
  set eventHeight(double value) {
    if (_eventHeight == value) return;

    _eventHeight = value;
    markNeedsLayout();
  }

  Iterable<E> get events => children.map((child) => child.data<E>().event!);

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _EventParentData<E>) {
      child.parentData = _EventParentData<E>();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0;
  }

  bool _debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw Exception("_EventsLayout doesn't have an intrinsic width.");
      }
      return true;
    }());
    return true;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _parallelEventCount() * eventHeight;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      _parallelEventCount() * eventHeight;

  final _yPositions = <E, int>{};

  @override
  void performLayout() {
    assert(!sizedByParent);

    if (children.isEmpty) {
      size = Size(constraints.maxWidth, 0);
      return;
    }

    _updateEventPositions();
    _setSize();
    _positionEvents();
  }

  void _updateEventPositions() {
    // Remove old events.
    _yPositions.removeWhere((e, _) {
      return e.start.page.floor() >= currentlyVisibleDates.end.page.ceil() ||
          e.end.page.ceil() <= currentlyVisibleDates.start.page;
    });

    // Insert new events.
    final sortedEvents = events
        .where((it) => !_yPositions.containsKey(it))
        .sortedByStartLength();

    Iterable<E> eventsWithPosition(int y) {
      return _yPositions.entries.where((e) => e.value == y).map((e) => e.key);
    }

    outer:
    for (final event in sortedEvents) {
      var y = 0;
      final interval = event.interval.dateInterval;
      while (true) {
        final intersectingEvents = eventsWithPosition(y);
        if (intersectingEvents
            .every((e) => !e.interval.dateInterval.intersects(interval))) {
          _yPositions[event] = y;
          continue outer;
        }

        y++;
      }
    }
  }

  void _setSize() {
    final parallelEvents = _parallelEventCount();
    size = Size(constraints.maxWidth, parallelEvents * eventHeight);
  }

  void _positionEvents() {
    final dateWidth = size.width / visibleRange.visibleDayCount;
    for (final child in children) {
      final event = child.data<E>().event!;
      final dateInterval = event.interval.dateInterval;

      final startPage = dateInterval.start.page;
      final left = ((startPage - page) * dateWidth).coerceAtLeast(0);
      final endPage = dateInterval.end.page.ceilToDouble();
      final right = ((endPage - page) * dateWidth).coerceAtMost(size.width);

      child.layout(BoxConstraints.tightFor(
        width: right - left,
        height: eventHeight,
      ));
      child.data<E>().offset = Offset(left, _yPositions[event]! * eventHeight);
    }
  }

  double _parallelEventCount() {
    int parallelEventsFrom(int page) {
      final startDate = DateTimeTimetable.dateFromPage(page);
      final interval = Interval(
        startDate,
        (startDate + (visibleRange.visibleDayCount - 1).days).atEndOfDay,
      );
      assert(interval.isValidTimetableDateInterval);

      final maxEventPosition = _yPositions.entries
          .where((e) => e.key.interval.intersects(interval))
          .map((e) => e.value)
          .max();
      return maxEventPosition != null ? maxEventPosition + 1 : 0;
    }

    _updateEventPositions();
    final oldParallelEvents = parallelEventsFrom(page.floor());
    final newParallelEvents = parallelEventsFrom(page.ceil());
    final t = page - page.floorToDouble();
    return lerpDouble(oldParallelEvents, newParallelEvents, t)!;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

extension _ParentData on RenderBox {
  _EventParentData<E> data<E extends Event>() =>
      parentData! as _EventParentData<E>;
}
