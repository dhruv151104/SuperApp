import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:product_traceability_mobile/core/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // New Fields
  final _companyNameController = TextEditingController();
  final _licenseIdController = TextEditingController();
  String _businessType = 'Other'; 
  String? _registeredLocation; // "lat,long"
  
  String _selectedRole = 'Manufacturer'; // Default
  bool _isLoading = false;
  bool _isLocationFetching = false;

  final List<String> _roles = ['Manufacturer', 'Retailer'];
  final List<String> _businessTypes = ['Pharmacy', 'Supermarket', 'Logistics', 'Factory', 'Other'];

  Future<void> _fetchLocation() async {
    setState(() => _isLocationFetching = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location denied');
      }
      
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _registeredLocation = "${position.latitude}, ${position.longitude}";
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location Error: $e")));
    } finally {
      if(mounted) setState(() => _isLocationFetching = false);
    }
  }

  Future<void> _register() async {
    if (_registeredLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please register your location.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedRole,
        _companyNameController.text.trim(),
        _registeredLocation,
        _licenseIdController.text.trim(),
        _businessType
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Successful! Please Login.")));
        context.pop(); // Go back to login
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registration Failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Account Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock)),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(labelText: "Role"),
              items: _roles.map((role) {
                return DropdownMenuItem(value: role, child: Text(role));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            
            const SizedBox(height: 32),
            const Text("Business Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            
            TextField(
              controller: _companyNameController,
              decoration: InputDecoration(
                labelText: _selectedRole == 'Manufacturer' ? "Company Name" : "Store Name",
                prefixIcon: const Icon(Icons.business)
              ),
            ),
            const SizedBox(height: 16),
             TextField(
              controller: _licenseIdController,
              decoration: const InputDecoration(labelText: "License / Registration ID", prefixIcon: Icon(Icons.badge)),
            ),
            const SizedBox(height: 16),
             DropdownButtonFormField<String>(
              value: _businessType,
              decoration: const InputDecoration(labelText: "Business Type"),
              items: _businessTypes.map((t) {
                return DropdownMenuItem(value: t, child: Text(t));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _businessType = val);
              },
            ),
            const SizedBox(height: 16),
            
            // Location
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12)
              ),
              child: Column(
                children: [
                   Row(
                     children: [
                       const Icon(Icons.location_on, color: Colors.blue),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           _registeredLocation == null ? "Location not set" : "Verified: $_registeredLocation",
                           style: TextStyle(color: _registeredLocation == null ? Colors.grey : Colors.black),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   OutlinedButton.icon(
                     onPressed: _isLocationFetching ? null : _fetchLocation,
                     icon: _isLocationFetching 
                       ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                       : const Icon(Icons.my_location),
                     label: const Text("Get Current Location"),
                   ),
                   const Text("Used for geofencing compliance", style: TextStyle(fontSize: 12, color: Colors.grey))
                ],
              ),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_isLoading || _isLocationFetching) ? null : _register,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}
