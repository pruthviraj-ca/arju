import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  // Animation
  late AnimationController _animController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
          ),
        );
    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Navigate to dashboard on success
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboardScreen,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      // For development: auto-create the user if they don't exist yet
      if (e.code == 'invalid-credential' || e.code == 'user-not-found') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          
          // Update display name for the drawer
          await FirebaseAuth.instance.currentUser?.updateDisplayName('Rahul Sharma');
          
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.dashboardScreen,
            (route) => false,
          );
          return;
        } catch (createError) {
          // Fall through to regular error handling if creation fails
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.getErrorMessage(e),
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reset Password',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your email address and we will send you a link to reset your password.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'you@truassets.in',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: AppTheme.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                final email = emailCtrl.text.trim().toLowerCase();
                final allowedEmails = [
                  'pruthviraj.in.in@gmail.com',
                  'arjunckbng@aol.com',
                  'pruthvi.in.in@gmail.com',
                ];
                if (!allowedEmails.contains(email)) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Invalid email: This email address is not registered.',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                  return;
                }
                try {
                  final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
                  if (methods.isEmpty) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Invalid email: This email address is not registered.',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                    return;
                  }

                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Password reset link sent to your email!',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                } catch (e) {
                  String message = 'Failed to send reset link: $e';
                  if (e is FirebaseAuthException) {
                    if (e.code == 'user-not-found' || e.code == 'invalid-email') {
                      message = 'Invalid email: This email address is not registered.';
                    }
                  }
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        message,
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Send Link',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 480 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo section
                  FadeTransition(
                    opacity: _logoFade,
                    child: SlideTransition(
                      position: _logoSlide,
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          // Logo mark
                          Image.asset(
                            'assets/images/truassets_logo.png',
                            height: 130,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Form card
                  FadeTransition(
                    opacity: _formFade,
                    child: SlideTransition(
                      position: _formSlide,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(18),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign in to your account',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Welcome back, Relationship Manager',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.mutedText,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Email field
                              Text(
                                'Email address',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.darkText,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'you@truassets.in',
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: CustomIconWidget(
                                      iconName: 'email',
                                      color: AppTheme.mutedText,
                                      size: 20,
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 48,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!RegExp(
                                    r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value.trim())) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password field
                              Text(
                                'Password',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSignIn(),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.darkText,
                                ),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: CustomIconWidget(
                                      iconName: 'lock',
                                      color: AppTheme.mutedText,
                                      size: 20,
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 48,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                    icon: CustomIconWidget(
                                      iconName: _obscurePassword
                                          ? 'visibility'
                                          : 'visibility_off',
                                      color: AppTheme.mutedText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Remember me & Forgot Password
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (v) => setState(
                                            () => _rememberMe = v ?? false,
                                          ),
                                          activeColor: AppTheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          side: const BorderSide(
                                            color: AppTheme.borderColor,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Remember me',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: AppTheme.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: _handleForgotPassword,
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Sign in button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppTheme.primary
                                        .withAlpha(153),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'Sign In',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await AuthService.instance.setDemoMode(true);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppTheme.primary,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Bypass / Demo Mode',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info box (replaces demo credentials)
                  FadeTransition(
                    opacity: _formFade,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withAlpha(51),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'info',
                            color: AppTheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sign in with your TruAssets account credentials provided by your admin.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
