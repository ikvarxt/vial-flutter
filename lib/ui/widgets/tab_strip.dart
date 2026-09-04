import 'package:flutter/material.dart';

import '../theme.dart';

/// Horizontal, scrollable list of tab titles (QTabWidget header).
class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.labels,
    required this.current,
    required this.onSelected,
  });

  final List<String> labels;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == current ? p.highlight : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: i == current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
