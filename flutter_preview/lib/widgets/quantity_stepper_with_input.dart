import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact quantity stepper with a tappable numeric input box in the
/// middle so users can type an exact quantity instead of only tapping
/// +/− repeatedly.
///
/// Reusable by both the return cart and (optionally) the regular cart.
class QuantityStepperWithInput extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final bool canIncrement;
  final Color? accentColor;

  const QuantityStepperWithInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.canIncrement = true,
    this.accentColor,
  });

  @override
  State<QuantityStepperWithInput> createState() =>
      _QuantityStepperWithInputState();
}

class _QuantityStepperWithInputState extends State<QuantityStepperWithInput> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant QuantityStepperWithInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    final qty = parsed ?? widget.value;
    widget.onChanged(qty);
    setState(() {
      _isEditing = false;
      _controller.text = '$qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Colors.deepOrange;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: accent,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => widget.onChanged(widget.value - 1),
        ),
        GestureDetector(
          onTap: () {
            setState(() => _isEditing = true);
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          },
          child: Container(
            width: 42,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: _isEditing ? accent : Colors.grey[300]!,
                width: _isEditing ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              readOnly: !_isEditing,
              enabled: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.0,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                isDense: true,
              ),
              onSubmitted: (_) => _commit(),
              onEditingComplete: _commit,
              onTapOutside: (_) {
                if (_isEditing) _commit();
              },
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed >= 0) {
                  widget.onChanged(parsed);
                }
              },
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: accent,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: widget.canIncrement
              ? () => widget.onChanged(widget.value + 1)
              : null,
        ),
      ],
    );
  }
}
