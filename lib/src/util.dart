import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// Extension with one [toShortString] method
/*extension RoleToShortString on types.Role {
  /// Converts enum to the string equal to enum's name
  String toShortString() {
    return toString().split('.').last;
  }
}*/

/// Extension with one [toShortString] method
/*extension RoomTypeToShortString on types.RoomType {
  /// Converts enum to the string equal to enum's name
  String toShortString() {
    return toString().split('.').last;
  }
}*/

/// Fetches user from Firebase and returns a promise
Future<Map<String, dynamic>> fetchUser(String userId, {String role}) async {
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

  final data = doc.data();

  data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
  data['id'] = doc.id;
  data['lastSeen'] = data['lastSeen']?.millisecondsSinceEpoch;
  data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;
  data['role'] = role;

  return data;
}

/// Returns a list of [types.Room] created from Firebase query.
/// If room has 2 participants, sets correct room name and image.
Future<List<types.Room>> processRoomsQuery(
  User firebaseUser,
  QuerySnapshot query,
) async {
  final futures = query.docs.map(
    (doc) => processRoomDocument(doc, firebaseUser),
  );

  return await Future.wait(futures);
}

/// Returns a [types.Room] created from Firebase document
Future<types.Room> processRoomDocument(
  DocumentSnapshot doc,
  User firebaseUser,
) async {
  final data = doc.data() as Map<String, dynamic>;

  data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
  data['id'] = doc.id;
  data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;

  var imageUrl = data['imageUrl'] as String;
  var name = data['name'] as String;
  final type = data['type'] as String;
  final userIds = data['userIds'] as List<dynamic>;
  final userRoles = data['userRoles'] as Map<String, dynamic>;
  data['name'] = await getOtherUserName(firebaseUser, userIds);
  final users = [];
  if(userRoles != null)
    {
      final users = await Future.wait(
        userIds.map(
              (userId) => fetchUser(
            userId as String,
            role: userRoles[userId] as String,
          ),
        ),
      );
    }

  if (type == types.RoomType.direct.toSShortString()) {
    try {
      final otherUser = users.firstWhere(
        (u) => u['id'] != firebaseUser.uid,
      );

      imageUrl = otherUser['imageUrl'] as String;
      name = '${otherUser['firstName'] ?? ''} ${otherUser['lastName'] ?? ''}'
          .trim();
    } catch (e) {
      // Do nothing if other user is not found, because he should be found.
      // Consider falling back to some default values.
    }
  }

  data['imageUrl'] = imageUrl;
  // data['name'] = name;
  data['users'] = users;
  data['userIds'] = userIds;

  if (data['lastMessages'] != null) {
    final lastMessages = data['lastMessages'].map((lm) {
      final author = users.firstWhere(
        (u) => u['id'] == lm['authorId'],
        orElse: () => {'id': lm['authorId'] as String},
      );

      lm['author'] = author;
      lm['createdAt'] = lm['createdAt']?.millisecondsSinceEpoch;
      lm['id'] = lm['id'] ?? '';
      lm['updatedAt'] = lm['updatedAt']?.millisecondsSinceEpoch;

      return lm;
    }).toList();

    data['lastMessages'] = lastMessages;
  }

  return types.Room.fromJson(data);
}

Future<String> getOtherUserName(User firebaseUser, List<dynamic> userIds) async {
  print('CURRENT USER ID: ${firebaseUser.uid}');
  print('SELECTED CHAT USER: $userIds');

  final e = userIds.where((element) => element != firebaseUser.uid).toList();

  final snapshot = await FirebaseFirestore.instance.collection('users').doc(e[0].toString()).get();

  final data = snapshot.data();
  return '${data['firstName']} ${data['lastName']}';
}
