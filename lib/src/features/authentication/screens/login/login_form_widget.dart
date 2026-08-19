import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final supabase = Supabase.instance.client;

  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();

  late final Emailcontroller emailGet;

  bool isTermsAccepted = true;
  bool isRememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    emailGet = Get.isRegistered<Emailcontroller>()
        ? Get.find<Emailcontroller>()
        : Get.put(Emailcontroller());

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? true;
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final terms = prefs.getBool('terms_accepted') ?? true;

      if (mounted) {
        setState(() {
          isRememberMe = rememberMe;
          isTermsAccepted = terms;
          if (rememberMe && savedEmail != null && savedEmail.isNotEmpty) {
            emailcontroller.text = savedEmail;
            if (savedPassword != null && savedPassword.isNotEmpty) {
              passwordcontroller.text = savedPassword;
            }
          }
        });
      }

      // Check current Supabase session
      final session = supabase.auth.currentSession;
      if (session?.user.email != null) {
        emailGet.emailget.value = session!.user.email!;
      }
    } catch (_) {}
  }

  Future<void> emailsignin() async {
    final email = emailcontroller.text.trim();
    final password = passwordcontroller.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your registered email address.")),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your password.")),
      );
      return;
    }

    if (!isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please accept the terms and conditions to proceed.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        emailGet.emailget.value = email;

        // Handle Remember Me persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', email);
        await prefs.setBool('remember_me', isRememberMe);
        await prefs.setBool('terms_accepted', isTermsAccepted);

        if (isRememberMe) {
          await prefs.setString('saved_email', email);
          await prefs.setString('saved_password', password);
        } else {
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }

        emailGet.mailchecker();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid login credentials. Please try again.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: ${e.toString().replaceAll('Exception:', '').trim()}"),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: CAppTheme.cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email Label & Input
          Text(
            "Email Address",
            style: GoogleFonts.montserrat(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1),
              ),
            ),
            child: TextField(
              controller: emailcontroller,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: accentColor),
                hintText: "e.g. member@ves.ac.in",
                hintStyle: GoogleFonts.lato(
                  fontSize: 13,
                  color: isDark ? const Color(0xff64748B) : Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Password Label & Input
          Text(
            "Password",
            style: GoogleFonts.montserrat(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1),
              ),
            ),
            child: TextField(
              controller: passwordcontroller,
              obscureText: _obscurePassword,
              onSubmitted: (_) => emailsignin(),
              style: GoogleFonts.lato(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: accentColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: secondaryText,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                hintText: "Enter your account password",
                hintStyle: GoogleFonts.lato(
                  fontSize: 13,
                  color: isDark ? const Color(0xff64748B) : Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Remember Me & Forgot Password Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Remember Me Checkbox
              InkWell(
                onTap: () {
                  setState(() {
                    isRememberMe = !isRememberMe;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: isRememberMe,
                        activeColor: accentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: BorderSide(
                          color: isDark ? const Color(0xff64748B) : const Color(0xff94A3B8),
                        ),
                        onChanged: (bool? val) {
                          setState(() {
                            isRememberMe = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Remember me',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xffCBD5E1) : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),

              // Forgot Password Link
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _showForgotPasswordSheet,
                child: Text(
                  "Forgot Password?",
                  style: GoogleFonts.lato(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Terms & Conditions Checkbox Row
          InkWell(
            onTap: () {
              setState(() {
                isTermsAccepted = !isTermsAccepted;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: isTermsAccepted,
                    activeColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(
                      color: isDark ? const Color(0xff64748B) : const Color(0xff94A3B8),
                    ),
                    onChanged: (bool? val) {
                      setState(() {
                        isTermsAccepted = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'I agree to ',
                        style: GoogleFonts.lato(
                          fontSize: 12.5,
                          color: secondaryText,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showTermsAndConditions,
                        child: Text(
                          'Terms & Conditions',
                          style: GoogleFonts.lato(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sign-In Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: isDark ? 0 : 2,
              ),
              onPressed: _isLoading ? null : emailsignin,
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isDark ? const Color(0xff080E1A) : Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Sign In to Inventory",
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordSheet() {
    final resetEmailController = TextEditingController(text: emailcontroller.text);
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = CAppTheme.isDark(context);
          final primaryText = CAppTheme.primaryTextColor(context);
          final secondaryText = CAppTheme.secondaryTextColor(context);
          final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: isDark ? const Color(0xff334155) : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Reset Password",
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your ISA member email address and we'll send you a password recovery link.",
                    style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1E293B) : const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1),
                      ),
                    ),
                    child: TextField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.lato(fontSize: 14, color: primaryText),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: accentColor),
                        hintText: "Enter your registered email",
                        hintStyle: GoogleFonts.lato(
                          fontSize: 13,
                          color: isDark ? const Color(0xff64748B) : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSending
                          ? null
                          : () async {
                              final email = resetEmailController.text.trim();
                              if (email.isEmpty) return;
                              setModalState(() => isSending = true);
                              try {
                                await supabase.auth.resetPasswordForEmail(email);
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Password reset email sent! Check your inbox."),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Failed: ${e.toString()}"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                setModalState(() => isSending = false);
                              }
                            },
                      child: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              "Send Reset Link",
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTermsAndConditions() {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? const Color(0xff334155) : Colors.transparent,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Terms and Conditions",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '1. Objective\n'
                'The purpose of these guidelines is to provide a clear understanding of the rules and procedures for the ISA-VESIT inventory system.\n\n'
                '2. Issuance of Components\n'
                '● Eligibility: Only students who are currently enrolled for ISA Memberships are eligible to borrow components.\n'
                '● Issuance Procedure:\n'
                '  ○ Components will be issued based on availability and necessity.\n'
                '  ○ A record of issued components will be maintained by the ISA Council.\n\n'
                '3. Student Responsibilities\n'
                '● Care: Students are responsible for the proper care and handling of the components.\n'
                '● Usage: Components must be used only for their intended educational or project purposes.\n'
                '● Return: Components must be returned by the due date specified at the time of issuance.\n'
                '● Modification: Modification of the components is not allowed.\n'
                '● Damage: No damage is allowed. Students will have to pay the entire amount if the component is damaged.\n'
                '● Loss: If a component is lost, the student is responsible for it and has to pay the entire amount of the component as listed below.\n'
                '● Issuance/Reissuance: Components must be issued or reissued in the presence of and with the approval of a council member only.\n'
                '● Reissue: The component should be reissued within 1 month of time after issuing the component.\n'
                '● Timing: For issuance/reissuance of the component the timings are 1) 1:00 pm - 1:30 pm 2) 3:30 pm - 4:00 pm\n\n'
                '4. Return Policy\n'
                '● Due Date: Components must be returned by the due date specified during issuance.\n'
                '● Condition: Components must be returned in the same condition as they were issued.\n'
                '● All the components should be returned to the council before the end semester exam.\n'
                '● Refer Fine Structure for more terms and conditions regarding the fine payment.\n\n'
                '5. Fine Structure and Payment\n'
                '● Late Returns:\n'
                '  ○ A fine will be imposed for each day the component is returned late.\n'
                '  ○ The maximum late fine will not exceed 2500 Rs.\n'
                '● Component Damage:\n'
                '  ○ No damage to the components would be accepted.\n'
                '  ○ In case of damage: Replacement Cost of the new component.\n'
                '● Loss of Component:\n'
                '  ○ Full replacement cost of the component will be charged.\n'
                '● Payment:\n'
                '  ○ Fines must be paid within 5 days of notification.\n'
                '  ○ Payment should be made online.\n\n'
                '6. Consequences of Non-Payment\n'
                '● Failure to pay fines may result in:\n'
                '  ○ Suspension of borrowing privileges.\n'
                '  ○ Membership Suspension.\n'
                '  ○ Clearance for collecting Leaving Certificate would not be provided by the Central Library of College.\n\n'
                '7. Dispute Resolution\n'
                '● Students who wish to dispute a fine may do so by submitting a written appeal to the ISA committee within 3 days of fine notification.\n'
                '● The decision of the ISA committee will be final.\n\n'
                '8. Policy Review\n'
                '● This policy will be reviewed annually and is subject to change. Updates will be communicated to all students via email and WhatsApp.\n\n'
                '9. Contact Information\n'
                'For any questions or concerns regarding this policy, please contact:\n'
                'Sr. Treasurer: Payaal Kapoor (9820008894)\n'
                'Jr. Treasurer: Sakshi Gupta (9833744631)',
                style: GoogleFonts.lato(fontSize: 13, color: secondaryText, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
