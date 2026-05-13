import 'package:our_native/features/memories/models/memory.dart';
import 'package:our_native/features/posts/models/post.dart';
import 'package:our_native/features/events/models/event.dart';
import 'package:our_native/features/help/models/help_request.dart';

/// Dummy data for UI development before Supabase is connected.
class DummyData {
  DummyData._();

  static final List<Map<String, dynamic>> feedPosts = [
    {
      'post': Post(
        id: 'p1',
        communityId: 'c1',
        authorId: 'a1',
        postType: PostType.memory,
        title: 'Our old village school - 1985',
        body:
            'This photo was taken in 1985 outside the old school building. I can see Ramkaka, Sitabai, and little Govind in the front row. Those were the best days of our lives.',
        coverImageUrl:
            'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=800',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      'authorName': 'Vishwanath Patil',
      'authorRole': 'elder',
      'reactionCounts': {'respect': 14, 'beautiful_memory': 8, 'proud': 3},
      'commentCount': 5,
    },
    {
      'post': Post(
        id: 'p2',
        communityId: 'c1',
        authorId: 'a2',
        postType: PostType.elderWisdom,
        title: 'Before It Disappears — Wisdom from Bapuji',
        body:
            '"एकमेकांस साह्य करा, अवघे धरू सुपंथ" — Help each other. That is the only true path. My father used to say this every morning before going to the fields.',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      'authorName': 'Sundarabai Shinde',
      'authorRole': 'elder',
      'reactionCounts': {'respect': 42, 'inspired': 18, 'prayers': 6},
      'commentCount': 12,
    },
    {
      'post': Post(
        id: 'p3',
        communityId: 'c1',
        authorId: 'a3',
        postType: PostType.helpRequest,
        title: 'Blood needed urgently — B+ in Nashik',
        body:
            'My mother is admitted in Nashik Civil Hospital. She needs 2 units of B+ blood urgently. Please contact Rajan at 9876543210.',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      'authorName': 'Rajan Deshmukh',
      'authorRole': 'member',
      'reactionCounts': {'prayers': 8, 'thank_you': 4},
      'commentCount': 3,
    },
    {
      'post': Post(
        id: 'p4',
        communityId: 'c1',
        authorId: 'a4',
        postType: PostType.achievement,
        title: 'Congratulations Priya — First in District!',
        body:
            'Our daughter Priya Kulkarni has scored 98.6% in SSC exams and stood first in our district. The whole village is proud! 🌟',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      'authorName': 'Suresh Kulkarni',
      'authorRole': 'member',
      'reactionCounts': {'proud': 67, 'respect': 22, 'inspired': 15},
      'commentCount': 24,
    },
  ];

  static final List<Event> upcomingEvents = [
    Event(
      id: 'e1',
      communityId: 'c1',
      title: 'Ganesh Utsav Village Gathering',
      description:
          'Annual Ganesh utsav celebration. All villagers and migrants are welcome.',
      eventType: EventType.festival,
      eventDate: DateTime.now().add(const Duration(days: 12)),
      location: 'Village Main Square, Apulki',
      status: 'upcoming',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      goingCount: 47,
      interestedCount: 23,
    ),
    Event(
      id: 'e2',
      communityId: 'c1',
      title: 'Blood Donation Camp',
      description:
          'Annual blood donation camp organized by village youth committee.',
      eventType: EventType.bloodDonation,
      eventDate: DateTime.now().add(const Duration(days: 5)),
      location: 'Gram Panchayat Hall, Apulki',
      status: 'upcoming',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      goingCount: 18,
      interestedCount: 12,
    ),
  ];

  static final List<Map<String, dynamic>> helpRequests = [
    {
      'post': Post(
        id: 'h1',
        communityId: 'c1',
        authorId: 'a5',
        postType: PostType.helpRequest,
        title: 'Job referral needed — IT sector',
        body:
            'My son Akash completed his BE in Computer Science. Looking for job referrals in IT companies in Pune. He is hardworking and honest.',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      'helpRequest': HelpRequest(
        id: 'hr1',
        postId: 'h1',
        helpType: HelpType.jobReferral,
        urgency: HelpUrgency.medium,
        contactName: 'Madhav Jadhav',
        helpStatus: HelpStatus.open,
      ),
      'authorName': 'Madhav Jadhav',
    },
    {
      'post': Post(
        id: 'h2',
        communityId: 'c1',
        authorId: 'a6',
        postType: PostType.helpRequest,
        title: 'Volunteer needed — Elder care visit',
        body:
            'Kamlavati Tai (78 years) lives alone in the village. She needs someone to check on her twice a week and help with medicines.',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      'helpRequest': HelpRequest(
        id: 'hr2',
        postId: 'h2',
        helpType: HelpType.volunteer,
        urgency: HelpUrgency.high,
        location: 'Apulki Village',
        helpStatus: HelpStatus.open,
      ),
      'authorName': 'Sanjay Mane',
    },
  ];

  static final List<Map<String, dynamic>> memories = [
    {
      'post': Post(
        id: 'm1',
        communityId: 'c1',
        authorId: 'a1',
        postType: PostType.memory,
        title: 'Harvest festival — 1978',
        body:
            'After a good harvest, the whole village would gather for thanksgiving. Look at these smiling faces!',
        coverImageUrl:
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      'memory': Memory(
        id: 'mem1',
        postId: 'm1',
        approxYear: '1978',
        locationName: 'Apulki Village Fields',
        category: MemoryCategory.festivals,
        isVintage: true,
      ),
      'authorName': 'Vishwanath Patil',
    },
    {
      'post': Post(
        id: 'm2',
        communityId: 'c1',
        authorId: 'a7',
        postType: PostType.memory,
        title: 'The old banyan tree — still standing',
        body:
            'This is where all the elders would sit and discuss village matters every evening. The tree is still there!',
        coverImageUrl:
            'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
        status: PostStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      'memory': Memory(
        id: 'mem2',
        postId: 'm2',
        approxYear: '1990',
        locationName: 'Village Center, Apulki',
        category: MemoryCategory.historical,
        isVintage: true,
      ),
      'authorName': 'Prabha Nair',
    },
  ];
}
