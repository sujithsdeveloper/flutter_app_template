import 'package:flutter/material.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';

class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      activeColor: ColorConstants.forestGreen,
      checkColor: Colors.white,
      side: const BorderSide(color: ColorConstants.borderGrey, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      value: value,
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
