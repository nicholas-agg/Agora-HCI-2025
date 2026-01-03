import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isSignUp = false; // Toggle between sign in and sign up

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleAuth() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    var email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Please enter both email and password.';
        _loading = false;
      });
      return;
    }

    if (_isSignUp && name.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Please enter your name.';
        _loading = false;
      });
      return;
    }

    // Convert demo username to valid email for Firebase compatibility
    final isDemoLogin = email.toLowerCase() == 'demo';
    if (isDemoLogin) {
      email = 'demo@agora.com';
    }

    try {
      if (_isSignUp) {
        await _authService.signUp(
          email: email,
          password: password,
          displayName: name,
        );
        // Show success message and prompt to verify email
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please check your email to verify your account before signing in.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        // Switch to sign-in view
        setState(() {
          _isSignUp = false;
          _emailController.clear();
          _passwordController.clear();
          _nameController.clear();
        });
        return;
      } else {
        try {
          await _authService.signIn(
            email: email,
            password: password,
          );
        } on Exception catch (signInError) {
          // If demo login fails, automatically create the demo account
          if (isDemoLogin && (signInError.toString().contains('ERROR_INVALID_CREDENTIAL') || 
              signInError.toString().contains('incorrect') || 
              signInError.toString().contains('malformed') ||
              signInError.toString().contains('expired') ||
              signInError.toString().contains('user not found') ||
              signInError.toString().contains('user-not-found'))) {
            try {
              await _authService.signUp(
                email: email,
                password: password,
                displayName: 'Demo User',
              );
              // Demo account created, but user must verify email before accessing app
              if (!mounted) return;
              setState(() {
                _loading = false;
                _error = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo account created! Please check your email to verify before signing in.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
              return;
            } on Exception catch (signUpError) {
              // If signup also fails, show error
              if (!mounted) return;
              setState(() {
                _error = 'Failed to create demo account: ${signUpError.toString()}';
                _loading = false;
              });
              return;
            }
          } else {
            rethrow;
          }
        }
      }
      // Navigation is handled automatically by StreamBuilder in main.dart
    } on Exception catch (e) {
      if (!mounted) return;
      
      // Extract user-friendly error message
      String errorMessage = e.toString().toLowerCase();
      String displayMessage;
      
      if (errorMessage.contains('invalid') && (errorMessage.contains('credential') || errorMessage.contains('password'))) {
        displayMessage = 'Invalid email or password.';
      } else if (errorMessage.contains('user-not-found') || errorMessage.contains('user not found')) {
        displayMessage = 'No account found with this email.';
      } else if (errorMessage.contains('wrong-password') || errorMessage.contains('incorrect')) {
        displayMessage = 'Incorrect password.';
      } else if (errorMessage.contains('email-already-in-use') || errorMessage.contains('already exists')) {
        displayMessage = 'An account already exists with this email.';
      } else if (errorMessage.contains('weak-password') || errorMessage.contains('too weak')) {
        displayMessage = 'Password is too weak. Use at least 6 characters.';
      } else if (errorMessage.contains('invalid-email') || errorMessage.contains('badly formatted')) {
        displayMessage = 'Invalid email address format.';
      } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        displayMessage = 'Network error. Please check your connection.';
      } else if (errorMessage.contains('too-many-requests')) {
        displayMessage = 'Too many attempts. Please try again later.';
      } else {
        displayMessage = 'Authentication failed. Please try again.';
      }
      
      setState(() {
        _error = displayMessage;
        _loading = false;
      });
    } catch (e) {
      // Catch any other unexpected errors
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _handleForgotPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _error = 'Please enter your email address.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      
      setState(() {
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo at the top
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    height: 120,
                    width: 120,
                  ),
                ),
                Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 36.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSignUp ? 'Sign Up' : 'Sign In',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                                fontFamily: 'Roboto',
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 28),
                        
                        // Name field (only for sign up)
                        if (_isSignUp) ...[
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        
                        // Email field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email, color: colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 18),
                        
                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
                          ),
                        ),
                        
                        // Forgot password link (only for sign in)
                        if (!_isSignUp) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : _handleForgotPassword,
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                        
                        // Sign in/up button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleAuth,
                            child: _loading
                                ? const SizedBox(
                                    height: 26,
                                    width: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                          ),
                        ),
                        
                        // Error message
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        
                        // Toggle between sign in and sign up
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp
                                  ? 'Already have an account?'
                                  : "Don't have an account?",
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                  _error = null;
                                });
                              },
                              child: Text(
                                _isSignUp ? 'Sign In' : 'Sign Up',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  'Welcome to Agora',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        fontFamily: 'Roboto',
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}