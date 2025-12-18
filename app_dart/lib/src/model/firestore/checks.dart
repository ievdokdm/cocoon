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

import '../../service/config.dart';
import '../../service/firestore.dart';
import 'base.dart';
import 'ci_staging.dart';
import 'unified_check_run.dart';
import 'unified_check_run_build.dart';

final class Checks {
  static Future<void> initializeCiStagingDocument({
    required FirestoreService firestoreService,
    required RepositorySlug slug,
    required String sha,
    required CiStage stage,
    required List<String> tasks,
    required Config config,
    PullRequest? pullRequest,
    CheckRun? checkRun,
  }) async {
    if (checkRun != null &&
        pullRequest != null &&
        config.flags.isUnifiedCheckRunFlowEnabledForUser(
          pullRequest.user!.login!,
        )) {
      log.info(
        'Storing UnifiedCheckRun data for ${slug.fullName}#${pullRequest.number} as it enabled for user ${pullRequest.user!.login}.',
      );
      // Create the UnifiedCheckRun and UnifiedCheckRunBuilds.
      final check = UnifiedCheckRun(
        checkRunId: checkRun.id!,
        commitSha: sha,
        slug: slug,
        pullRequestId: pullRequest.number!,
        stage: stage,
        creationTime: pullRequest.createdAt!.microsecondsSinceEpoch,
        author: pullRequest.user!.login!,
        remainingBuilds: null,
        failedBuilds: null,
      );
      final builds = [
        ...tasks.map(
          (t) => UnifiedCheckRunBuild.init(
            buildName: t,
            checkRunId: checkRun.id!,
            creationTime: pullRequest.createdAt!.microsecondsSinceEpoch,
          ),
        ),
      ];
      await firestoreService.writeViaTransaction(
        documentsToWrites([...builds, check], exists: false),
      );
    } else {
      // Initialize the CiStaging document.
      await CiStaging.initializeDocument(
        firestoreService: firestoreService,
        slug: slug,
        sha: sha,
        stage: stage,
        tasks: tasks,
        checkRunGuard: checkRun != null ? '$checkRun' : '',
      );
    }
  }
}
