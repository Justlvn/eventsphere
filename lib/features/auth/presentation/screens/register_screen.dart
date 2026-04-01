import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/devinci_email.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _showAdminCodeField = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final adminCode = _adminCodeController.text.trim();

    await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      adminCode: adminCode.isNotEmpty ? adminCode : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.loading;
    final isPending =
        authProvider.status == AuthStatus.emailConfirmationPending;

    if (isPending) {
      return _EmailConfirmationScreen(email: _emailController.text.trim());
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Column(
            children: [
              // ── Zone logo / dégradé ──────────────────────────────────────
              AuthHeroArea(
                subtitle: 'Créer un compte',
                height: size.height * 0.28,
              ),

              // ── Formulaire ────────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Inscription',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rejoignez la vie associative',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Nom complet',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Veuillez saisir votre nom.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'prenom.nom@edu.devinci.fr',
                                  helperText: '@devinci.fr ou @edu.devinci.fr uniquement',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Veuillez saisir votre email.';
                                  }
                                  if (!isDevinciInstitutionEmail(v)) {
                                    return 'Utilisez une adresse @devinci.fr ou @edu.devinci.fr.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Mot de passe',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Veuillez saisir un mot de passe.';
                                  }
                                  if (v.length < 6) {
                                    return 'Au moins 6 caractères.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirmer le mot de passe',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v != _passwordController.text) {
                                    return 'Les mots de passe ne correspondent pas.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // ── Code admin ───────────────────────────────
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() {
                                  _showAdminCodeField = !_showAdminCodeField;
                                  if (!_showAdminCodeField) {
                                    _adminCodeController.clear();
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _showAdminCodeField
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.vpn_key_outlined,
                                        size: 18,
                                        color: _showAdminCodeField
                                            ? AppColors.primary
                                            : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "J'ai un code administrateur",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _showAdminCodeField
                                                ? AppColors.primary
                                                : Colors.grey.shade700,
                                            fontWeight: _showAdminCodeField
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _showAdminCodeField
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: _showAdminCodeField
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: TextFormField(
                                          controller: _adminCodeController,
                                          decoration: const InputDecoration(
                                            labelText: 'Code administrateur',
                                            prefixIcon:
                                                Icon(Icons.vpn_key_outlined),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),

                        if (authProvider.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          AuthErrorBanner(message: authProvider.errorMessage!),
                        ],

                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("S'inscrire"),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed:
                                isLoading ? null : () => context.go('/login'),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: 'Déjà un compte ? ',
                                    style:
                                        TextStyle(color: Colors.grey.shade500),
                                  ),
                                  TextSpan(
                                    text: 'Se connecter',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Écran confirmation email ─────────────────────────────────────────────────

class _EmailConfirmationScreen extends StatelessWidget {
  final String email;

  const _EmailConfirmationScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Vérifiez votre boîte mail',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                'Un email de confirmation a été envoyé à :',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                "Cliquez sur le lien dans l'email pour activer votre compte, puis connectez-vous.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, height: 1.5),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Aller à la connexion'),
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
