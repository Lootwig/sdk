// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/lsp_protocol/protocol_special.dart';
import 'package:analysis_server/src/lsp/handlers/handler_document_symbols.dart'
    show defaultSupportedSymbolKinds;
import 'package:analysis_server/src/lsp/handlers/handlers.dart';
import 'package:analysis_server/src/lsp/lsp_analysis_server.dart';
import 'package:analysis_server/src/lsp/mapping.dart';
import 'package:analyzer/source/line_info.dart';

import 'package:analyzer/src/dart/analysis/search.dart' as search;

class WorkspaceSymbolHandler
    extends MessageHandler<WorkspaceSymbolParams, List<SymbolInformation>> {
  WorkspaceSymbolHandler(LspAnalysisServer server) : super(server);
  Method get handlesMessage => Method.workspace_symbol;

  @override
  WorkspaceSymbolParams convertParams(Map<String, dynamic> json) =>
      WorkspaceSymbolParams.fromJson(json);

  Future<ErrorOr<List<SymbolInformation>>> handle(
      WorkspaceSymbolParams params) async {
    // Respond to empty queries with an empty list. The spec says this should
    // be non-empty, however VS Code's client sends empty requests (but then
    // appears to not render the results we supply anyway).
    final query = params?.query ?? '';
    if (query == '') {
      return success([]);
    }

    final symbolCapabilities = server?.clientCapabilities?.workspace?.symbol;

    final clientSupportedSymbolKinds =
        symbolCapabilities?.symbolKind?.valueSet != null
            ? new HashSet<SymbolKind>.of(symbolCapabilities.symbolKind.valueSet)
            : defaultSupportedSymbolKinds;

    // Convert the string input into a case-insensitive regex that has wildcards
    // between every character and at start/end to allow for fuzzy matching.
    final fuzzyQuery = query.split('').map(RegExp.escape).join('.*');
    final partialFuzzyQuery = '.*$fuzzyQuery.*';
    final regex = new RegExp(partialFuzzyQuery, caseSensitive: false);

    // Cap the number of results we'll return because short queries may match
    // huge numbers on large projects.
    var remainingResults = 500;

    final declarations = <search.Declaration>[];
    final filePathsHashSet = new LinkedHashSet<String>();
    for (var driver in server.driverMap.values) {
      final driverResults = await driver.search
          .declarations(regex, remainingResults, filePathsHashSet);
      declarations.addAll(driverResults);
      remainingResults -= driverResults.length;
    }

    // Convert the file paths to something we can quickly index into since
    // we'll be looking things up by index a lot.
    final filePaths = filePathsHashSet.toList();
    // We'll need line information to convert locations, so fetch
    // them once and allow looking up using the file index.
    final lineInfos = filePaths.map(server.getLineInfo).toList();

    // Map the results to SymbolInformations and flatten the list of lists.
    final symbols = declarations
        .map((declaration) => _asSymbolInformation(
              declaration,
              clientSupportedSymbolKinds,
              filePaths,
              lineInfos,
            ))
        .toList();

    return success(symbols);
  }

  SymbolInformation _asSymbolInformation(
    search.Declaration declaration,
    HashSet<SymbolKind> clientSupportedSymbolKinds,
    List<String> filePaths,
    List<LineInfo> lineInfos,
  ) {
    final filePath = filePaths[declaration.fileIndex];
    final lineInfo = lineInfos[declaration.fileIndex];
    return new SymbolInformation(
        declaration.name,
        declarationKindToSymbolKind(
            clientSupportedSymbolKinds, declaration.kind),
        null, // We don't have easy access to isDeprecated here.
        new Location(
          Uri.file(filePath).toString(),
          toRange(lineInfo, declaration.codeOffset, declaration.codeLength),
        ),
        declaration.className ?? declaration.mixinName);
  }
}