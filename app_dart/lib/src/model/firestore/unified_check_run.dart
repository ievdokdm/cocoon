// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'unified_check_run_build.dart';
library;

import 'package:cocoon_server/logging.dart';
import 'package:github/github.dart';
import 'package:googleapis/firestore/v1.dart' hide Status;
import 'package:path/path.dart' as p;

import '../../../cocoon_service.dart';
import '../../service/firestore.dart';
import 'base.dart';

enum CiStage { engine, fusion }

final class UnifiedCheckRun extends AppDocument<UnifiedCheckRun> {
  static const collectionId = 'unified_check_runs';
  static const fieldCommitSha = 'commit_sha';
  static const fieldAuthor = 'author';
  static const fieldCreationTime = 'creation_time';
  static const fieldRemainingBuilds = 'remaining_builds';
  static const fieldFailedBuilds = 'failed_builds';

  static String documentId({
    required RepositorySlug slug,
    required int pullRequestId,
    required int checkRunId,
    required CiStage stage,
  }) =>
      '${slug.owner}_${slug.name}_${pullRequestId}_${checkRunId}_${stage.name}';

  @override
  AppDocumentMetadata<UnifiedCheckRun> get runtimeMetadata => metadata;

  static final metadata = AppDocumentMetadata<UnifiedCheckRun>(
    collectionId: collectionId,
    fromDocument: UnifiedCheckRun.fromDocument,
  );

  factory UnifiedCheckRun.initialize({
    required RepositorySlug slug,
    required int pullRequestId,
    required int checkRunId,
    required CiStage stage,
    required String commitSha,
    required int creationTime,
    required String author,
    required int buildCount,
  }) {
    return UnifiedCheckRun(
      checkRunId: checkRunId,
      commitSha: commitSha,
      slug: slug,
      pullRequestId: pullRequestId,
      stage: stage,
      author: author,
      creationTime: creationTime,
      remainingBuilds: buildCount,
      failedBuilds: 0,
    );
  }

  factory UnifiedCheckRun.fromDocument(Document document) {
    return UnifiedCheckRun._(document.fields!, name: document.name!);
  }

  factory UnifiedCheckRun({
    required int checkRunId,
    required String commitSha,
    required RepositorySlug slug,
    required int pullRequestId,
    required CiStage stage,
    required int creationTime,
    required String author,
    int? remainingBuilds,
    int? failedBuilds,
  }) {
    final fields = <String, Value>{
      fieldCommitSha: commitSha.toValue(),
      fieldCreationTime: creationTime.toValue(),
      fieldAuthor: author.toValue(),
      if (remainingBuilds != null)
        fieldRemainingBuilds: remainingBuilds.toValue(),
      if (failedBuilds != null) fieldFailedBuilds: failedBuilds.toValue(),
    };
    return UnifiedCheckRun._(
      fields,
      name:
          '$kDatabase/documents/$collectionId/${documentId(slug: slug, pullRequestId: pullRequestId, checkRunId: checkRunId, stage: stage)}',
    );
  }

  UnifiedCheckRun._(Map<String, Value> fields, {required String name}) {
    this.fields = fields;
    this.name = name;
  }

  String get commitSha => fields[fieldCommitSha]!.stringValue!;
  String get author => fields[fieldAuthor]!.stringValue!;
  int get creationTime => int.parse(fields[fieldCreationTime]!.integerValue!);
  int? get remainingBuilds => fields[fieldRemainingBuilds] != null
      ? int.parse(fields[fieldRemainingBuilds]!.integerValue!)
      : null;
  int? get failedBuilds => fields[fieldFailedBuilds] != null
      ? int.parse(fields[fieldFailedBuilds]!.integerValue!)
      : null;

  /// The repository that this stage is recorded for.
  RepositorySlug get slug {
    // Read it from the document name.
    final [owner, repo, _, _, _] = p.posix.basename(name!).split('_');
    return RepositorySlug(owner, repo);
  }

  /// The pull request for which this stage is recorded for.
  int get pullRequestId {
    // Read it from the document name.
    final [_, _, pullRequestId, _, _] = p.posix.basename(name!).split('_');
    return int.parse(pullRequestId);
  }

  /// Which commit this stage is recorded for.
  int get checkRunId {
    // Read it from the document name.
    final [_, _, _, checkRunId, _] = p.posix.basename(name!).split('_');
    return int.parse(checkRunId);
  }

  /// The stage of the CI process.
  CiStage get stage {
    // Read it from the document name.
    final [_, _, _, _, stageName] = p.posix.basename(name!).split('_');
    return CiStage.values.byName(stageName);
  }

  /// Initializes a new document for the given [tasks] in Firestore so that stage-tracking can succeed.
  ///
  /// The list of tasks will be written as fields of a document with additional fields for tracking the creationTime
  /// number of tasks, remaining count. It is required to include [commitSha] as a json encoded [CheckRun] as this
  /// will be used to unlock any check runs blocking progress.
  ///
  /// Returns the created document or throws an error.
  static Future<Document> initializeDocument({
    required FirestoreService firestoreService,

    required RepositorySlug slug,
    required int pullRequestId,
    required int checkRunId,
    required CiStage stage,

    required String commitSha,
    required int creationTime,
    required String author,
    required int buildCount,
  }) async {
    final logCrumb =
        'initializeDocument(${slug.owner}_${slug.name}_${pullRequestId}_${checkRunId}_$stage, $buildCount builds)';

    final fields = <String, Value>{
      fieldCommitSha: commitSha.toValue(),
      fieldAuthor: author.toValue(),
      fieldCreationTime: creationTime.toValue(),
      fieldRemainingBuilds: buildCount.toValue(),
      fieldFailedBuilds: 0.toValue(),
    };

    final document = Document(fields: fields);

    try {
      // Calling createDocument multiple times for the same documentId will return a 409 - ALREADY_EXISTS error;
      // this is good because it means we don't have to do any transactions.
      // curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer <TOKEN>" "https://firestore.googleapis.com/v1beta1/projects/flutter-dashboard/databases/cocoon/documents/unified_check_run?documentId=foo_bar_baz" -d '{"fields": {"test": {"stringValue": "baz"}}}'
      final newDoc = await firestoreService.createDocument(
        document,
        collectionId: collectionId,
        documentId: documentId(
          slug: slug,
          pullRequestId: pullRequestId,
          checkRunId: checkRunId,
          stage: stage, //
        ),
      );
      log.info('$logCrumb: document created');
      return newDoc;
    } catch (e) {
      log.warn('$logCrumb: failed to create document', e);
      rethrow;
    }
  }
}
