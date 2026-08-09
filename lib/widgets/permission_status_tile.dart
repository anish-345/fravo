import 'package:flutter/material.dart';

/// A compact tile that shows whether a specific Android permission is granted.
/// Tapping it calls [onTap] to open the relevant settings page.
class PermissionStatusTile extends StatelessWidget {
  const PermissionStatusTile({
    super.key,
    required this.label,
    required this.isGranted,
    required this.onTap,
  });

  final String label;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isGranted ? const Color(0xFFE6FFED) : const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isGranted
                ? const Color(0xFF68D391)
                : const Color(0xFFFC8181),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isGranted ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: isGranted
                  ? const Color(0xFF38A169)
                  : const Color(0xFFE53E3E),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isGranted
                      ? const Color(0xFF276749)
                      : const Color(0xFF9B2C2C),
                ),
              ),
            ),
            if (!isGranted)
              const Text(
                'Tap to grant →',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE53E3E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (isGranted)
              const Text(
                'Granted ✓',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF38A169),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
