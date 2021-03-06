// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UndefinedExtensionMethodTest);
  });
}

@reflectiveTest
class UndefinedExtensionMethodTest extends DriverResolutionTest {
  @override
  AnalysisOptionsImpl get analysisOptions => AnalysisOptionsImpl()
    ..contextFeatures = new FeatureSet.forTesting(
        sdkVersion: '2.3.0', additionalFeatures: [Feature.extension_methods]);

  test_method_defined() async {
    await assertNoErrorsInCode('''
extension E on String {
  int m() => 0;
}
f() {
  E('a').m();
}
''');
  }

  test_method_undefined() async {
    await assertErrorsInCode('''
extension E on String {}
f() {
  E('a').m();
}
''', [
      error(CompileTimeErrorCode.UNDEFINED_EXTENSION_METHOD, 40, 1),
    ]);
    var invocation = findNode.methodInvocation('m();');
    assertMethodInvocation(
      invocation,
      null,
      'dynamic',
      expectedType: 'dynamic',
    );
  }

  test_operator_defined() async {
    await assertNoErrorsInCode('''
extension E on String {
  void operator +(int offset) {}
}
f() {
  E('a') + 1;
}
''');
  }

  test_operator_undefined() async {
    await assertErrorsInCode('''
extension E on String {}
f() {
  E('a') + 1;
}
''', [
      error(CompileTimeErrorCode.UNDEFINED_EXTENSION_METHOD, 40, 1),
    ]);
    var binaryExpression = findNode.binary('+ 1');
    assertElementNull(binaryExpression);
    assertInvokeTypeNull(binaryExpression);
    assertTypeDynamic(binaryExpression);
  }

  test_static_withInference() async {
    await assertErrorsInCode('''
extension E on Object {}
var a = E.m();
''', [
      error(CompileTimeErrorCode.UNDEFINED_EXTENSION_METHOD, 35, 1),
    ]);
  }

  test_static_withoutInference() async {
    await assertErrorsInCode('''
extension E on Object {}
void f() {
  E.m();
}
''', [
      error(CompileTimeErrorCode.UNDEFINED_EXTENSION_METHOD, 40, 1),
    ]);
  }
}
