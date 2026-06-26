import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/shipping_address.dart';
import '../providers/address_provider.dart';

/// Bottom sheet form for adding or editing a shipping address.
class AddressFormSheet extends ConsumerStatefulWidget {
  final ShippingAddress? existingAddress; // null = add mode

  const AddressFormSheet({super.key, this.existingAddress});

  /// Show the address form as a modal bottom sheet.
  static Future<bool?> show(BuildContext context, {ShippingAddress? address}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddressFormSheet(existingAddress: address),
    );
  }

  @override
  ConsumerState<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postcodeController;
  bool _isDefault = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    _labelController = TextEditingController(text: a?.label ?? '');
    _nameController = TextEditingController(text: a?.recipientName ?? '');
    _phoneController = TextEditingController(text: a?.phone ?? '');
    _line1Controller = TextEditingController(text: a?.addressLine1 ?? '');
    _line2Controller = TextEditingController(text: a?.addressLine2 ?? '');
    _cityController = TextEditingController(text: a?.city ?? '');
    _stateController = TextEditingController(text: a?.state ?? '');
    _postcodeController = TextEditingController(text: a?.postcode ?? '');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final service = ref.read(addressServiceProvider);

    try {
      if (_isEditMode) {
        await service.updateAddress(
          addressId: widget.existingAddress!.id,
          label: _labelController.text.trim(),
          recipientName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          addressLine1: _line1Controller.text.trim(),
          addressLine2: _line2Controller.text.trim().isEmpty
              ? null
              : _line2Controller.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          postcode: _postcodeController.text.trim(),
        );
        if (_isDefault && !widget.existingAddress!.isDefault) {
          await service.setDefaultAddress(widget.existingAddress!.id);
        }
      } else {
        await service.addAddress(
          label: _labelController.text.trim(),
          recipientName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          addressLine1: _line1Controller.text.trim(),
          addressLine2: _line2Controller.text.trim().isEmpty
              ? null
              : _line2Controller.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          postcode: _postcodeController.text.trim(),
          isDefault: _isDefault,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditMode ? 'Edit Address' : 'Add New Address',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 24),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                        controller: _labelController,
                        label: 'Address Label',
                        hint: 'e.g. Home, Office, Campus',
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _nameController,
                        label: 'Recipient Name',
                        hint: 'Full name',
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: '+60xx-xxx xxxx',
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone is required';
                          }
                          if (v.trim().length < 10) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _line1Controller,
                        label: 'Address Line 1',
                        hint: 'Street, building, unit',
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _line2Controller,
                        label: 'Address Line 2 (Optional)',
                        hint: 'Apartment, floor, etc.',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildField(
                              controller: _cityController,
                              label: 'City',
                              hint: 'City',
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              controller: _postcodeController,
                              label: 'Postcode',
                              hint: '58100',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (v.trim().length < 5) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _stateController,
                        label: 'State',
                        hint: 'e.g. Kuala Lumpur, Selangor',
                        validator: _required,
                      ),
                      const SizedBox(height: 16),

                      // Default checkbox
                      GestureDetector(
                        onTap: () => setState(() => _isDefault = !_isDefault),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _isDefault
                                      ? AppColors.primary
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                                color: _isDefault
                                    ? AppColors.primary
                                    : Colors.white,
                              ),
                              child: _isDefault
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Set as default address',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isEditMode ? 'Save Changes' : 'Add Address',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
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
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      style: GoogleFonts.inter(fontSize: 14),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }
}
