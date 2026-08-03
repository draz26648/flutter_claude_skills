---
name: performance
description: Flutter performance rules — const constructors, RepaintBoundary placement, builder constructors for lists, image cache sizing, and keeping work out of build methods. Use this whenever implementing a list or grid, loading images, writing animations, investigating jank or dropped frames, or when any build method starts doing real work. Trigger it proactively on list and image code rather than waiting for a performance complaint, since the fixes are nearly free at authoring time and expensive to retrofit once the widget tree is built around the problem.
---

# Performance

## Build methods

`build()` runs often. It allocates the widget tree and nothing else.

Never inside `build()`: network calls, JSON parsing, sorting or filtering a large list,
`DateTime.now()` formatting in a loop, regex compilation, or creating a controller.
Move computation to the Cubit, memoize the result, and let build read it.

**`const` wherever possible.** A `const` widget is not rebuilt and not re-allocated. Turn
on `prefer_const_constructors` in the lint rules so this is enforced rather than
remembered.

**Extract widgets rather than helper methods.** A `Widget _buildHeader()` rebuilds with
the parent every time. A separate `const HeaderWidget()` does not. This is the most
common and most impactful structural fix in a Flutter codebase.

## Lists

Always `ListView.builder` or `ListView.separated` — never `ListView(children: [...])` for
anything that is not a short fixed list, because the non-builder form constructs every
child immediately regardless of visibility.

Provide `itemExtent` when the row height is known. It lets the framework skip layout for
off-screen items and makes scroll-to-index instant instead of linear.

Give items stable `ValueKey`s so reordering moves elements rather than rebuilding them.

For long lists, `addAutomaticKeepAlives: false` and `addRepaintBoundaries: false` when
items are simple — the defaults help complex items and cost memory on simple ones.

## Repaint boundaries

`RepaintBoundary` isolates a subtree so its repaints do not force neighbours to repaint.
Worth adding around: an animating element inside static content, a video or camera
preview, a chart that updates independently, a list item with its own animation.

Not worth adding everywhere. Each boundary is a separate layer with memory cost. Add
them where the repaint rainbow in DevTools shows something flashing that should not be.

## Images

Always set `cacheWidth` or `cacheHeight` on network and asset images. Without it a
2000px image decodes at full size to fill a 100px avatar, holding roughly 16MB of memory
for something that needs 40KB. On a scrolling list of avatars this is the difference
between a smooth list and an out-of-memory crash on a mid-range Android device.

```dart
Image.network(url, cacheWidth: (100 * devicePixelRatio).round())
```

Use `cached_network_image` for anything loaded repeatedly, and always provide a
placeholder sized identically to the final image so the layout does not jump.

## Animations

Prefer implicit animations (`AnimatedContainer`, `AnimatedOpacity`) for simple state
transitions. Use `AnimationController` when the animation needs to be interruptible,
reversible, or driven by a gesture.

Animate with `AnimatedBuilder` and a `child` parameter so the static subtree is built
once rather than every frame.

Never animate `Opacity` on a large subtree — it forces a saveLayer. Use `FadeTransition`
or `AnimatedOpacity`, which are optimized for this.

## Profiling

Profile in profile mode. Debug mode numbers are meaningless — the assertions and lack of
AOT compilation make everything several times slower.

In DevTools: the timeline for frames over 16ms, the repaint rainbow for unnecessary
repaints, and the memory view for image cache growth during scrolling.

Measure before optimizing. The bottleneck is regularly not where it seems, and a
restructure done on a guess costs a day and changes nothing.

## Common mistakes

- `setState` on a whole screen when one small widget changed.
- `Opacity(opacity: 0)` to hide something. Use `Visibility` or `Offstage` — an invisible
  widget at zero opacity still lays out and paints.
- Rebuilding a `ScrollController` or `TextEditingController` in `build()`. They belong in
  `initState` and need disposing.
