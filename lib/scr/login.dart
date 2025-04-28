import 'package:flutter/material.dart';
import 'package:ikwimpay/providers/auth_provider.dart';
import 'package:ikwimpay/scr/homescreen.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true; // For password visibility toggle

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // If already logged in, navigate to home screen
    if (authProvider.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    }

    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Removes the back button

          title: const Text(
            'ITEC LTD',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0), // Adjust padding as needed
              child: Image.asset(
                'assets/images/ikwim_tr.png', // Ensure this path is correct
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                // Adjust size as needed
              ),
            ),
          ],
          backgroundColor: const Color(0xFF870813),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          // color: Color(0xFFA50000), // Dark blue background color
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.all(15.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Login text
                        const Text(
                          'Login',
                          style: TextStyle(
                            // color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // const SizedBox(height: 16),
                        // // Login instruction text
                        // const Text(
                        //   'Please enter your login credentials to access your account',
                        //   textAlign: TextAlign.center,
                        //   style: TextStyle(
                        //     // color: Colors.white,
                        //     fontSize: 16,
                        //   ),
                        // ), // Logo at the center
                        // Container(
                        //   width: 120,
                        //   height: 80,
                        //   decoration: BoxDecoration(
                        //     color: Colors.purple[800],
                        //     borderRadius: BorderRadius.circular(8),
                        //   ),
                        //   child: const Center(
                        //     child: Icon(
                        //       Icons.scanner,
                        //       color: Colors.white,
                        //       size: 40,
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 20),

                        // Email fieldchild: Container(

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontWeight: FontWeight.w300),
                          decoration: InputDecoration(
                            labelText: 'Phone',
                            hintText: 'Phone',
                            hintStyle: const TextStyle(
                                // color: Colors.white,
                                fontWeight: FontWeight.w300,
                                fontSize: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // contentPadding: const EdgeInsets.only(bottom: 8),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                            errorStyle: const TextStyle(
                                // color: Colors.white,
                                fontWeight: FontWeight.w300,
                                fontSize: 16),
                            prefixIcon: const Icon(
                              Icons.email,
                              // color: Colors.white,
                              weight: 300,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone';
                            }
                            // final emailRegExp =
                            //     RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            // if (!emailRegExp.hasMatch(value)) {
                            //   return 'Please enter a valid email address';
                            // }
                            return null;
                          },
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _isObscure,
                          style: const TextStyle(
                              // color: Colors.white,
                              fontWeight: FontWeight.w400,
                              fontSize: 20),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Password',
                            hintStyle: const TextStyle(
                                // color: Colors.white,
                                fontWeight: FontWeight.w300,
                                fontSize: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // contentPadding: const EdgeInsets.only(bottom: 8),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                            errorStyle: const TextStyle(
                                fontWeight: FontWeight.w300, fontSize: 16),
                            prefixIcon: const Icon(
                              Icons.lock,
                              // color: Colors.white,
                              size: 20,
                              weight: 300,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                // color: Colors.white,
                                size: 20,
                                weight: 300,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isObscure = !_isObscure;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const Divider(color: Colors.white70),
                        const SizedBox(height: 5),

                        // Forgot password
                        // Align(
                        //   alignment: Alignment.centerRight,
                        //   child: TextButton(
                        //     onPressed: () {
                        //       // Handle forgot password
                        //     },
                        //     child: const Text(
                        //       'Forgot Password?',
                        //       style: TextStyle(fontWeight: FontWeight.w400),
                        //     ),
                        //   ),
                        // ),

                        // Error message
                        if (authProvider.errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      authProvider.errorMessage,
                                      style: const TextStyle(
                                          color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 30),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () async {
                                    FocusScope.of(context).unfocus();
                                    if (_formKey.currentState!.validate()) {
                                      // Call the login method from AuthProvider
                                      // which should be connected to the API
                                      bool success = await authProvider.login(
                                        _emailController.text,
                                        _passwordController.text,
                                      );

                                      if (success && mounted) {
                                        // Show success message before navigation
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Login successful!'),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );

                                        // Navigate to home screen after successful login
                                        Future.delayed(
                                            const Duration(seconds: 1), () {
                                          if (mounted) {
                                            Navigator.of(context)
                                                .pushReplacement(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const HomeScreen(),
                                              ),
                                            );
                                          }
                                        });
                                      }
                                      // No need for else block as error is displayed
                                      // via authProvider.errorMessage
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF870813),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
          ),
        ));
  }
}
