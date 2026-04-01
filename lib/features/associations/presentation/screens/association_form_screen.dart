import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/association.dart';
import '../providers/associations_provider.dart';

/// Formulaire de création et d'édition d'une association.
///
/// - [association] null → mode création
/// - [association] non null → mode édition (à brancher à l'étape suivante)
class AssociationFormScreen extends StatefulWidget {
  final Association? association;

  const AssociationFormScreen({super.key, this.association});

  bool get isEditing => association != null;

  @override
  State<AssociationFormScreen> createState() => _AssociationFormScreenState();
}

class _AssociationFormScreenState extends State<AssociationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.association?.name ?? '');
    _descController =
        TextEditingController(text: widget.association?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<AssociationsProvider>();

      if (widget.isEditing) {
        // L'édition sera implémentée à l'étape suivante.
      } else {
        await provider.createAssociation(
          name: _nameController.text,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Association modifiée avec succès.'
                  : 'Association créée avec succès.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? "Modifier l'association" : 'Nouvelle association',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFieldLabel('Nom de l\'association *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: 'Ex : Bureau des Étudiants',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est obligatoire.';
                  }
                  if (value.trim().length < 2) {
                    return 'Le nom doit faire au moins 2 caractères.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Décrivez brièvement cette association…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.isEditing ? 'Enregistrer' : 'Créer l\'association',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
