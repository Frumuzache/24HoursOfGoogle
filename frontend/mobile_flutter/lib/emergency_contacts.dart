import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'models/contacts.dart';
import 'services/api_client.dart';
import 'services/location_service.dart';

class ContactManagerScreen extends StatefulWidget {
  final int profileId;

  const ContactManagerScreen({super.key, required this.profileId});

  @override
  State<ContactManagerScreen> createState() => _ContactManagerScreenState();
}

class _ContactManagerScreenState extends State<ContactManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSendingSos = false;
  EmergencyContact? _currentContact;

  String _normalizePhoneForApi(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s\-().]'), '');
    if (compact.isEmpty) {
      return compact;
    }

    if (compact.startsWith('+')) {
      return compact;
    }

    if (compact.startsWith('00')) {
      return '+${compact.substring(2)}';
    }

    final digitsOnly = compact.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('0') && digitsOnly.length >= 9) {
      return '+40${digitsOnly.substring(1)}';
    }

    if (digitsOnly.isEmpty) {
      return compact;
    }

    return '+40$digitsOnly';
  }

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    setState(() => _isLoading = true);

    try {
      final profile = await ApiClient().getProfile(widget.profileId);
      final contactName = profile['emergency_contact_name'] as String?;
      final contactPhone = profile['emergency_contact_phone'] as String?;

      if (!mounted) {
        return;
      }

      if (contactName != null && contactName.isNotEmpty) {
        _nameController.text = contactName;
      }
      if (contactPhone != null && contactPhone.isNotEmpty) {
        _phoneController.text = contactPhone;
      }

      setState(() {
        _currentContact = (contactName == null || contactName.isEmpty) &&
                (contactPhone == null || contactPhone.isEmpty)
            ? null
            : EmergencyContact(
                name: contactName ?? '',
                phone: contactPhone ?? '',
                relation: 'Primary contact',
              );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load emergency contact: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final normalizedPhone = _normalizePhoneForApi(_phoneController.text);

    try {
      await ApiClient().updateEmergencyContact(
        profileId: widget.profileId,
        name: _nameController.text.trim(),
        phone: normalizedPhone,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentContact = EmergencyContact(
          name: _nameController.text.trim(),
          phone: normalizedPhone,
          relation: 'Primary contact',
        );
      });

      _phoneController.text = normalizedPhone;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency contact saved.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save contact: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _triggerSos() async {
    setState(() => _isSendingSos = true);

    try {
      final position = await LocationService().getCurrentLocation();
      final response = await ApiClient().triggerSos(
        profileId: widget.profileId,
        heartRate: 72,
        locationLabel: position == null ? 'Unknown location' : 'Current location',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (!mounted) {
        return;
      }

      final sos = response['sos'] as Map<String, dynamic>?;
      final emergencyContact = sos?['emergency_contact'] as Map<String, dynamic>?;
      final alert = sos?['alert'] as Map<String, dynamic>?;
      final message = alert?['message'] as String? ?? 'SOS triggered successfully.';
      final contactName = emergencyContact?['name'] as String?;
      final contactPhone = emergencyContact?['phone'] as String?;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.softAwareness, size: 60),
              const SizedBox(height: 16),
              const Text('SOS Triggered', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (contactName != null || contactPhone != null) ...[
                const SizedBox(height: 16),
                Text(
                  contactName == null || contactName.isEmpty
                      ? 'Emergency contact configured.'
                      : 'Emergency contact: $contactName',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.midnightText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contactPhone != null && contactPhone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    contactPhone,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.midnightText.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri(scheme: 'tel', path: contactPhone);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call contact'),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepSerenity,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trigger SOS: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingSos = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMist,
      appBar: AppBar(
        title: Text('Emergency Contacts', style: TextStyle(color: AppColors.midnightText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.midnightText),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency Contact',
                style: TextStyle(
                  color: AppColors.midnightText,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Save the person who should be alerted when you hit SOS.',
                style: TextStyle(color: AppColors.midnightText.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_currentContact != null) ...[
                  _buildSummaryCard(_currentContact!),
                  const SizedBox(height: 20),
                ],
                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.surfaceBlue, width: 2),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Contact name',
                            prefixIcon: Icon(Icons.person, color: AppColors.deepSerenity),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a contact name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone, color: AppColors.deepSerenity),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a phone number';
                            }
                            if (value.trim().length < 3) {
                              return 'Phone number is too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveContact,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepSerenity,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Save contact', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isSendingSos ? null : _triggerSos,
                            icon: const Icon(Icons.emergency_share),
                            label: _isSendingSos
                                ? const Text('Sending SOS...')
                                : const Text('Trigger SOS now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(EmergencyContact contact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current contact',
            style: TextStyle(
              color: AppColors.midnightText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contact.name.isEmpty ? 'No name saved yet' : contact.name,
            style: TextStyle(
              color: AppColors.midnightText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contact.phone.isEmpty ? 'No phone saved yet' : contact.phone,
            style: TextStyle(color: AppColors.midnightText.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}
