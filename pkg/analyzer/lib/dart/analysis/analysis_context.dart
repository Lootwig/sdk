// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/src/generated/engine.dart';

/// A representation of a body of code and the context in which the code is to
/// be analyzed.
///
/// The body of code is represented as a collection of files and directories, as
/// defined by the list of included paths. If the list of included paths
/// contains one or more directories, then zero or more files or directories
/// within the included directories can be excluded from analysis, as defined by
/// the list of excluded paths.
///
/// Clients may not extend, implement or mix-in this class.
abstract class AnalysisContext {
  /// The analysis options used to control the way the code is analyzed.
  AnalysisOptions get analysisOptions;

  /// Return the context root from which this context was created.
  ContextRoot get contextRoot;

  /// Return the currently active analysis session.
  AnalysisSession get currentSession;

  /// A list of the absolute, normalized paths of files and directories that
  /// will not be analyzed.
  ///
  /// Deprecated: Use `contextRoot.excludedPaths`.
  @deprecated
  List<String> get excludedPaths;

  /// A list of the absolute, normalized paths of files and directories that
  /// will be analyzed. If a path in the list represents a file, then that file
  /// will be analyzed, even if it is in the list of [excludedPaths]. If path in
  /// the list represents a directory, then all of the files contained in that
  /// directory, either directly or indirectly, and that are not explicitly
  /// excluded by the list of [excludedPaths] will be analyzed.
  ///
  /// Deprecated: Use `contextRoot.includedPaths`.
  @deprecated
  List<String> get includedPaths;

  /// Return the absolute, normalized paths of all of the files that are
  /// contained in this context. These are all of the files that are included
  /// directly or indirectly by one or more of the [includedPaths] and that are
  /// not excluded by any of the [excludedPaths].
  ///
  /// Deprecated: Use `contextRoot.analyzedFiles`.
  @deprecated
  Iterable<String> analyzedFiles();

  /// Return `true` if the file or directory with the given [path] will be
  /// analyzed in this context. A file (or directory) will be analyzed if it is
  /// either the same as or contained in one of the [includedPaths] and, if it
  /// is contained in one of the [includedPaths], is not the same as or
  /// contained in one of the [excludedPaths].
  ///
  /// Deprecated: Use `contextRoot.isAnalyzed`.
  @deprecated
  bool isAnalyzed(String path);
}
