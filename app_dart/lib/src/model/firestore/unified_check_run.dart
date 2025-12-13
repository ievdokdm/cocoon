// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library;

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
  static const fieldPullRequestId = 'pull_request_id';
  static const fieldCreationTime = 'creation_time';
  static const fieldRemainingBuilds = 'remaining_builds';
  static const fieldFailedBuilds = 'failed_builds';

  static String documentId({
    required RepositorySlug slug,
    required int checkRunId,
    required CiStage stage,
  }) => '${slug.owner}_${slug.name}_${checkRunId}_${stage.name}';

  @override
  AppDocumentMetadata<UnifiedCheckRun> get runtimeMetadata => metadata;

  static final metadata = AppDocumentMetadata<UnifiedCheckRun>(
    collectionId: collectionId,
    fromDocument: UnifiedCheckRun.fromDocument,
  );

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
      fieldPullRequestId: pullRequestId.toValue(),
      fieldCreationTime: creationTime.toValue(),
      fieldAuthor: author.toValue(),
      if (remainingBuilds != null)
        fieldRemainingBuilds: remainingBuilds.toValue(),
      if (failedBuilds != null) fieldFailedBuilds: failedBuilds.toValue(),
    };
    return UnifiedCheckRun._(
      fields,
      name:
          '$kDatabase/documents/$collectionId/${documentId(slug: slug, checkRunId: checkRunId, stage: stage)}',
    );
  }

  UnifiedCheckRun._(Map<String, Value> fields, {required String name}) {
    this.fields = fields;
    this.name = name;
  }

  String get commitSha => fields[fieldCommitSha]!.stringValue!;
  String get author => fields[fieldAuthor]!.stringValue!;
  int get pullRequestId => int.parse(fields[fieldPullRequestId]!.integerValue!);
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

  /// Which commit this stage is recorded for.
  String get checkRunId {
    // Read it from the document name.
    final [_, _, _, checkRunId, _] = p.posix.basename(name!).split('_');
    return checkRunId;
  }

  /// The stage of the CI process.
  CiStage get stage {
    // Read it from the document name.
    final [_, _, _, _, stageName] = p.posix.basename(name!).split('_');
    return CiStage.values.byName(stageName);
  }
}
