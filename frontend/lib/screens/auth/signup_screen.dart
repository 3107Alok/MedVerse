import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  // Doctor fields
  final _licenseController = TextEditingController();
  final _specController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _expController = TextEditingController();

  UserRole _selectedRole = UserRole.patient;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                validator: (value) => value!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: (value) => value!.isEmpty ? 'Enter email' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                validator: (value) => value!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 24),
              Text('Select Role', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Column(
                children: [
                  RadioListTile<UserRole>(
                    title: const Text('Patient'),
                    value: UserRole.patient,
                    groupValue: _selectedRole,
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                  RadioListTile<UserRole>(
                    title: const Text('Doctor'),
                    value: UserRole.doctor,
                    groupValue: _selectedRole,
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                ],
              ),
              if (_selectedRole == UserRole.doctor) ...[
                const SizedBox(height: 20),
                Text('Professional Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _licenseController,
                  decoration: const InputDecoration(labelText: 'Medical License Number'),
                  validator: (v) => _selectedRole == UserRole.doctor && v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specController,
                  decoration: const InputDecoration(labelText: 'Specialization'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hospitalController,
                  decoration: const InputDecoration(labelText: 'Hospital Affiliation'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expController,
                  decoration: const InputDecoration(labelText: 'Years of Experience'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          Map<String, dynamic>? extraData;
                          if (_selectedRole == UserRole.doctor) {
                            extraData = {
                              'license': _licenseController.text,
                              'specialization': _specController.text,
                              'hospital': _hospitalController.text,
                              'experience': _expController.text,
                            };
                          }
                          
                          final success = await authProvider.signUp(
                            email: _emailController.text,
                            password: _passwordController.text,
                            name: _nameController.text,
                            role: _selectedRole,
                            extraData: extraData,
                          );
                          
                          if (success && mounted) {
                            Navigator.pop(context);
                          } else if (!success && mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Registration Failed')),
                              );
                          }
                        }
                      },
                child: authProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
