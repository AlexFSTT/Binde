import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _emailSent = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final result = await _authService.resetPassword(_emailController.text.trim());
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      if (result.isSuccess) {
        setState(() => _emailSent = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resetare parolă'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _emailSent ? _buildSuccessView(colorScheme) : _buildFormView(colorScheme),
        ),
      ),
    );
  }
  
  Widget _buildFormView(ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          
          Icon(
            Icons.lock_reset,
            size: 80,
            color: colorScheme.primary,
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Ai uitat parola?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Introdu adresa de email și îți vom trimite un link pentru a-ți reseta parola.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          
          const SizedBox(height: 32),
          
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleResetPassword(),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'exemplu@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Te rugăm să introduci email-ul';
              }
              if (!value.contains('@')) {
                return 'Te rugăm să introduci un email valid';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Trimite link de resetare',
                    style: TextStyle(fontSize: 16),
                  ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessView(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        
        Icon(
          Icons.mark_email_read,
          size: 80,
          color: Colors.green,
        ),
        
        const SizedBox(height: 24),
        
        Text(
          'Email trimis!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Am trimis un link de resetare la:\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Verifică inbox-ul și folder-ul de spam.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
        
        const SizedBox(height: 32),
        
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Înapoi la Login',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}