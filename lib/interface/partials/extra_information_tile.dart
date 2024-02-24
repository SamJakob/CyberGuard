import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:flutter/material.dart';

typedef ExtraInformationTileChanged<T> = Future<void> Function(T value);

class ExtraInformationTile<T> extends StatefulWidget {
  final bool isEditing;
  final String title;
  final String description;
  final T value;
  final ExtraInformationTileChanged<T>? onChanged;

  /// Optionally, a label to use if the value is true. This is also used as
  /// a label for [max].
  final String? labelIfTrue;

  /// Optionally, a label to use if the value is false. This is also used as
  /// a label for [min].
  final String? labelIfFalse;

  /// Optionally, a color to use if the value is true. This is also used to
  /// highlight the label for [max].
  final Color? colorIfTrue;

  /// Optionally, a color to use if the value is false. This is also used to
  /// highlight the label for [min].
  final Color? colorIfFalse;

  /// Optionally, a maximum limit for the value. This is ignored if [T] is not
  /// comparable.
  final T? max;

  /// Optionally, a minimum limit for the value. This is ignored if [T] is not
  /// comparable.
  final T? min;

  const ExtraInformationTile({
    super.key,
    required this.isEditing,
    required this.title,
    required this.description,
    required this.value,
    this.onChanged,
    this.labelIfTrue,
    this.labelIfFalse,
    this.colorIfTrue,
    this.colorIfFalse,
    this.max,
    this.min,
  });

  @override
  State<ExtraInformationTile<T>> createState() => _ExtraInformationTileState();
}

class _ExtraInformationTileState<T> extends State<ExtraInformationTile<T>> {
  late T _value;
  bool _isLoading = false;

  @override
  initState() {
    super.initState();
    _value = widget.value;
  }

  Future<void> save<U>(final U newValue) async {
    if (U != T) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.onChanged != null) {
        await widget.onChanged!(newValue as T);
      }
      _value = newValue as T;
    } catch (_) {}

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(final BuildContext context) {
    if (widget.isEditing) {
      if (T == bool) return _renderSwitch();
      if (T == int) return _renderSlider();
    }

    return ListTile(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(widget.description),
      trailing: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: _renderValue(),
      ),
    );
  }

  Widget _renderValue() {
    if (_value is bool) {
      return _value as bool
          ? Text(
              widget.labelIfTrue ?? "YES",
              style: TextStyle(
                fontSize: 24,
                color: widget.colorIfTrue ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          : Text(
              widget.labelIfFalse ?? "NO",
              style: TextStyle(
                fontSize: 24,
                color: widget.colorIfFalse ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
            );
    }

    return Text(
      widget.value.toString(),
      style: const TextStyle(
        fontSize: 24,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Renders a slider for a numeric value.
  Widget _renderSlider() {
    return ListTile(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        children: [
          Text(widget.description),
          Row(
            children: [
              Text(
                "${widget.min.toString()}${widget.labelIfFalse != null ? " (${widget.labelIfFalse})" : ""}",
              ),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                      sliderTheme: const SliderThemeData(
                    showValueIndicator: ShowValueIndicator.always,
                  )),
                  child: Slider(
                    divisions:
                        (widget.max as int? ?? 5) - (widget.min as int? ?? 1),
                    value: (_value as int? ?? 1).toDouble(),
                    min: (widget.min as int? ?? 1).toDouble(),
                    max: (widget.max as int? ?? 5).toDouble(),
                    onChanged: (final value) async {
                      await save(value.toInt());
                    },
                  ),
                ),
              ),
              Text(
                "${widget.max.toString()}${widget.labelIfTrue != null ? " (${widget.labelIfTrue})" : ""}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renders a switch for a boolean value.
  Widget _renderSwitch() {
    if (T != bool) {
      throw Exception("Cannot render a switch for a non-boolean value.");
    }

    return ListTile(
      onTap: () async {
        await save(!(_value as bool));
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(widget.description),
      trailing: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ApolloLoadingSpinner(
                size: 32,
              ),
            )
          : Switch(
              value: _value as bool,
              onChanged: (final bool newValue) async {
                await save(newValue);
              },
            ),
    );
  }
}
