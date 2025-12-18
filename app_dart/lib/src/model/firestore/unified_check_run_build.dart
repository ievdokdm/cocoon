// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'unified_check_run.dart';
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
    if (checkRunId < 1) {
      throw RangeError.value(checkRunId, 'checkRunId', 'Must be at least 1');
    } else if (attemptNumber < 1) {
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
      final checkRunId = int.tryParse(match.group(1)!);
      final buildName = match.group(2)!;
      final attemptNumber = int.tryParse(match.group(3)!);
      if (checkRunId != null && attemptNumber != null) {
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
  /// [buildName] could also include underscores which led us to use regexp .
  /// But we dont have build number at the moment of creating the document and
  /// we need to query by checkRunId and buildName for updating the document.
  static final _parseDocumentName = RegExp(r'([0-9]+)_(.*)_([0-9]+)$');

  final int checkRunId;
  final String buildName;
  final int attemptNumber;

  @override
  String get documentId {
    return [checkRunId, buildName, attemptNumber].join('_');
  }

  @override
  AppDocumentMetadata<UnifiedCheckRunBuild> get runtimeMetadata =>
      UnifiedCheckRunBuild.metadata;
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
  static const fieldSummary = 'summary';

  static AppDocumentId<UnifiedCheckRunBuild> documentIdFor({
    required int checkRunId,
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
      p.posix.join(
        kDatabase,
        'documents',
        kUnifiedCheckRunBuildCollectionId,
        id.documentId,
      ),
    );
    return UnifiedCheckRunBuild.fromDocument(document);
  }

  factory UnifiedCheckRunBuild({
    required int checkRunId,
    required String buildName,
    required TaskStatus status,
    required int attemptNumber,
    required int creationTime,
    int? buildNumber,
    int? startTime,
    int? endTime,
    String? summary,
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
        if (buildNumber != null) fieldBuildNumber: buildNumber.toValue(),
        fieldStatus: status.value.toValue(),
        fieldAttemptNumber: attemptNumber.toValue(),
        fieldCreationTime: creationTime.toValue(),
        if (startTime != null) fieldStartTime: startTime.toValue(),
        if (endTime != null) fieldEndTime: endTime.toValue(),
        if (summary != null) fieldSummary: summary.toValue(),
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

  factory UnifiedCheckRunBuild.init({
    required String buildName,
    required int checkRunId,
    required int creationTime,
  }) {
    return UnifiedCheckRunBuild(
      buildName: buildName,
      attemptNumber: 1,
      checkRunId: checkRunId,
      creationTime: creationTime,
      status: TaskStatus.waitingForBackfill,
      buildNumber: null,
      startTime: null,
      endTime: null,
      summary: null,
    );
  }

  UnifiedCheckRunBuild._(Map<String, Value> fields, {required String name}) {
    this
      ..fields = fields
      ..name = name;
  }

  int get checkRunId => int.parse(fields[fieldCheckRunId]!.stringValue!);
  String get buildName => fields[fieldBuildName]!.stringValue!;
  int get attemptNumber => int.parse(fields[fieldAttemptNumber]!.integerValue!);
  int get creationTime => int.parse(fields[fieldCreationTime]!.integerValue!);
  int? get buildNumber => fields[fieldBuildNumber] != null
      ? int.parse(fields[fieldBuildNumber]!.integerValue!)
      : null;
  int? get startTime => fields[fieldStartTime] != null
      ? int.parse(fields[fieldStartTime]!.integerValue!)
      : null;
  int? get endTime => fields[fieldEndTime] != null
      ? int.parse(fields[fieldEndTime]!.integerValue!)
      : null;
  String? get summary => fields[fieldSummary]?.stringValue;

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

  void setSummary(String summary) {
    fields[fieldSummary] = summary.toValue();
  }

  void updateFromBuild(bbv2.Build build) {
    fields[fieldBuildNumber] = build.number.toValue();
    fields[fieldCreationTime] = build.createTime
        .toDateTime()
        .millisecondsSinceEpoch
        .toValue();

    if (build.hasStartTime()) {
      fields[fieldStartTime] = build.startTime
          .toDateTime()
          .millisecondsSinceEpoch
          .toValue();
    }

    if (build.hasEndTime()) {
      fields[fieldEndTime] = build.endTime
          .toDateTime()
          .millisecondsSinceEpoch
          .toValue();
    }
    _setStatusFromLuciStatus(build);
  }

  void _setStatusFromLuciStatus(bbv2.Build build) {
    if (status.isComplete) {
      return;
    }
    setStatus(build.status.toTaskStatus());
  }

  /// Returns _all_ builds running against the speificed [checkRunId].
  Future<List<UnifiedCheckRunBuild>> queryAllBuildsForCheckRun({
    required FirestoreService firestoreService,
    required int checkRunId,
    TaskStatus? status,
    String? buildName,
    Transaction? transaction,
  }) async {
    return await _queryUnifiedCheckRunBuild(
      firestoreService: firestoreService,
      checkRunId: checkRunId,
      buildName: buildName,
      status: status,
      transaction: transaction,
    );
  }

  /// Returns _all_ build attempts forthe speificed [checkRunId] and [buildName].
  Future<List<UnifiedCheckRunBuild>> queryAllBuildAttempts({
    required FirestoreService firestoreService,
    required int checkRunId,
    required String? buildName,
    Transaction? transaction,
  }) async {
    return await _queryUnifiedCheckRunBuild(
      firestoreService: firestoreService,
      checkRunId: checkRunId,
      buildName: buildName,
      status: null,
      transaction: transaction,
    );
  }

  Future<List<UnifiedCheckRunBuild>> _queryUnifiedCheckRunBuild({
    required FirestoreService firestoreService,
    required int checkRunId,
    String? buildName,
    TaskStatus? status,
    Transaction? transaction,
  }) async {
    final filterMap = {
      '${UnifiedCheckRunBuild.fieldCheckRunId} =': checkRunId,
      if (buildName != null)
        '${UnifiedCheckRunBuild.fieldBuildName} =': buildName,
      if (status != null) '${UnifiedCheckRunBuild.fieldStatus} =': status.value,
    };
    // For tasks, therer is no reason to _not_ order this way.
    final orderMap = {
      UnifiedCheckRunBuild.fieldCreationTime: kQueryOrderDescending,
    };
    final documents = await firestoreService.query(
      kUnifiedCheckRunBuildCollectionId,
      filterMap,
      orderMap: orderMap,
      transaction: transaction,
    );
    return [...documents.map(UnifiedCheckRunBuild.fromDocument)];
  }
}
