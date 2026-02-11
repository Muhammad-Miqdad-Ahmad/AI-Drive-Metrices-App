import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String userName = "Loading...";
  String userEmail = "...";
  bool isDarkMode = false;
  bool isKmH = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "Guest User";
      userEmail = prefs.getString('user_email') ?? "No Email Set";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// PROFILE SECTION
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          const Text(
            "Preferences",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          _buildSettingsTile(
            "Dark Mode",
            Icons.dark_mode,
            trailing: Switch(
              value: isDarkMode,
              activeColor: AppColors.primaryPurple,
              onChanged: (v) => setState(() => isDarkMode = v),
            ),
          ),

          _buildSettingsTile(
            "Units",
            Icons.speed,
            trailing: Text(
              isKmH ? "km/h" : "mph",
              style: const TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => setState(() => isKmH = !isKmH),
          ),

          const SizedBox(height: 20),
          const Text(
            "Security & Device",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          _buildSettingsTile("Change Password", Icons.lock_outline),
          _buildSettingsTile(
            "Device Info",
            Icons.developer_board,
            trailing: const Text(
              "v1.0.4-beta",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 20),
          _buildSettingsTile(
            "Logout",
            Icons.logout,
            isDestructive: true,
            onTap: () {
              // Add logout logic (e.g., clearing prefs and Navigating to Login)
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    String title,
    IconData icon, {
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : AppColors.primaryPurple,
              size: 22,
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.redAccent : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
          ],
        ),
      ),
    );
  }
}
