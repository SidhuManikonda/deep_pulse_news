import 'package:deep_pulse_news/core/constants/app_colors.dart';
import 'package:deep_pulse_news/data/models/state.dart' as location_models;
import 'package:deep_pulse_news/shared/widgets/alert_popup.dart';
import 'package:deep_pulse_news/shared/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_font_sizes.dart';
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/user.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/searchable_dropdown.dart';

class AdminUserManagementScreen extends ConsumerStatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  ConsumerState<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends ConsumerState<AdminUserManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminUserManagementControllerProvider).resetSelections();
      ref
          .read(adminUserManagementControllerProvider)
          .fetchRoles(authRepository: ref.read(authRepositoryProvider));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authViewModel = ref.watch(authViewModelProvider);
    final currentUser = authViewModel.user;
    final controller = ref.watch(adminUserManagementControllerProvider);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            'User Management',
            style: TextStyle(
              fontSize: appFontSizeTitle,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).appTextPrimary,
            ),
          ),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Basic Information',
                  style: TextStyle(
                    fontSize: scaledFontSize(15),
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).appTextPrimary,
                  ),
                ),

                const SizedBox(height: 16),

                // Name Field
                TextFormField(
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: const Color(0xFF333333),
                    fontWeight: FontWeight.w500,
                  ),
                  controller: _nameController,
                  decoration: _fieldDecoration(
                    label: 'Full Name',
                    hint: 'Enter user\'s full name',
                    icon: Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: const Color(0xFF333333),
                    fontWeight: FontWeight.w500,
                  ),
                  controller: _emailController,
                  decoration: _fieldDecoration(
                    label: 'Email',
                    hint: 'Enter email address',
                    icon: Icons.email_outlined,
                  ),

                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Mobile Field
                TextFormField(
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: const Color(0xFF333333),
                    fontWeight: FontWeight.w500,
                  ),
                  controller: _mobileController,
                  decoration: _fieldDecoration(
                    label: 'Mobile Number',
                    hint: 'Enter mobile number',
                    icon: Icons.phone_outlined,
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a mobile number';
                    }
                    if (value.length < 10) {
                      return 'Mobile number must be at least 10 digits';
                    }
                    if (value.length > 10) {
                      return 'Mobile number must not exceed 10 digits';
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                      return 'Mobile number must contain only digits';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: const Color(0xFF333333),
                    fontWeight: FontWeight.w500,
                  ),
                  controller: _passwordController,
                  decoration: _fieldDecoration(
                    label: 'Password',
                    hint: 'Enter password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        ref
                                .watch(adminUserManagementControllerProvider)
                                .isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: const Color(0xFFBBBBBB),
                      ),
                      onPressed: () {
                        ref
                            .read(adminUserManagementControllerProvider)
                            .togglePasswordVisibility();
                      },
                    ),
                  ),

                  obscureText: !(ref
                      .watch(adminUserManagementControllerProvider)
                      .isPasswordVisible),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Role Selection
                Text(
                  'Role & Permissions',
                  style: TextStyle(
                    fontSize: scaledFontSize(15),
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).appTextPrimary,
                  ),
                ),

                const SizedBox(height: 16),

                // Role Dropdown with static IDs
                if (controller.isLoadingRoles)
                  const Center(child: CircularProgressIndicator())
                else if (controller.rolesError != null)
                  Text('Error loading roles: ${controller.rolesError}')
                else
                  Consumer(
                    builder: (context, ref, child) {
                      final ctrl = ref.watch(
                        adminUserManagementControllerProvider,
                      );
                      return DropdownButtonFormField<int>(
                        value: ctrl.selectedRoleId,
                        decoration: _fieldDecoration(
                          label: 'User Role',
                          hint: 'Select user role',
                          icon: Icons.shield_outlined,
                        ),
                        style: TextStyle(
                          fontSize: scaledFontSize(14),
                          color: const Color(0xFF333333),
                          fontWeight: FontWeight.w500,
                        ),
                        items: ctrl.roles
                            .where((role) {
                              // Sub-admin should not see admin or sub_admin roles
                              if (currentUser.primaryRole.value ==
                                  'sub_admin') {
                                final slug =
                                    role.slug?.toLowerCase() ??
                                    role.name.toLowerCase().replaceAll(
                                      ' ',
                                      '_',
                                    );
                                final show =
                                    slug != 'admin' &&
                                    slug != 'sub_admin' &&
                                    slug != 'sub-admin';
                                return show;
                              }
                              return true;
                            })
                            .map((role) {
                              return DropdownMenuItem<int>(
                                value: role.id,
                                child: Text(
                                  role.name,
                                  style: TextStyle(
                                    fontSize: scaledFontSize(14),
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                              );
                            })
                            .toList(),
                        dropdownColor: Colors.white,
                        onChanged: (value) {
                          ref
                              .read(adminUserManagementControllerProvider)
                              .setRole(value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a role';
                          }
                          return null;
                        },
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Location Assignment
                Consumer(
                  builder: (context, ref, child) {
                    final controller = ref.watch(
                      adminUserManagementControllerProvider,
                    );
                    if (controller.selectedRoleId != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Assignment',
                            style: TextStyle(
                              fontSize: scaledFontSize(15),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLocationAssignmentUI(context, currentUser),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 32),

                // Create User Button
                // SizedBox(
                //   width: double.infinity,
                //   height: 50,
                //   child: ElevatedButton(
                //     onPressed: authViewModel.isLoading ? null : _createUser,
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Theme.of(context).primaryColor,
                //       foregroundColor: Colors.white,
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(8),
                //       ),
                //     ),
                //     child: authViewModel.isLoading
                //         ? const CircularProgressIndicator(color: Colors.white)
                //         : Text(
                //             'Create User',
                //             style: TextStyle(
                //               fontSize: scaledFontSize(16),
                //               fontWeight: FontWeight.w600,
                //             ),
                //           ),
                //   ),
                // ),
                CustomIconButton(
                  text: 'Create User',
                  onTap: _createUser,
                  isLoading: authViewModel.isLoading,
                  width: double.infinity,
                  buttonColor: theme.appPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                // Error Display
                if (authViewModel.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      // border: BorderSide(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authViewModel.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationAssignmentUI(BuildContext context, User currentUser) {
    final currentRole = currentUser.primaryRole.value;

    // Admin can assign to any location
    if (currentRole == 'admin') {
      return _buildFullLocationSelector();
    }

    // Sub-admin can assign within their state
    if (currentRole == 'sub_admin') {
      return _buildStateScopedLocationSelector(currentUser);
    }

    // Dist-reporter can assign within their scope
    if (currentRole == 'dist-reporter') {
      return _buildDistReporterScopedLocationSelector(currentUser);
    }

    return const SizedBox.shrink();
  }

  Widget _buildFullLocationSelector() {
    final locationViewModel = ref.watch(locationViewModelProvider);
    final controller = ref.watch(adminUserManagementControllerProvider);
    final roleSlug =
        controller.selectedRoleSlug ?? controller.selectedRoleName ?? '';

    // Determine which location fields to show based on role
    // Subadmin: State only
    // Dist-reporter: State + District
    // Reporter/Reader: State + District + Mandal
    final showDistrict = roleSlug != 'subadmin';
    final showMandal = roleSlug != 'subadmin' && roleSlug != 'dist-reporter';

    // Load states if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (locationViewModel.states.isEmpty &&
          !locationViewModel.isLoadingStates) {
        ref.read(locationViewModelProvider).loadStates();
      }
    });

    return Consumer(
      builder: (context, ref, child) {
        final controller = ref.watch(adminUserManagementControllerProvider);
        final theme = Theme.of(context);

        return Column(
          children: [
            // State
            _buildSearchableSelector<location_models.State>(
              theme: theme,
              label: 'State',
              icon: Icons.location_on,
              hint: controller.selectedState?.name ?? 'Select state',
              isSelected: controller.selectedState != null,
              isLoading: locationViewModel.isLoadingStates,
              items: locationViewModel.states,
              getName: (s) => s.name,
              onSelected: (s) {
                ref.read(adminUserManagementControllerProvider).setState(s);
                if (showDistrict) {
                  ref.read(locationViewModelProvider).loadDistricts(s.id);
                }
              },
            ),

            // District
            if (showDistrict && controller.selectedState != null) ...[
              const SizedBox(height: 16),
              _buildSearchableSelector<District>(
                theme: theme,
                label: 'District',
                icon: Icons.location_city,
                hint: controller.selectedDistrict?.name ?? 'Select district',
                isSelected: controller.selectedDistrict != null,
                isLoading: locationViewModel.isLoadingDistricts,
                items: locationViewModel.districts,
                getName: (d) => d.name,
                onSelected: (d) {
                  ref
                      .read(adminUserManagementControllerProvider)
                      .setDistrict(d);
                  if (showMandal) {
                    ref.read(locationViewModelProvider).loadMandals(d.id);
                  }
                },
              ),
            ],

            // Mandal
            if (showMandal && controller.selectedDistrict != null) ...[
              const SizedBox(height: 16),
              _buildSearchableSelector<Mandal>(
                theme: theme,
                label: 'Mandal',
                icon: Icons.home,
                hint: controller.selectedMandal?.name ?? 'Select mandal',
                isSelected: controller.selectedMandal != null,
                isLoading: locationViewModel.isLoadingMandals,
                items: locationViewModel.mandals,
                getName: (m) => m.name,
                onSelected: (m) {
                  ref.read(adminUserManagementControllerProvider).setMandal(m);
                },
              ),
            ],
          ],
        );
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: const Color(0xFF888888),
        fontSize: scaledFontSize(13),
      ),
      hintStyle: TextStyle(
        color: const Color(0xFFAAAAAA),
        fontSize: scaledFontSize(13),
      ),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFFBBBBBB)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8A0A0)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8A0A0), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildSearchableSelector<T>({
    required ThemeData theme,
    required String label,
    required IconData icon,
    required String hint,
    required bool isSelected,
    required bool isLoading,
    required List<T> items,
    required String Function(T) getName,
    required void Function(T) onSelected,
  }) {
    return SearchableDropdown<T>(
      label: label,
      icon: icon,
      selectedValue: isSelected ? hint : null,
      isLoading: isLoading,
      items: items,
      getName: getName,
      onSelected: onSelected,
    );
  }

  Widget _buildStateScopedLocationSelector(User currentUser) {
    final locationViewModel = ref.watch(locationViewModelProvider);
    final controller = ref.watch(adminUserManagementControllerProvider);
    final roleSlug =
        controller.selectedRoleSlug ?? controller.selectedRoleName ?? '';
    final showMandal = roleSlug != 'dist-reporter';

    // Load districts if not already loaded for this state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUser.stateId != null &&
          (locationViewModel.districts.isEmpty ||
              locationViewModel.districts.first.stateId !=
                  currentUser.stateId) &&
          !locationViewModel.isLoadingDistricts) {
        ref.read(locationViewModelProvider).loadDistricts(currentUser.stateId!);
      }
    });

    return Column(
      children: [
        // State is fixed for sub-admin
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).appGrey100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Assigned to State: ${currentUser.stateName ?? 'N/A'}',
                style: TextStyle(
                  fontSize: appFontSizeBody,
                  color: Theme.of(context).appTextPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // District Selector within state
        Consumer(
          builder: (context, ref, child) {
            final controller = ref.watch(adminUserManagementControllerProvider);
            final theme = Theme.of(context);
            return _buildSearchableSelector<District>(
              theme: theme,
              label: 'District',
              icon: Icons.location_city,
              hint: controller.selectedDistrict?.name ?? 'Select district',
              isSelected: controller.selectedDistrict != null,
              isLoading: locationViewModel.isLoadingDistricts,
              items: locationViewModel.districts,
              getName: (d) => d.name,
              onSelected: (d) {
                ref.read(adminUserManagementControllerProvider).setDistrict(d);
                if (showMandal) {
                  ref.read(locationViewModelProvider).loadMandals(d.id);
                }
              },
            );
          },
        ),

        // Mandal Selector — only for reporter/reader, not dist-reporter
        if (showMandal && controller.selectedDistrict != null) ...[
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final controller = ref.watch(
                adminUserManagementControllerProvider,
              );
              final theme = Theme.of(context);
              return _buildSearchableSelector<Mandal>(
                theme: theme,
                label: 'Mandal',
                icon: Icons.home,
                hint: controller.selectedMandal?.name ?? 'Select mandal',
                isSelected: controller.selectedMandal != null,
                isLoading: locationViewModel.isLoadingMandals,
                items: locationViewModel.mandals,
                getName: (m) => m.name,
                onSelected: (m) {
                  ref.read(adminUserManagementControllerProvider).setMandal(m);
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDistReporterScopedLocationSelector(User currentUser) {
    final locationViewModel = ref.watch(locationViewModelProvider);

    // Load mandals if not already loaded for this district
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUser.districtId != null &&
          (locationViewModel.mandals.isEmpty ||
              locationViewModel.mandals.first.districtId !=
                  currentUser.districtId) &&
          !locationViewModel.isLoadingMandals) {
        ref
            .read(locationViewModelProvider)
            .loadMandals(currentUser.districtId!);
      }
    });

    return Column(
      children: [
        // State and District are fixed for dist-reporter
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).appGrey100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Assigned Location',
                    style: TextStyle(
                      fontSize: appFontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).appTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'State: ${currentUser.stateName ?? 'N/A'}',
                style: TextStyle(
                  fontSize: appFontSizeCaption,
                  color: Theme.of(context).appGrey600,
                ),
              ),
              Text(
                'District: ${currentUser.districtName ?? 'N/A'}',
                style: TextStyle(
                  fontSize: appFontSizeCaption,
                  color: Theme.of(context).appGrey600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Mandal Selector within district
        if (locationViewModel.isLoadingMandals) ...[
          const CircularProgressIndicator(),
        ] else if (locationViewModel.mandalsError != null) ...[
          Text('Error loading mandals: ${locationViewModel.mandalsError}'),
        ] else ...[
          Consumer(
            builder: (context, ref, child) {
              final controller = ref.watch(
                adminUserManagementControllerProvider,
              );
              return DropdownButtonFormField<Mandal>(
                value: controller.selectedMandal,
                decoration: InputDecoration(
                  labelText: 'Mandal',
                  hintText: 'Select mandal within your district',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.home),
                ),
                items: locationViewModel.mandals.map((mandal) {
                  return DropdownMenuItem<Mandal>(
                    value: mandal,
                    child: Text(mandal.name),
                  );
                }).toList(),
                dropdownColor: Colors.white,

                onChanged: (value) {
                  ref
                      .read(adminUserManagementControllerProvider)
                      .setMandal(value);
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(adminUserManagementControllerProvider);

    if (controller.selectedRoleId == null) {
      AlertPopupManager().showAlert(
        title: 'Role Required',
        message: 'Please select a user role.',
        type: AlertType.warning,
      );
      return;
    }

    final authViewModel = ref.read(authViewModelProvider);
    final currentUser = authViewModel.user!;

    final success = await controller.createUser(
      authViewModel: authViewModel,
      currentUser: currentUser,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      mobile: _mobileController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      ref
          .read(adminUserManagementControllerProvider)
          .fetchUsers(
            authRepository: ref.read(authRepositoryProvider),
            forceRefresh: true,
          );
      Navigator.of(context).pop();
    }
  }
}
