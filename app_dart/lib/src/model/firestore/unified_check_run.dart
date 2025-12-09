// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'unified_check_run.dart';
library;

import 'package:cocoon_server/logging.dart';
import 'package:collection/collection.dart';
import 'package:github/github.dart';
import 'package:googleapis/firestore/v1.dart' hide Status;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../service/firestore.dart';
import 'base.dart';

final class UnifiedCheckRunId extends AppDocumentId<UnifiedCheckRun> {
  UnifiedCheckRunId({
    required this.owner,
    required this.repo,
    required this.pullRequestId,
    required this.checkRunId,
    required this.stage,
  });

  /// The repository owner.
  final String owner;

  /// The repository name.
  final String repo;

  /// The pull request id.
  final String pullRequestId;

  /// The Check Run Id.
  final String checkRunId;

  /// The stage of the CI process.
  final CiStage stage;

  @override
  String get documentId =>
      [owner, repo, pullRequestId, checkRunId, stage].join('_');

  @override
  AppDocumentMetadata<UnifiedCheckRun> get runtimeMetadata =>
      UnifiedCheckRun.metadata;
}

/// Representation of the current work scheduled for a given stage of monorepo check runs.
///
/// 'Staging' is the breaking up of the CI tasks such that some are performed before others.
/// This is required so that engine build artifacts can be made available to any tests that
/// depend on them.
///
/// This document layout is currently:
/// ```
///  /projects/flutter-dashboard/databases/cocoon/unified_check_run/
///     document: <this.slug.owner>_<this.slug.repo>_<this.checkRunId>_<this.stage>
///       creationTime: int >= 0
///       remaining: int >= 0
///       [*fields]: string {scheduled, success, failure, skipped}
/// ```
final class UnifiedCheckRun extends AppDocument<UnifiedCheckRun> {
  /// Firestore collection for the [UnifiedCheckRun] documents.
  static const _collectionId = 'unified_check_run';

  static const kRemainingField = 'remaining_builds';
  static const kFailedField = 'failed_builds';
  static const kCreationTimeField = 'creation_time';
  static const kCommitShaField = 'commit_sha';

  @visibleForTesting
  static const fieldRepoFullPath = 'repository';

  @visibleForTesting
  static const fieldCheckRunId = 'check_run_id';

  @visibleForTesting
  static const fieldStage = 'stage';

  static AppDocumentId<UnifiedCheckRun> documentIdFor({
    required RepositorySlug slug,
    required String pullRequestId,
    required String checkRunId,
    required CiStage stage,
  }) =>
      UnifiedCheckRunId(
        owner: slug.owner,
        repo: slug.name,
        pullRequestId: pullRequestId,
        checkRunId: checkRunId,
        stage: stage,
      );

  @override
  AppDocumentMetadata<UnifiedCheckRun> get runtimeMetadata => metadata;

  /// Description of the document in Firestore.
  static final metadata = AppDocumentMetadata<UnifiedCheckRun>(
    collectionId: _collectionId,
    fromDocument: UnifiedCheckRun.fromDocument,
  );

  /// Returns a firebase documentName used in [fromFirestore].
  static String documentNameFor({
    required RepositorySlug slug,
    required String pullRequestId,
    required String checkRunId,
    required CiStage stage,
  }) {
    // Document names cannot cannot have '/' in the document id.
    final docId = documentIdFor(
      slug: slug,
      pullRequestId: pullRequestId,
      checkRunId: checkRunId,
      stage: stage,
    );
    return '$kDocumentParent/$_collectionId/${docId.documentId}';
  }

  /// Lookup [UnifiedCheckRun] from Firestore.
  ///
  /// Use [documentNameFor] to get the correct [documentName]
  static Future<UnifiedCheckRun> fromFirestore({
    required FirestoreService firestoreService,
    required String documentName,
  }) async {
    final document = await firestoreService.getDocument(documentName);
    return UnifiedCheckRun.fromDocument(document);
  }

  /// Create [UnifiedCheckRun] from a other Document.
  UnifiedCheckRun.fromDocument(Document other) {
    this
      ..name = other.name
      ..fields = {...?other.fields}
      ..createTime = other.createTime
      ..updateTime = other.updateTime;
  }

  /// The repository that this stage is recorded for.
  RepositorySlug get slug {
    if (fields[fieldRepoFullPath]?.stringValue case final repoFullPath?) {
      return RepositorySlug.full(repoFullPath);
    }

    // Read it from the document name.
    final [owner, repo, _, _, _] = p.posix.basename(name!).split('_');
    return RepositorySlug(owner, repo);
  }

  /// The pull request for which this stage is recorded for.
  String get pullRequestId {
    // Read it from the document name.
    final [_, _, pullRequestId, _, _] = p.posix.basename(name!).split('_');
    return pullRequestId;
  }

  /// Which commit this stage is recorded for.
  String get checkRunId {
    if (fields[fieldCheckRunId]?.stringValue case final checkRunId?) {
      return checkRunId;
    }

    // Read it from the document name.
    final [_, _, _, checkRunId, _] = p.posix.basename(name!).split('_');
    return checkRunId;
  }

  /// The stage of the CI process.
  CiStage? get stage {
    if (fields[fieldStage]?.stringValue case final stageName?) {
      return CiStage.values.firstWhereOrNull((e) => e.name == stageName);
    }

    // Read it from the document name.
    final [_, _, _, _, stageName] = p.posix.basename(name!).split('_');
    return CiStage.values.firstWhereOrNull((e) => e.name == stageName);
  }

  /// The remaining number of checks in this staging.
  int get remaining => int.parse(fields[kRemainingField]!.integerValue!);

  /// The creationTime number of checks in this staging.
  int get creationTime => int.parse(fields[kCreationTimeField]!.integerValue!);

  /// The creationTime number of failing checks.
  int get failed => int.parse(fields[kFailedField]!.integerValue!);

  /// The commit sha.
  String get commitSha => fields[kCommitShaField]!.stringValue!;

  static const keysOfImport = [
    kRemainingField,
    kCreationTimeField,
    kFailedField,
    kCommitShaField,
    fieldRepoFullPath,
    fieldCheckRunId,
    fieldStage,
  ];

  /// The recorded builds, a map of "build_name": "build details json".
  Map<String, TaskConclusion> get builds {
    return {
      for (final MapEntry(:key, :value) in fields.entries)
        if (!keysOfImport.contains(key))
          key: TaskConclusion.fromName(value.stringValue),
    };
  }

  /// Mark a [buildName] for a given [stage] with [conclusion].
  ///
  /// Returns a [CheckRunConclusion] record or throws. If the check_run was
  /// both valid and recorded successfully, the record's `remaining` value
  /// signals how many more tests are running. Returns the record (valid: false)
  /// otherwise.
  static Future<CheckRunConclusion> markConclusion({
    required FirestoreService firestoreService,
    required RepositorySlug slug,
    required String pullRequestId,
    required String checkRunId,
    required CiStage stage,
    required String buildName,
    required TaskConclusion conclusion,
  }) async {
    final changeCrumb = '${slug.owner}_${slug.name}_${pullRequestId}_$checkRunId';
    final logCrumb =
        'markConclusion(${changeCrumb}_$stage, $buildName, $conclusion)';

    // Marking needs to happen while in a transaction to ensure `remaining` is
    // updated correctly. For that to happen correctly; we need to perform a
    // read of the document in the transaction as well. So start the transaction
    // first thing.
    final transaction = await firestoreService.beginTransaction();

    var remaining = -1;
    var failed = -1;
    var valid = false;
    TaskConclusion? recordedConclusion;

    late final Document doc;

    // transaction block
    try {
      // First: read the fields we want to change.
      final documentName = documentNameFor(
        slug: slug,
        pullRequestId: pullRequestId,
        stage: stage,
        checkRunId: checkRunId,
      );
      doc = await firestoreService.getDocument(
        documentName,
        transaction: transaction,
      );

      final fields = doc.fields;
      if (fields == null) {
        throw '$logCrumb: missing fields for $transaction / $doc';
      }

      // Fields and remaining _must_ be present.
      final docRemaining = int.tryParse(
        fields[kRemainingField]?.integerValue ?? '',
      );
      if (docRemaining == null) {
        throw '$logCrumb: missing field "$kRemainingField" for $transaction / ${doc.fields}';
      }
      remaining = docRemaining;

      final maybeFailed = int.tryParse(
        fields[kFailedField]?.integerValue ?? '',
      );
      if (maybeFailed == null) {
        throw '$logCrumb: missing field "$kFailedField" for $transaction / ${doc.fields}';
      }
      failed = maybeFailed;

      // We will have tests scheduled after the engine was built successfully, so missing the buildName field
      // is an OK response to have. All fields should have been written at creation time.
      if (fields[buildName]?.stringValue case final name?) {
        recordedConclusion = TaskConclusion.fromName(name);
      }
      if (recordedConclusion == null) {
        log.info(
          '$logCrumb: $buildName not present in doc for $transaction / $doc',
        );
        await firestoreService.rollback(transaction);
        return CheckRunConclusion(
          result: CheckRunConclusionResult.missing,
          remaining: remaining,
          checkRunId: null,
          failed: failed,
          summary: 'Check run "$buildName" not present in $stage CI stage',
          details: 'Change $changeCrumb',
        );
      }

      // GitHub sends us 3 "action" messages for check_runs: created, completed, or rerequested.
      //   - We are responsible for the "created" messages.
      //   - The user is responsible for "rerequested"
      //   - LUCI is responsible for the completed.
      // Completed messages are either success / failure.
      // "remaining" should only go down if the previous state was scheduled - this is the first state
      // that is written by the scheduler.
      // "failed_count" can go up or down depending on:
      //   recordedConclusion == failure && conclusion == success: down (-1)
      //   recordedConclusion != failure && conclusion == failure: up (+1)
      // So if the test existed and either remaining or failed_count is changed; the response is valid.
      if (recordedConclusion == TaskConclusion.scheduled &&
          conclusion != TaskConclusion.scheduled) {
        // Guard against going negative and log enough info so we can debug.
        if (remaining == 0) {
          throw '$logCrumb: field "$kRemainingField" is already zero for $transaction / ${doc.fields}';
        }
        remaining = remaining - 1;
        valid = true;
      }

      // Only rollback the "failed" counter if this is a successful test run,
      // i.e. the test failed, the user requested a rerun, and now it passes.
      if (recordedConclusion == TaskConclusion.failure &&
          conclusion == TaskConclusion.success) {
        log.info(
          '$logCrumb: conclusion flipped to positive - assuming test was re-run',
        );
        if (failed == 0) {
          throw '$logCrumb: field "$kFailedField" is already zero for $transaction / ${doc.fields}';
        }
        valid = true;
        failed = failed - 1;
      }

      // Only increment the "failed" counter if the new conclusion flips from positive or neutral to failure.
      if ((recordedConclusion == TaskConclusion.scheduled ||
              recordedConclusion == TaskConclusion.success) &&
          conclusion == TaskConclusion.failure) {
        log.info('$logCrumb: test failed');
        valid = true;
        failed = failed + 1;
      }

      // All checks pass. "valid" is only set to true if there was a change in either the remaining or failed count.
      log.info(
        '$logCrumb: setting remaining to $remaining, failed to $failed, and changing $recordedConclusion',
      );
      fields[buildName] = conclusion.name.toValue();
      fields[kRemainingField] = remaining.toValue();
      fields[kFailedField] = failed.toValue();
    } on DetailedApiRequestError catch (e, stack) {
      if (e.status == 404) {
        // An attempt to read a document not in firestore should not be retried.
        log.info('$logCrumb: staging document not found for $transaction');
        await firestoreService.rollback(transaction);
        return CheckRunConclusion(
          result: CheckRunConclusionResult.internalError,
          remaining: -1,
          checkRunId: null,
          failed: failed,
          summary: 'Internal server error',
          details:
              '''
Staging document not found for CI stage "$stage" for $changeCrumb. Got 404 from
Firestore.

Error:
${e.toString()}
$stack
''',
        );
      }
      // All other errors should bubble up and be retried.
      await firestoreService.rollback(transaction);
      rethrow;
    } catch (e) {
      // All other errors should bubble up and be retried.
      await firestoreService.rollback(transaction);
      rethrow;
    }

    // Commit this write firebase and if no one else was writing at the same time, return success.
    // If this commit fails, that means someone else modified firestore and the caller should try again.
    // We do not need to rollback the transaction; firebase documentation says a failed commit takes care of that.
    final response = await firestoreService.commit(
      transaction,
      documentsToWrites([doc], exists: true),
    );
    log.info(
      '$logCrumb: results = ${response.writeResults?.map((e) => e.toJson())}',
    );
    return CheckRunConclusion(
      result: valid
          ? CheckRunConclusionResult.ok
          : CheckRunConclusionResult.internalError,
      remaining: remaining,
      checkRunId: checkRunId,
      failed: failed,
      summary: valid
          ? 'All tests passed'
          : 'Not a valid state transition for $buildName',
      details: valid
          ? '''
For CI stage $stage:
  Pending: $remaining
  Failed: $failed
'''
          : ''
                'Attempted to transition the state of check run $buildName '
                'from "${recordedConclusion.name}" to "${conclusion.name}".',
    );
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
    required String pullRequestId,
    required String checkRunId,
    required CiStage stage,
    required List<String> tasks,
    required String commitSha,
  }) async {
    final logCrumb =
        'initializeDocument(${slug.owner}_${slug.name}_${pullRequestId}_${checkRunId}_$stage, ${tasks.length} tasks)';

    final fields = <String, Value>{
      kCreationTimeField: tasks.length.toValue(),
      kRemainingField: tasks.length.toValue(),
      kFailedField: 0.toValue(),
      kCommitShaField: commitSha.toValue(),
      fieldRepoFullPath: slug.fullName.toValue(),
      fieldCheckRunId: checkRunId.toValue(),
      fieldStage: stage.name.toValue(),
      for (final task in tasks) task: TaskConclusion.scheduled.name.toValue(),
    };

    final document = Document(fields: fields);

    try {
      // Calling createDocument multiple times for the same documentId will return a 409 - ALREADY_EXISTS error;
      // this is good because it means we don't have to do any transactions.
      // curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer <TOKEN>" "https://firestore.googleapis.com/v1beta1/projects/flutter-dashboard/databases/cocoon/documents/unified_check_run?documentId=foo_bar_baz" -d '{"fields": {"test": {"stringValue": "baz"}}}'
      final newDoc = await firestoreService.createDocument(
        document,
        collectionId: _collectionId,
        documentId: documentIdFor(
          slug: slug,
          pullRequestId: pullRequestId,
          checkRunId: checkRunId,
          stage: stage, //
        ).documentId,
      );
      log.info('$logCrumb: document created');
      return newDoc;
    } catch (e) {
      log.warn('$logCrumb: failed to create document', e);
      rethrow;
    }
  }
}

/// Represents the conclusion of a [Task] within a [UnifiedCheckRun] document.
enum TaskConclusion {
  /// An unknown task conclusion.
  unknown,

  /// A task is scheduled to run.
  scheduled,

  /// A task was completed as a success.
  success,

  /// A task was completed as a failure.
  failure;

  /// Returns a [TaskConclusion] from a [name].
  factory TaskConclusion.fromName(String? name) {
    for (final value in TaskConclusion.values) {
      if (value.name == name) {
        return value;
      }
    }
    return TaskConclusion.unknown;
  }

  /// Whether the task is completed or not.
  bool get isComplete => this != scheduled;

  /// Whether the task is a success or not.
  bool get isSuccess => this == success;
}

/// Well-defined stages in the build infrastructure.
enum CiStage implements Comparable<CiStage> {
  /// Build engine artifacts
  fusionEngineBuild('engine'),

  /// All non-engine artifact tests (engine & framework)
  fusionTests('fusion');

  const CiStage(this.name);

  final String name;

  @override
  int compareTo(CiStage other) => index - other.index;

  @override
  String toString() => name;
}

/// Explains what happened when attempting to mark the conclusion of a check run
/// using [UnifiedCheckRun.markConclusion].
enum CheckRunConclusionResult {
  /// Check run update recorded successfully in the respective CI stage.
  ///
  /// It is OK to evaluate returned results for stage completeness.
  ok,

  /// The check run is not in the specified CI stage.
  ///
  /// Perhaps it's from a different CI stage.
  missing,

  /// An unexpected error happened, and the results of the conclusion are
  /// undefined.
  ///
  /// Examples of situations that can lead to this result:
  ///
  /// * The Firestore document is missing.
  /// * The contents of the Firestore document are inconsistent.
  /// * An unexpected error happend while trying to read from/write to Firestore.
  ///
  /// When this happens, it's best to stop the current transaction, report the
  /// error to the logs, and have someone investigate the issue.
  internalError,
}

/// Results from attempting to mark a staging task as completed.
///
/// See: [UnifiedCheckRun.markConclusion]
class CheckRunConclusion {
  final CheckRunConclusionResult result;
  final int remaining;
  final String? checkRunId;
  final int failed;
  final String summary;
  final String details;

  const CheckRunConclusion({
    required this.result,
    required this.remaining,
    required this.checkRunId,
    required this.failed,
    required this.summary,
    required this.details,
  });

  bool get isOk => result == CheckRunConclusionResult.ok;

  bool get isPending => isOk && remaining > 0;

  bool get isFailed => isOk && !isPending && failed > 0;

  bool get isComplete => isOk && !isPending && !isFailed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckRunConclusion &&
          other.result == result &&
          other.remaining == remaining &&
          other.checkRunId == checkRunId &&
          other.failed == failed &&
          other.summary == summary &&
          other.details == details);

  @override
  int get hashCode =>
      Object.hashAll([result, remaining, checkRunId, failed, summary, details]);

  @override
  String toString() =>
      'BuildConclusion("$result", "$remaining", "$checkRunId", "$failed", "$summary", "$details")';
}
