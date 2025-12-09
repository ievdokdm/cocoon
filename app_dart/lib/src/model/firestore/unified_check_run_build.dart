// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library;

import 'package:buildbucket/buildbucket_pb.dart' as bbv2;
import 'package:cocoon_common/task_status.dart';
import 'package:googleapis/firestore/v1.dart' hide Status;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../service/firestore.dart';
import '../bbv2_extension.dart';
import 'base.dart';

const String kUnifiedCheckRunBuildCollectionId = 'unified_check_run_builds';

@immutable
final class UnifiedCheckRunBuildId extends AppDocumentId<UnifiedCheckRunBuild> {
  UnifiedCheckRunBuildId({
    required this.checkRunId,
    required this.buildName,
    required this.attemptNumber,
  }) {
    if (attemptNumber < 1) {
      throw RangeError.value(
        attemptNumber,
        'attemptNumber',
        'Must be at least 1',
      );
    }
  }

  /// Parse the inverse of [UnifiedCheckRunBuildId.documentName].
  factory UnifiedCheckRunBuildId.parse(String documentName) {
    final result = tryParse(documentName);
    if (result == null) {
      throw FormatException(
        'Unexpected firestore unified check run build document name: "$documentName"',
      );
    }
    return result;
  }

  /// Tries to parse the inverse of [UnifiedCheckRunBuildId.documentName].
  ///
  /// If could not be parsed, returns `null`.
  static UnifiedCheckRunBuildId? tryParse(String documentName) {
    if (_parseDocumentName.matchAsPrefix(documentName) case final match?) {
      final checkRunId = match.group(1)!;
      final buildName = match.group(2)!;
      final attemptNumber = int.tryParse(match.group(3)!);
      if (attemptNumber != null) {
        return UnifiedCheckRunBuildId(
          checkRunId: checkRunId,
          buildName: buildName,
          attemptNumber: attemptNumber,
        );
      }
    }
    return null;
  }

  /// Parses `{checkRunId}_{buildName}_{attemptNumber}`.
  ///
  /// This is gross because the [buildName] could also include underscores.
  static final _parseDocumentName = RegExp(r'([a-z0-9]+)_(.*)_([0-9]+)$');

  final String checkRunId;
  final String buildName;
  final int attemptNumber;

  @override
  String get documentId {
    return [checkRunId, buildName, attemptNumber].join('_');
  }

  @override
  AppDocumentMetadata<UnifiedCheckRunBuild> get runtimeMetadata => UnifiedCheckRunBuild.metadata;
}

final class UnifiedCheckRunBuild extends AppDocument<UnifiedCheckRunBuild> {
  static const fieldCheckRunId = 'checkRunId';
  static const fieldBuildName = 'buildName';
  static const fieldBuildNumber = 'buildNumber';
  static const fieldStatus = 'status';
  static const fieldAttemptNumber = 'attemptNumber';
  static const fieldCreationTime = 'creationTime';
  static const fieldStartTime = 'startTime';
  static const fieldEndTime = 'endTime';

  static AppDocumentId<UnifiedCheckRunBuild> documentIdFor({
    required String checkRunId,
    required String buildName,
    required int attemptNumber,
  }) {
    return UnifiedCheckRunBuildId(
      checkRunId: checkRunId,
      buildName: buildName,
      attemptNumber: attemptNumber,
    );
  }

  @override
  AppDocumentMetadata<UnifiedCheckRunBuild> get runtimeMetadata => metadata;

  static final metadata = AppDocumentMetadata<UnifiedCheckRunBuild>(
    collectionId: kUnifiedCheckRunBuildCollectionId,
    fromDocument: UnifiedCheckRunBuild.fromDocument,
  );

  static Future<UnifiedCheckRunBuild> fromFirestore(
    FirestoreService firestoreService,
    AppDocumentId<UnifiedCheckRunBuild> id,
  ) async {
    final document = await firestoreService.getDocument(
      p.posix.join(kDatabase, 'documents', kUnifiedCheckRunBuildCollectionId, id.documentId),
    );
    return UnifiedCheckRunBuild.fromDocument(document);
  }

  factory UnifiedCheckRunBuild({
    required String checkRunId,
    required String buildName,
    required int buildNumber,
    required TaskStatus status,
    required int attemptNumber,
    required int creationTime,
    required int startTime,
    required int endTime,
  }) {
    final id = UnifiedCheckRunBuildId(
      checkRunId: checkRunId,
      buildName: buildName,
      attemptNumber: attemptNumber,
    );
    return UnifiedCheckRunBuild._(
      {
        fieldCheckRunId: checkRunId.toValue(),
        fieldBuildName: buildName.toValue(),
        fieldBuildNumber: buildNumber.toValue(),
        fieldStatus: status.value.toValue(),
        fieldAttemptNumber: attemptNumber.toValue(),
        fieldCreationTime: creationTime.toValue(),
        fieldStartTime: startTime.toValue(),
        fieldEndTime: endTime.toValue(),
      },
      name: p.posix.join(
        kDatabase,
        'documents',
        kUnifiedCheckRunBuildCollectionId,
        id.documentId,
      ),
    );
  }

  factory UnifiedCheckRunBuild.fromDocument(Document document) {
    return UnifiedCheckRunBuild._(document.fields!, name: document.name!);
  }

  UnifiedCheckRunBuild._(Map<String, Value> fields, {required String name}) {
    this
      ..fields = fields
      ..name = name;
  }

  String get checkRunId => fields[fieldCheckRunId]!.stringValue!;
  String get buildName => fields[fieldBuildName]!.stringValue!;
  int get buildNumber => int.parse(fields[fieldBuildNumber]!.integerValue!);
  int get attemptNumber => int.parse(fields[fieldAttemptNumber]!.integerValue!);
  int get creationTime => int.parse(fields[fieldCreationTime]!.integerValue!);
  int get startTime => int.parse(fields[fieldStartTime]!.integerValue!);
  int get endTime => int.parse(fields[fieldEndTime]!.integerValue!);

  TaskStatus get status {
    final rawValue = fields[fieldStatus]!.stringValue!;
    return TaskStatus.from(rawValue);
  }

  void setStatus(TaskStatus status) {
    fields[fieldStatus] = status.value.toValue();
  }

  void setEndTime(int endTime) {
    fields[fieldEndTime] = endTime.toValue();
  }

  void updateFromBuild(bbv2.Build build) {
    fields[fieldBuildNumber] = build.number.toValue();
    fields[fieldCreationTime] = build.createTime
        .toDateTime()
        .millisecondsSinceEpoch
        .toValue();
    fields[fieldStartTime] = build.startTime
        .toDateTime()
        .millisecondsSinceEpoch
        .toValue();
    fields[fieldEndTime] = build.endTime
        .toDateTime()
        .millisecondsSinceEpoch
        .toValue();
    _setStatusFromLuciStatus(build);
  }

  void _setStatusFromLuciStatus(bbv2.Build build) {
    if (status.isComplete) {
      return;
    }
    setStatus(build.status.toTaskStatus());
  }
}
