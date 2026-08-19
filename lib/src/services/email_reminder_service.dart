import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailBatchResult {
  final int total;
  final int successCount;
  final int failedCount;
  final List<String> errorMessages;

  EmailBatchResult({
    required this.total,
    required this.successCount,
    required this.failedCount,
    required this.errorMessages,
  });
}

class EmailReminderService {
  static const String defaultSender = 'isa.vesit@ves.ac.in';
  static const String _prefAppPasswordKey = 'isa_email_app_password';
  static const String _prefSenderEmailKey = 'isa_email_sender_address';

  // Fallback placeholder - can be configured in app
  static const String _fallbackAppPassword = '';

  static Future<String> getSenderEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefSenderEmailKey) ?? defaultSender;
  }

  static Future<String> getAppPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAppPasswordKey) ?? _fallbackAppPassword;
  }

  static Future<void> saveEmailCredentials({
    required String sender,
    required String appPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSenderEmailKey, sender.trim());
    await prefs.setString(_prefAppPasswordKey, appPassword.trim());
  }

  /// Resolve member email address by lookup from Members table
  static Future<String?> resolveMemberEmail({
    required String memberIdOrEmail,
    String? fallbackEmail,
  }) async {
    final trimmed = memberIdOrEmail.trim();
    if (trimmed.contains('@')) return trimmed;
    if (fallbackEmail != null && fallbackEmail.contains('@')) return fallbackEmail.trim();

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('Members')
          .select('Email Id')
          .eq('ISA Login ID', trimmed)
          .maybeSingle();

      if (res != null && res['Email Id'] != null) {
        final em = res['Email Id'].toString().trim();
        if (em.contains('@')) return em;
      }
    } catch (_) {}

    return null;
  }

  /// Sends an Overdue Component Return Email Notice
  static Future<bool> sendDueReminderEmail({
    required String toEmail,
    required String memberName,
    required String transactionId,
    required String issueDate,
    required String expectedReturnDate,
    required List<String> componentNames,
  }) async {
    final sender = await getSenderEmail();
    final password = await getAppPassword();

    if (password.isEmpty) {
      throw Exception('Please set your Google App Password in Settings (⚙️) first.');
    }

    final smtpServer = gmail(sender, password);
    final componentsListHtml = componentNames.map((c) => '<li><strong>$c</strong></li>').join('');

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f4f6f9; margin: 0; padding: 20px; color: #1e293b; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.08); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #19335A, #0f172a); padding: 28px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 20px; letter-spacing: 0.5px; font-weight: 700; }
    .header p { margin: 6px 0 0 0; font-size: 13px; color: #94a3b8; }
    .badge { display: inline-block; background-color: #fee2e2; color: #b91c1c; font-size: 11px; font-weight: 700; padding: 4px 12px; border-radius: 20px; margin-top: 14px; text-transform: uppercase; letter-spacing: 0.8px; border: 1px solid #fecaca; }
    .body { padding: 28px 24px; }
    .greeting { font-size: 16px; font-weight: 600; color: #0f172a; margin-bottom: 12px; }
    .message { font-size: 14px; line-height: 1.6; color: #475569; margin-bottom: 20px; }
    .card { background-color: #f8fafc; border-radius: 8px; border: 1px solid #e2e8f0; padding: 18px; margin-bottom: 20px; }
    .component-box { background-color: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 12px 16px; margin: 12px 0; }
    .component-box ul { margin: 0; padding-left: 20px; font-size: 13.5px; color: #1e293b; }
    .component-box li { margin-bottom: 4px; }
    .alert-box { background-color: #fff7ed; border-left: 4px solid #ea580c; padding: 12px 16px; border-radius: 4px; font-size: 13px; color: #9a3412; line-height: 1.5; margin-bottom: 20px; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }
    .footer strong { color: #64748b; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>ISA VESIT INVENTORY</h1>
      <p>Hardware Lab & Component Management Portal</p>
      <div class="badge">OVERDUE RETURN REMINDER</div>
    </div>
    <div class="body">
      <div class="greeting">Dear $memberName,</div>
      <p class="message">
        This is an automated reminder from the <strong>ISA-VESIT Inventory Team</strong> regarding hardware component(s) issued to you which are currently pending return.
      </p>

      <div class="card">
        <table style="width: 100%; border-collapse: collapse; font-size: 13px;">
          <tr>
            <td style="padding: 5px 0; color: #64748b; font-weight: 600;">Transaction ID:</td>
            <td style="padding: 5px 0; color: #0f172a; font-weight: 600; text-align: right;">#$transactionId</td>
          </tr>
          <tr>
            <td style="padding: 5px 0; color: #64748b; font-weight: 600;">Issue Date:</td>
            <td style="padding: 5px 0; color: #0f172a; font-weight: 600; text-align: right;">$issueDate</td>
          </tr>
          <tr>
            <td style="padding: 5px 0; color: #64748b; font-weight: 600;">Expected Due Date:</td>
            <td style="padding: 5px 0; color: #dc2626; font-weight: 700; text-align: right;">$expectedReturnDate</td>
          </tr>
        </table>

        <div style="margin-top: 14px; font-weight: 600; font-size: 12.5px; color: #475569;">Issued Component(s):</div>
        <div class="component-box">
          <ul>
            $componentsListHtml
          </ul>
        </div>
      </div>

      <div class="alert-box">
        <strong>Action Required:</strong> Please return the borrowed hardware component(s) to the ISA Lab at the earliest to ensure availability for other members and avoid penalty fines as per ISA-VESIT Lab policy.
      </div>

      <p style="font-size: 12px; color: #64748b; font-style: italic;">
        * Note: If you have already returned these component(s) or handed them back to the lab coordinators, kindly ignore this reminder.
      </p>
    </div>
    <div class="footer">
      <strong>ISA-VESIT</strong> &bull; Vivekananda Education Society's Institute of Technology<br>
      For queries, reach us at <a href="mailto:isa.vesit@ves.ac.in" style="color: #0284c7; text-decoration: none;">isa.vesit@ves.ac.in</a>
    </div>
  </div>
</body>
</html>
''';

    final message = Message()
      ..from = Address(sender, 'ISA VESIT INVENTORY')
      ..recipients.add(toEmail.trim())
      ..subject = '[ISA-VESIT INVENTORY] Reminder: Pending Component Return (#$transactionId)'
      ..html = htmlContent;

    try {
      final sendReport = await send(message, smtpServer);
      return sendReport.toString().isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  /// Sends a Fine Payment Notice Email
  static Future<bool> sendFineNoticeEmail({
    required String toEmail,
    required String memberName,
    required String fineId,
    required String reason,
    required double amount,
    required String issueDate,
  }) async {
    final sender = await getSenderEmail();
    final password = await getAppPassword();

    if (password.isEmpty) {
      throw Exception('Please set your Google App Password in Settings (⚙️) first.');
    }

    final smtpServer = gmail(sender, password);

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f4f6f9; margin: 0; padding: 20px; color: #1e293b; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.08); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #19335A, #0f172a); padding: 28px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 20px; letter-spacing: 0.5px; font-weight: 700; }
    .header p { margin: 6px 0 0 0; font-size: 13px; color: #94a3b8; }
    .badge { display: inline-block; background-color: #fee2e2; color: #b91c1c; font-size: 11px; font-weight: 700; padding: 4px 12px; border-radius: 20px; margin-top: 14px; text-transform: uppercase; letter-spacing: 0.8px; border: 1px solid #fecaca; }
    .body { padding: 28px 24px; }
    .greeting { font-size: 16px; font-weight: 600; color: #0f172a; margin-bottom: 12px; }
    .message { font-size: 14px; line-height: 1.6; color: #475569; margin-bottom: 20px; }
    .amount-card { background: linear-gradient(135deg, #fee2e2, #fef2f2); border: 1px solid #fca5a5; border-radius: 8px; padding: 20px; text-align: center; margin-bottom: 20px; }
    .amount-title { font-size: 12px; font-weight: 700; color: #991b1b; text-transform: uppercase; letter-spacing: 0.8px; }
    .amount-value { font-size: 32px; font-weight: 900; color: #b91c1c; margin: 6px 0 0 0; }
    .card { background-color: #f8fafc; border-radius: 8px; border: 1px solid #e2e8f0; padding: 18px; margin-bottom: 20px; }
    .alert-box { background-color: #fff7ed; border-left: 4px solid #ea580c; padding: 12px 16px; border-radius: 4px; font-size: 13px; color: #9a3412; line-height: 1.5; margin-bottom: 20px; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }
    .footer strong { color: #64748b; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>ISA VESIT INVENTORY</h1>
      <p>Hardware Lab & Component Management Portal</p>
      <div class="badge">PENDING FINE PAYMENT NOTICE</div>
    </div>
    <div class="body">
      <div class="greeting">Dear $memberName,</div>
      <p class="message">
        This is a formal notification from the <strong>ISA-VESIT Inventory Council</strong> regarding an outstanding penalty / fine record associated with your account.
      </p>

      <div class="amount-card">
        <div class="amount-title">Outstanding Fine Amount</div>
        <div class="amount-value">&#8377; ${amount.toStringAsFixed(0)}</div>
      </div>

      <div class="card">
        <table style="width: 100%; border-collapse: collapse; font-size: 13px;">
          <tr>
            <td style="padding: 5px 0; color: #64748b; font-weight: 600;">Fine Record ID:</td>
            <td style="padding: 5px 0; color: #0f172a; font-weight: 600; text-align: right;">#$fineId</td>
          </tr>
          <tr>
            <td style="padding: 5px 0; color: #64748b; font-weight: 600;">Date Recorded:</td>
            <td style="padding: 5px 0; color: #0f172a; font-weight: 600; text-align: right;">$issueDate</td>
          </tr>
          <tr>
            <td style="padding: 5px 0; color: #64748b; font-weight: 600;">Reason / Remarks:</td>
            <td style="padding: 5px 0; color: #0f172a; font-weight: 600; text-align: right;">$reason</td>
          </tr>
        </table>
      </div>

      <div class="alert-box">
        <strong>Action Required:</strong> Please clear the pending fine amount with the ISA-VESIT Lab in-charges at your earliest convenience to restore regular component borrowing privileges.
      </div>

      <p style="font-size: 12px; color: #64748b; font-style: italic;">
        * Note: If you have already cleared or settled this fine with the lab coordinators, kindly disregard this notice.
      </p>
    </div>
    <div class="footer">
      <strong>ISA-VESIT</strong> &bull; Vivekananda Education Society's Institute of Technology<br>
      For queries or payment receipts, reach us at <a href="mailto:isa.vesit@ves.ac.in" style="color: #0284c7; text-decoration: none;">isa.vesit@ves.ac.in</a>
    </div>
  </div>
</body>
</html>
''';

    final message = Message()
      ..from = Address(sender, 'ISA VESIT INVENTORY')
      ..recipients.add(toEmail.trim())
      ..subject = '[ISA-VESIT INVENTORY] Notice: Pending Fine Payment (₹${amount.toStringAsFixed(0)})'
      ..html = htmlContent;

    try {
      final sendReport = await send(message, smtpServer);
      return sendReport.toString().isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  /// App Password & Email Settings Config Dialog
  static Future<void> showEmailConfigDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSender = await getSenderEmail();
    final currentPass = await getAppPassword();

    final senderCtrl = TextEditingController(text: currentSender);
    final passCtrl = TextEditingController(text: currentPass);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: Color(0xff19335A)),
            const SizedBox(width: 8),
            Text(
              'Email Service Settings',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xff19335A),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your 16-character Google Workspace App Password for "isa.vesit@ves.ac.in" to send automated due & fine notices directly from the app.',
                style: GoogleFonts.lato(fontSize: 12.5, color: isDark ? const Color(0xff94A3B8) : Colors.grey[700]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: senderCtrl,
                style: GoogleFonts.lato(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Sender Email Address',
                  hintText: 'isa.vesit@ves.ac.in',
                  filled: true,
                  fillColor: isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: GoogleFonts.lato(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Google App Password',
                  hintText: '16-character app password (e.g. xxxx xxxx xxxx xxxx)',
                  filled: true,
                  fillColor: isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff19335A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (senderCtrl.text.isNotEmpty) {
                await saveEmailCredentials(
                  sender: senderCtrl.text,
                  appPassword: passCtrl.text,
                );
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email settings updated successfully!'),
                      backgroundColor: Color(0xff15803D),
                    ),
                  );
                }
              }
            },
            child: Text('Save Password', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
