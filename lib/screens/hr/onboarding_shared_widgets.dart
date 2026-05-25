import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand Palette
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingColors {
  OnboardingColors._();

  static const Color primary = Color(0xFF540478);
  static const Color primaryLight = Color(0xFF7B2FBE);
  static const Color primarySurface = Color(0xFFF3E8FF);
  static const Color primaryBorder = Color(0xFFD8B4FE);

  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFF86EFAC);

  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFFFBEB);

  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEF2F2);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F5FC);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Input Decoration
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration onboardingInputDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: OnboardingColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: OnboardingColors.primary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: OnboardingColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: OnboardingColors.border, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: OnboardingColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: OnboardingColors.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: OnboardingColors.error, width: 2),
    ),
    filled: true,
    fillColor: OnboardingColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    suffixIcon: suffixIcon,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header Card
// ─────────────────────────────────────────────────────────────────────────────
class StepHeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const StepHeaderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF540478), Color(0xFF7B2FBE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: OnboardingColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Section Container
// ─────────────────────────────────────────────────────────────────────────────
class FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? iconColor;

  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OnboardingColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnboardingColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OnboardingColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? OnboardingColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OnboardingColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: OnboardingColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload Button (single file)
// ─────────────────────────────────────────────────────────────────────────────
class UploadFieldButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final String? uploadedUrl;
  final bool isUploading;
  final bool isRequired;

  const UploadFieldButton({
    super.key,
    required this.label,
    this.hint,
    required this.onPressed,
    this.uploadedUrl,
    this.isUploading = false,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFile = uploadedUrl != null && uploadedUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OnboardingColors.textPrimary,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: OnboardingColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 12,
              color: OnboardingColors.textHint,
            ),
          ),
        ],
        const SizedBox(height: 10),
        InkWell(
          onTap: isUploading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasFile
                  ? OnboardingColors.successSurface
                  : OnboardingColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasFile
                    ? OnboardingColors.successBorder
                    : OnboardingColors.primaryBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (isUploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          OnboardingColors.primary),
                    ),
                  )
                else
                  Icon(
                    hasFile ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    color: hasFile
                        ? OnboardingColors.success
                        : OnboardingColors.primary,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUploading
                        ? 'Uploading…'
                        : hasFile
                            ? 'File uploaded ✓'
                            : 'Tap to choose file (PDF, JPG, PNG)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isUploading
                          ? OnboardingColors.textSecondary
                          : hasFile
                              ? OnboardingColors.success
                              : OnboardingColors.primary,
                    ),
                  ),
                ),
                if (!isUploading)
                  Icon(
                    hasFile ? Icons.edit_outlined : Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: hasFile
                        ? OnboardingColors.success
                        : OnboardingColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-document list tile
// ─────────────────────────────────────────────────────────────────────────────
class DocumentListTile extends StatelessWidget {
  final String name;
  final String uploadedAt;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDelete;

  const DocumentListTile({
    super.key,
    required this.name,
    required this.uploadedAt,
    this.icon = Icons.insert_drive_file_rounded,
    this.iconColor = OnboardingColors.primary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OnboardingColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnboardingColors.primaryBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: OnboardingColors.textPrimary,
          ),
        ),
        subtitle: Text(
          uploadedAt,
          style: const TextStyle(
            fontSize: 11,
            color: OnboardingColors.textSecondary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
          onPressed: onDelete,
          tooltip: 'Remove',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Document Button (multi-upload style)
// ─────────────────────────────────────────────────────────────────────────────
class AddDocumentButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isUploading;
  final Color? color;

  const AddDocumentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isUploading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? OnboardingColors.primary;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isUploading ? null : onPressed,
        icon: isUploading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: c),
              )
            : Icon(Icons.add_circle_outline_rounded, color: c),
        label: Text(
          isUploading ? 'Uploading…' : label,
          style: TextStyle(color: c, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: c, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Banner (registered-user tip, etc.)
// ─────────────────────────────────────────────────────────────────────────────
class InfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;

  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? OnboardingColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive two-column row helper
//   On screens ≥ 640 px it shows [left] and [right] side by side;
//   on smaller screens it stacks them.
// ─────────────────────────────────────────────────────────────────────────────
class ResponsiveRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double breakpoint;

  const ResponsiveRow({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 640,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= breakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 16), right],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section sub-heading (plain text label inside a FormSection)
// ─────────────────────────────────────────────────────────────────────────────
class SubSectionLabel extends StatelessWidget {
  final String text;
  final String? hint;

  const SubSectionLabel(this.text, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: OnboardingColors.textPrimary,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 12,
              color: OnboardingColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}