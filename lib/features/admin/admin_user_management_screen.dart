import 'package:deep_pulse_news/core/constants/app_colors.dart';
import 'package:deep_pulse_news/data/models/state.dart' as location_models;
import 'package:deep_pulse_news/shared/widgets/alert_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_font_sizes.dart';
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/user.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/auto_scaled_text.dart';

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
    ref.read(
      adminUserManagementControllerProvider.select((v) => v.resetSelections()),
    );
    super.initState();
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
    final authViewModel = ref.watch(authViewModelProvider);
    final currentUser = authViewModel.user;
    final allowedRoles = authViewModel.getAllowedUserRoles();

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: AutoScaledText(
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
              AutoScaledText(
                'Basic Information',
                style: TextStyle(
                  fontSize: appFontSizeSubHeader,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).appTextPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter user\'s full name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
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
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter email address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.email),
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
                controller: _mobileController,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Enter mobile number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a mobile number';
                  }
                  if (value.length < 10) {
                    return 'Mobile number must be at least 10 digits';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
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
              AutoScaledText(
                'Role & Permissions',
                style: TextStyle(
                  fontSize: appFontSizeSubHeader,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).appTextPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Role Dropdown with static IDs
              Consumer(
                builder: (context, ref, child) {
                  final controller = ref.watch(
                    adminUserManagementControllerProvider,
                  );
                  return DropdownButtonFormField<int>(
                    value: controller.selectedRoleId,
                    decoration: InputDecoration(
                      labelText: 'User Role',
                      hintText: 'Select user role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.admin_panel_settings),
                    ),
                    items: allowedRoles.map((roleId) {
                      return DropdownMenuItem<int>(
                        value: roleId,
                        child: Text(
                          controller.getRoleDisplayNameFromId(roleId),
                        ),
                      );
                    }).toList(),
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
                        AutoScaledText(
                          'Location Assignment',
                          style: TextStyle(
                            fontSize: appFontSizeHeader,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
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
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: authViewModel.isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: authViewModel.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : AutoScaledText(
                          'Create User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
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
                        child: AutoScaledText(
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
    );
  }

  Widget _buildLocationAssignmentUI(BuildContext context, User currentUser) {
    final currentRole = currentUser.primaryRole.value;

    // Admin can assign to any location
    if (currentRole == 'admin') {
      return _buildFullLocationSelector();
    }

    // Sub-admin can assign within their state
    if (currentRole == 'subAdmin') {
      return _buildStateScopedLocationSelector(currentUser);
    }

    // Editor can assign within their scope
    if (currentRole == 'editor') {
      return _buildEditorScopedLocationSelector(currentUser);
    }

    return const SizedBox.shrink();
  }

  Widget _buildFullLocationSelector() {
    final locationViewModel = ref.watch(locationViewModelProvider);

    // Load states if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (locationViewModel.states.isEmpty &&
          !locationViewModel.isLoadingStates) {
        ref.read(locationViewModelProvider).loadStates();
      }
    });

    return Column(
      children: [
        // State Selector
        if (locationViewModel.isLoadingStates) ...[
          const CircularProgressIndicator(),
        ] else if (locationViewModel.statesError != null) ...[
          Text('Error loading states: ${locationViewModel.statesError}'),
        ] else ...[
          Consumer(
            builder: (context, ref, child) {
              final controller = ref.watch(
                adminUserManagementControllerProvider,
              );
              return DropdownButtonFormField<location_models.State>(
                value: controller.selectedState,
                decoration: InputDecoration(
                  labelText: 'State',
                  hintText: 'Select state',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                items: locationViewModel.states.map((state) {
                  return DropdownMenuItem<location_models.State>(
                    value: state,
                    child: Text(state.name),
                  );
                }).toList(),
                onChanged: (value) {
                  ref
                      .read(adminUserManagementControllerProvider)
                      .setState(value);
                  if (value != null) {
                    ref.read(locationViewModelProvider).loadDistricts(value.id);
                  }
                },
              );
            },
          ),
        ],

        const SizedBox(height: 16),

        // District Selector
        Consumer(
          builder: (context, ref, child) {
            final controller = ref.watch(adminUserManagementControllerProvider);
            if (controller.selectedState == null) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                if (locationViewModel.isLoadingDistricts) ...[
                  const CircularProgressIndicator(),
                ] else if (locationViewModel.districtsError != null) ...[
                  Text(
                    'Error loading districts: ${locationViewModel.districtsError}',
                  ),
                ] else ...[
                  Consumer(
                    builder: (context, ref, child) {
                      final controller = ref.watch(
                        adminUserManagementControllerProvider,
                      );
                      return DropdownButtonFormField<District>(
                        value: controller.selectedDistrict,
                        decoration: InputDecoration(
                          labelText: 'District',
                          hintText: 'Select district',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.location_city),
                        ),
                        items: locationViewModel.districts.map((district) {
                          return DropdownMenuItem<District>(
                            value: district,
                            child: Text(district.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          ref
                              .read(adminUserManagementControllerProvider)
                              .setDistrict(value);
                          if (value != null) {
                            ref
                                .read(locationViewModelProvider)
                                .loadMandals(value.id);
                          }
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Mandal Selector
                if (controller.selectedDistrict != null) ...[
                  if (locationViewModel.isLoadingMandals) ...[
                    const CircularProgressIndicator(),
                  ] else if (locationViewModel.mandalsError != null) ...[
                    Text(
                      'Error loading mandals: ${locationViewModel.mandalsError}',
                    ),
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
                            hintText: 'Select mandal',
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
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStateScopedLocationSelector(User currentUser) {
    final locationViewModel = ref.watch(locationViewModelProvider);

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
              AutoScaledText(
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
        if (locationViewModel.isLoadingDistricts) ...[
          const CircularProgressIndicator(),
        ] else if (locationViewModel.districtsError != null) ...[
          Text('Error loading districts: ${locationViewModel.districtsError}'),
        ] else ...[
          Consumer(
            builder: (context, ref, child) {
              final controller = ref.watch(
                adminUserManagementControllerProvider,
              );
              return DropdownButtonFormField<District>(
                value: controller.selectedDistrict,
                decoration: InputDecoration(
                  labelText: 'District',
                  hintText: 'Select district within your state',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_city),
                ),
                items: locationViewModel.districts.map((district) {
                  return DropdownMenuItem<District>(
                    value: district,
                    child: Text(district.name),
                  );
                }).toList(),
                onChanged: (value) {
                  ref
                      .read(adminUserManagementControllerProvider)
                      .setDistrict(value);
                  if (value != null) {
                    ref.read(locationViewModelProvider).loadMandals(value.id);
                  }
                },
              );
            },
          ),
        ],

        const SizedBox(height: 16),

        // Mandal Selector
        Consumer(
          builder: (context, ref, child) {
            final controller = ref.watch(adminUserManagementControllerProvider);
            if (controller.selectedDistrict == null)
              return const SizedBox.shrink();
            return Column(
              children: [
                if (locationViewModel.isLoadingMandals) ...[
                  const CircularProgressIndicator(),
                ] else if (locationViewModel.mandalsError != null) ...[
                  Text(
                    'Error loading mandals: ${locationViewModel.mandalsError}',
                  ),
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
                          hintText: 'Select mandal',
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
          },
        ),
      ],
    );
  }

  Widget _buildEditorScopedLocationSelector(User currentUser) {
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
        // State and District are fixed for editor
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
                  AutoScaledText(
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
              AutoScaledText(
                'State: ${currentUser.stateName ?? 'N/A'}',
                style: TextStyle(
                  fontSize: appFontSizeCaption,
                  color: Theme.of(context).appGrey600,
                ),
              ),
              AutoScaledText(
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

    if (success) {
      _nameController.clear();
      _emailController.clear();
      _mobileController.clear();
      _passwordController.clear();
    }
  }
}
