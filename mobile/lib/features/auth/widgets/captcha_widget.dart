import 'package:flutter/material.dart';

/// Виджет для captcha (stub - заглушка)
/// В реальном приложении здесь будет интеграция с reCAPTCHA или другой системой
class CaptchaWidget extends StatefulWidget {
  final Function(String) onVerified;

  const CaptchaWidget({
    super.key,
    required this.onVerified,
  });

  @override
  State<CaptchaWidget> createState() => _CaptchaWidgetState();
}

class _CaptchaWidgetState extends State<CaptchaWidget> {
  bool _isVerified = false;
  String _captchaToken = 'stub_captcha_token_${DateTime.now().millisecondsSinceEpoch}';

  void _handleVerify() {
    setState(() {
      _isVerified = true;
    });
    widget.onVerified(_captchaToken);
  }

  @override
  Widget build(BuildContext context) {
    // Stub: в реальном приложении здесь будет настоящая captcha
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          // Иконка captcha
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.security, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Подтвердите, что вы не робот',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Captcha (stub)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          if (!_isVerified)
            TextButton(
              onPressed: _handleVerify,
              child: const Text('Проверить'),
            )
          else
            const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
}

