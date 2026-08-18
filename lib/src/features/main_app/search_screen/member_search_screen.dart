import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Member {
  final String name;
  final String email;
  final String id;
  final String division;
  final String phone;
  final String? profileImageUrl;

  Member({
    required this.name,
    required this.email,
    required this.id,
    required this.division,
    required this.phone,
    this.profileImageUrl,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      name: json['Name'] ?? '',
      email: json['Email Id'] ?? '',
      id: json['ISA Login ID'] ?? '',
      division: json['Division'] ?? '',
      phone: json['Phone Number'] ?? '',
      profileImageUrl: json['ProfileImageUrl'], // Ensure it's populated
    );
  }
}

class MemberController extends GetxController {
  RxList<Member> members = <Member>[].obs;
  RxList<Member> foundMembers = <Member>[].obs;
  RxList<Member> beMembers = <Member>[].obs;
  RxList<Member> teMembers = <Member>[].obs;
  RxList<Member> seMembers = <Member>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchMembers();
  }

  // Future<void> fetchMembers() async {
  //   try {
  //     // Fetch members from the Members table
  //     final List<dynamic> membersData =
  //         await Supabase.instance.client.from('Members').select();

  //     if (membersData.isEmpty) {
  //       print('No data found in Members table.');
  //       return;
  //     }

  //     List<Member> loadedMembers = [];

  //     // Fetch profile images for each member
  //     for (var memberData in membersData) {
  //       String memberId =
  //           memberData['ISA Login ID'] ?? ''; // Ensure field matches DB
  //       String? profileImageUrl;

  //       print('Fetching profile image for Member ID: $memberId'); // Debug log

  //       // Fetch the profile image URL from Profiles table
  //       if (memberId.isNotEmpty) {
  //         final profileData = await Supabase.instance.client
  //             .from('profiles')
  //             .select('profile_image_url')
  //             .eq('member_id', memberId)
  //             .maybeSingle();

  //         profileImageUrl = profileData?['profile_image_url'];

  //         // Debugging: Log the profile image URL
  //         print(
  //             'Profile Image URL for ${memberData["Name"]}: $profileImageUrl');
  //       }

  //       // Add the member to the list
  //       loadedMembers.add(Member(
  //         name: memberData['Name'] ?? '',
  //         email: memberData['Email Id'] ?? '',
  //         id: memberData['ISA Login ID'] ?? '',
  //         division: memberData['Division'] ?? '',
  //         phone: memberData['Phone Number'] ?? '',
  //         profileImageUrl: profileImageUrl,
  //       ));
  //     }

  //     members.value = loadedMembers;
  //     print('Fetched members: ${members.length}');

  //     // Categorize members by batch
  //     beMembers.value =
  //         members.where((member) => member.id.startsWith('2021-')).toList();
  //     teMembers.value =
  //         members.where((member) => member.id.startsWith('2022-')).toList();
  //     seMembers.value =
  //         members.where((member) => member.id.startsWith('2023-')).toList();

  //     foundMembers.value = members;
  //   } catch (error) {
  //     print('Error fetching members: $error');
  //     Get.snackbar(
  //       'Error',
  //       'Failed to fetch members: ${error.toString()}',
  //       snackPosition: SnackPosition.BOTTOM,
  //     );
  //   }
  // }
  Future<void> fetchMembers() async {
    try {
      // Fetch all members from the Members table
      final List<dynamic> membersData =
          await Supabase.instance.client.from('Members').select();

      if (membersData.isEmpty) {
        print('No data found in Members table.');
        return;
      }

      // Extract all member IDs
      final memberIds = membersData
          .map((member) => member['ISA Login ID'])
          .whereType<String>()
          .toList();

      // Build a dynamic OR query if `in_` is not supported
      String orQuery = memberIds.map((id) => 'member_id.eq.$id').join(',');

      // Fetch all profile images in a single query
      final List<dynamic> profilesData = await Supabase.instance.client
          .from('profiles')
          .select('member_id, profile_image_url')
          .or(orQuery);

      // Create a map for quick lookup of profile images
      final Map<String, String> profileImagesMap = {
        for (var profile in profilesData)
          profile['member_id']: profile['profile_image_url'] ?? '',
      };

      // Construct member objects
      List<Member> loadedMembers = membersData.map((memberData) {
        final memberId = memberData['ISA Login ID'] ?? '';
        final profileImageUrl = profileImagesMap[memberId];

        return Member(
          name: memberData['Name'] ?? '',
          email: memberData['Email Id'] ?? '',
          id: memberId,
          division: memberData['Division'] ?? '',
          phone: memberData['Phone Number'] ?? '',
          profileImageUrl: profileImageUrl,
        );
      }).toList();

      // Update state with the fetched members
      members.value = loadedMembers;
      print('Fetched members: ${members.length}');

      // Categorize members by batch
      beMembers.value =
          members.where((member) => member.id.startsWith('2022-')).toList();
      teMembers.value =
          members.where((member) => member.id.startsWith('2023-')).toList();
      seMembers.value =
          members.where((member) => member.id.startsWith('2024-')).toList();

      foundMembers.value = members;
    } catch (error) {
      print('Error fetching members: $error');
      Get.snackbar(
        'Error',
        'Failed to fetch members: ${error.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void filterMembers(String query) {
    if (query.isEmpty) {
      beMembers.value =
          members.where((member) => member.id.startsWith('2021-')).toList();
      teMembers.value =
          members.where((member) => member.id.startsWith('2022-')).toList();
      seMembers.value =
          members.where((member) => member.id.startsWith('2023-')).toList();
    } else {
      beMembers.value = members
          .where((member) =>
              member.id.startsWith('2021-') &&
              member.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      teMembers.value = members
          .where((member) =>
              member.id.startsWith('2022-') &&
              member.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      seMembers.value = members
          .where((member) =>
              member.id.startsWith('2023-') &&
              member.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }
}

class MemberSearchScreen extends StatefulWidget {
  const MemberSearchScreen({super.key});

  @override
  State<MemberSearchScreen> createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final MemberController controller = Get.put(MemberController());

  Widget _buildMemberSection(String title, RxList<Member> sectionMembers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Obx(
          () => ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sectionMembers.length,
            itemBuilder: (context, index) {
              final member = sectionMembers[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    child: member.profileImageUrl != null &&
                            member.profileImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.network(
                              member.profileImageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.grey[600],
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.grey[600],
                          ),
                  ),
                  onTap: () {
                    showMemberDetails(context, member);
                  },
                  title: Text(
                    member.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'ISA Login ID: ${member.id}\nDivision: ${member.division}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Search'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 154, 210, 255),
              Color.fromARGB(255, 213, 245, 252),
              Color.fromARGB(255, 242, 254, 255),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => controller.filterMembers(value),
                decoration: const InputDecoration(
                  labelText: 'Search',
                  suffixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMemberSection('BE Members', controller.beMembers),
                      _buildMemberSection('TE Members', controller.teMembers),
                      _buildMemberSection('SE Members', controller.seMembers),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showMemberDetails(BuildContext context, Member member) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(
            member.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${member.email}'),
              Text('Phone: ${member.phone}'),
              Text('Id: ${member.id}'),
              Text('Division: ${member.division}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
