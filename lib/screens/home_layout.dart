import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/expense_store.dart';
import '../widgets/home_tiles.dart';

/// One tile on the home screen.
/// x and w count half-columns (8 across the screen).
/// y and h count half-rows (each one is [kHalfRow] pixels tall).
class TileSpec {
  const TileSpec(
    this.kind, {
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final TileKind kind;
  final int x;
  final int y;
  final int w;
  final int h;
}

/// Current layout. Change the numbers here to move or resize a tile.
const homeLayout = <TileSpec>[
  TileSpec(TileKind.profile, x: 0, y: 0, w: 2, h: 1),
  TileSpec(TileKind.balance, x: 0, y: 1, w: 8, h: 2),
  TileSpec(TileKind.accounts, x: 0, y: 3, w: 6, h: 3),
  TileSpec(TileKind.transfer, x: 6, y: 3, w: 2, h: 3),
  TileSpec(TileKind.month, x: 0, y: 6, w: 8, h: 1),
  TileSpec(TileKind.transactions, x: 0, y: 7, w: 8, h: 9),
];

/// The account switcher while the user is scrolling it: full width.
const _accountsOpen = TileSpec(TileKind.accounts, x: 0, y: 3, w: 8, h: 3);

const kHalfRow = 64.0;

class HomeCanvas extends StatefulWidget {
  const HomeCanvas({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<HomeCanvas> createState() => _HomeCanvasState();
}

class _HomeCanvasState extends State<HomeCanvas> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final specs = homeLayout
        .where((t) => !(_expanded && t.kind == TileKind.transfer))
        .map(
          (t) => _expanded && t.kind == TileKind.accounts ? _accountsOpen : t,
        )
        .toList();
    final rows = specs.map((t) => t.y + t.h).reduce(math.max);

    return LayoutBuilder(
      builder: (context, c) {
        final unit = c.maxWidth / 8;
        return SizedBox(
          width: c.maxWidth,
          height: rows * kHalfRow,
          child: Stack(
            children: [
              for (final t in specs)
                Positioned(
                  left: t.x * unit,
                  top: t.y * kHalfRow,
                  width: t.w * unit,
                  height: t.h * kHalfRow,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: buildTile(
                      context,
                      t.kind,
                      widget.store,
                      expanded: _expanded,
                      onExpanded: (v) => setState(() => _expanded = v),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
