import 'package:banay/services/chat/chat_participant_profile_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeConversationParticipantProfileUpdate', () {
    test('ignores updates when event user id is empty', () {
      final conversation = <String, dynamic>{
        'id': 'conversation-1',
        'participant': <String, dynamic>{
          'id': 'user-1',
          'displayName': 'Alice',
          'name': 'Alice',
          'avatarUrl': 'https://cdn.example.com/alice.jpg',
        },
      };

      final result = mergeConversationParticipantProfileUpdate(
        conversation,
        userId: ' ',
        displayName: 'Bob',
        avatarUrl: 'https://cdn.example.com/bob.jpg',
      );

      expect(result, isNull);
    });

    test('ignores updates for a different participant', () {
      final conversation = <String, dynamic>{
        'id': 'conversation-1',
        'participant': <String, dynamic>{
          'id': 'user-1',
          'displayName': 'Alice',
          'name': 'Alice',
          'avatarUrl': 'https://cdn.example.com/alice.jpg',
        },
      };

      final result = mergeConversationParticipantProfileUpdate(
        conversation,
        userId: 'user-2',
        displayName: 'Bob',
        avatarUrl: 'https://cdn.example.com/bob.jpg',
      );

      expect(result, isNull);
    });

    test('updates the matching participant identity fields', () {
      final conversation = <String, dynamic>{
        'id': 'conversation-1',
        'participant': <String, dynamic>{
          'id': 'user-1',
          'displayName': 'Alice',
          'name': 'Alice',
          'avatarUrl': 'https://cdn.example.com/alice.jpg',
          'role': 'BUYER',
        },
      };

      final result = mergeConversationParticipantProfileUpdate(
        conversation,
        userId: 'user-1',
        displayName: 'Alice Shop',
        avatarUrl: 'https://cdn.example.com/alice-shop.jpg',
        coverImageUrl: 'https://cdn.example.com/alice-cover.jpg',
        role: 'SELLER',
      );

      expect(result, isNotNull);
      expect(result!['participant']['displayName'], 'Alice Shop');
      expect(result['participant']['name'], 'Alice Shop');
      expect(
        result['participant']['avatarUrl'],
        'https://cdn.example.com/alice-shop.jpg',
      );
      expect(
        result['participant']['coverImageUrl'],
        'https://cdn.example.com/alice-cover.jpg',
      );
      expect(result['participant']['role'], 'SELLER');
    });
  });
}
