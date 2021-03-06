// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.type_builder;

import 'package:kernel/ast.dart' show DartType, Supertype;

import '../fasta_codes.dart' show LocatedMessage;

import '../scope.dart';
import 'library_builder.dart';
import 'named_type_builder.dart';
import 'type_declaration_builder.dart';
import 'type_variable_builder.dart';

abstract class TypeBuilder {
  const TypeBuilder();

  TypeDeclarationBuilder get declaration => null;

  void resolveIn(
      Scope scope, int charOffset, Uri fileUri, LibraryBuilder library) {}

  /// See `UnresolvedType.checkType`.
  void check(LibraryBuilder library, int charOffset, Uri fileUri) {}

  /// See `UnresolvedType.normalizeType`.
  void normalize(int charOffset, Uri fileUri) {}

  void bind(TypeDeclarationBuilder builder) {}

  /// May return null, for example, for mixin applications.
  Object get name;

  String get debugName;

  StringBuffer printOn(StringBuffer buffer);

  String toString() => "$debugName(${printOn(new StringBuffer())})";

  /// Returns the [TypeBuilder] for this type in which [TypeVariableBuilder]s
  /// in [substitution] have been replaced by the corresponding [TypeBuilder]s.
  ///
  /// If [unboundTypes] is provided, created type builders that are not bound
  /// are added to [unboundTypes]. Otherwise, creating an unbound type builder
  /// throws an error.
  // TODO(johnniwinther): Change [NamedTypeBuilder] to hold the
  // [TypeParameterScopeBuilder] should resolve it, so that we cannot create
  // [NamedTypeBuilder]s that are orphaned.
  TypeBuilder subst(Map<TypeVariableBuilder, TypeBuilder> substitution,
          [List<NamedTypeBuilder> unboundTypes]) =>
      this;

  /// Clones the type builder recursively without binding the subterms to
  /// existing declaration or type variable builders.  All newly built types
  /// are added to [newTypes], so that they can be added to a proper scope and
  /// resolved later.
  TypeBuilder clone(List<TypeBuilder> newTypes);

  buildInvalidType(LocatedMessage message, {List<LocatedMessage> context});

  String get fullNameForErrors => "${printOn(new StringBuffer())}";

  DartType build(LibraryBuilder library);

  Supertype buildSupertype(LibraryBuilder library, int charOffset, Uri fileUri);

  Supertype buildMixedInType(
      LibraryBuilder library, int charOffset, Uri fileUri);
}
