// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:expect/expect.dart';

import 'package:test_runner/src/feature.dart';
import 'package:test_runner/src/path.dart';
import 'package:test_runner/src/static_error.dart';
import 'package:test_runner/src/test_file.dart';

import 'utils.dart';

// Note: This test file validates how some of the special markers used by the
// test runner are parsed. But this test is also run *by* that same test
// runner, and we don't want it to see the markers inside the string literals
// here as significant, so we obfuscate them using seemingly-pointless string
// escapes here like `\/`.

void main() {
  testParseDill();
  testParseVMOptions();
  testParseOtherOptions();
  testParseEnvironment();
  testParsePackages();
  testParseMultitest();
  testParseMultiHtmltest();
  testParseErrorFlags();
  testParseErrorExpectations();
  testName();
  testMultitest();
  testShardHash();
}

void testParseDill() {
  // Handles ".dill" files.
  var file = parseTestFile("", path: "test.dill");
  Expect.isNotNull(file.vmOptions);
  Expect.equals(1, file.vmOptions.length);
  Expect.listEquals(<String>[], file.vmOptions.first);

  Expect.listEquals(<String>[], file.dartOptions);
  Expect.listEquals(<String>[], file.sharedOptions);
  Expect.listEquals(<String>[], file.dart2jsOptions);
  Expect.listEquals(<String>[], file.ddcOptions);
  Expect.listEquals(<String>[], file.otherResources);
  Expect.listEquals(<String>[], file.sharedObjects);

  Expect.isNull(file.environment);
  Expect.isNull(file.packages);

  Expect.isFalse(file.isMultitest);

  Expect.isFalse(file.hasSyntaxError);
  Expect.isFalse(file.hasCompileError);
  Expect.isFalse(file.hasRuntimeError);
  Expect.isFalse(file.hasStaticWarning);
  Expect.isFalse(file.hasCrash);
}

void testParseVMOptions() {
  expectVMOptions(String source, List<List<String>> expected) {
    var file = parseTestFile(source);
    Expect.isNotNull(file.vmOptions);
    Expect.equals(expected.length, file.vmOptions.length);
    for (var i = 0; i < expected.length; i++) {
      Expect.listEquals(expected[i], file.vmOptions[i]);
    }
  }

  // No options.
  expectVMOptions("", [[]]);

  // Splits words.
  expectVMOptions("/\/ VMOptions=--verbose --async", [
    ["--verbose", "--async"]
  ]);

  // Allows multiple.
  expectVMOptions("""
  /\/ VMOptions=--first one
  /\/ VMOptions=--second two
  """, [
    ["--first", "one"],
    ["--second", "two"]
  ]);
}

void testParseOtherOptions() {
  // No options.
  var file = parseTestFile("");
  Expect.listEquals(<String>[], file.dartOptions);
  Expect.listEquals(<String>[], file.sharedOptions);
  Expect.listEquals(<String>[], file.dart2jsOptions);
  Expect.listEquals(<String>[], file.ddcOptions);
  Expect.listEquals(<String>[], file.otherResources);
  Expect.listEquals(<String>[], file.sharedObjects);
  Expect.listEquals(<String>[], file.requirements);

  // Single options split into words.
  file = parseTestFile("""
  /\/ DartOptions=dart options
  /\/ SharedOptions=shared options
  /\/ dart2jsOptions=dart2js options
  /\/ dartdevcOptions=ddc options
  /\/ OtherResources=other resources
  /\/ SharedObjects=shared objects
  /\/ Requirements=nnbd nnbd-strong
  """);
  Expect.listEquals(["dart", "options"], file.dartOptions);
  Expect.listEquals(["shared", "options"], file.sharedOptions);
  Expect.listEquals(["dart2js", "options"], file.dart2jsOptions);
  Expect.listEquals(["ddc", "options"], file.ddcOptions);
  Expect.listEquals(["other", "resources"], file.otherResources);
  Expect.listEquals([Feature.nnbd, Feature.nnbdStrong], file.requirements);

  // Disallows multiple lines for some options.
  expectParseThrows("""
  /\/ DartOptions=first
  /\/ DartOptions=second
  """);
  expectParseThrows("""
  /\/ SharedOptions=first
  /\/ SharedOptions=second
  """);
  expectParseThrows("""
  /\/ dart2jsOptions=first
  /\/ dart2jsOptions=second
  """);
  expectParseThrows("""
  /\/ dartdevcOptions=first
  /\/ dartdevcOptions=second
  """);
  expectParseThrows("""
  /\/ Requirements=nnbd
  /\/ Requirements=nnbd-strong
  """);

  // Merges multiple lines for others.
  file = parseTestFile("""
  /\/ OtherResources=other resources
  /\/ OtherResources=even more
  /\/ SharedObjects=shared objects
  /\/ SharedObjects=many more
  """);
  Expect.listEquals(
      ["other", "resources", "even", "more"], file.otherResources);
  Expect.listEquals(["shared", "objects", "many", "more"], file.sharedObjects);

  // Disallows unrecognized features in requirements.
  expectParseThrows("""
  /\/ Requirements=unknown-feature
  """);
}

void testParseEnvironment() {
  // No environment.
  var file = parseTestFile("");
  Expect.isNull(file.environment);

  // Without values.
  file = parseTestFile("""
  /\/ Environment=some value
  /\/ Environment=another one
  """);
  Expect.mapEquals({"some value": "", "another one": ""}, file.environment);

  // With values.
  file = parseTestFile("""
  /\/ Environment=some value=its value
  /\/ Environment=another one   =   also value
  """);
  Expect.mapEquals(
      {"some value": "its value", "another one   ": "   also value"},
      file.environment);
}

void testParsePackages() {
  // No option.
  var file = parseTestFile("");
  Expect.isNull(file.packages);

  // Single option is converted to a path.
  file = parseTestFile("""
  /\/ Packages=packages thing
  """);
  Expect.isTrue(
      file.packages.endsWith("${Platform.pathSeparator}packages thing"));

  // "none" is left alone.
  file = parseTestFile("""
  /\/ Packages=none
  """);
  Expect.equals("none", file.packages);

  // Cannot appear more than once.
  expectParseThrows("""
  /\/ Packages=first
  /\/ Packages=second
  """);
}

void testParseMultitest() {
  // Not present.
  var file = parseTestFile("");
  Expect.isFalse(file.isMultitest);

  // Present.
  file = parseTestFile("""
  main() {} /\/# 01: compile-time error
  """);
  Expect.isTrue(file.isMultitest);
}

void testParseMultiHtmltest() {
  // Not present.
  var file = parseTestFile("");
  Expect.isFalse(file.isMultiHtmlTest);
  Expect.listEquals(<String>[], file.subtestNames);

  // Present.
  // Note: the "${''}" is to prevent the test runner running *this* test file
  // from parsing it as a multi-HTML test.
  file = parseTestFile("""
  main() {
    useHtml\IndividualConfiguration();
    group('pixel_manipulation', () {
    });
    group('arc', () {
    });
    group('drawImage_image_element', () {
    });
  }
  """);
  Expect.isTrue(file.isMultiHtmlTest);
  Expect.listEquals(["pixel_manipulation", "arc", "drawImage_image_element"],
      file.subtestNames);
}

void testParseErrorFlags() {
  // Not present.
  var file = parseTestFile("");
  Expect.isFalse(file.hasSyntaxError);
  Expect.isFalse(file.hasCompileError);
  Expect.isFalse(file.hasRuntimeError);
  Expect.isFalse(file.hasStaticWarning);
  Expect.isFalse(file.hasCrash);

  file = parseTestFile("@syntax\-error");
  Expect.isTrue(file.hasSyntaxError);
  Expect.isTrue(file.hasCompileError); // Note: true.
  Expect.isFalse(file.hasRuntimeError);
  Expect.isFalse(file.hasStaticWarning);
  Expect.isFalse(file.hasCrash);

  file = parseTestFile("@compile\-error");
  Expect.isFalse(file.hasSyntaxError);
  Expect.isTrue(file.hasCompileError);
  Expect.isFalse(file.hasRuntimeError);
  Expect.isFalse(file.hasStaticWarning);
  Expect.isFalse(file.hasCrash);

  file = parseTestFile("@runtime\-error");
  Expect.isFalse(file.hasSyntaxError);
  Expect.isFalse(file.hasCompileError);
  Expect.isTrue(file.hasRuntimeError);
  Expect.isFalse(file.hasStaticWarning);
  Expect.isFalse(file.hasCrash);

  file = parseTestFile("@static\-warning");
  Expect.isFalse(file.hasSyntaxError);
  Expect.isFalse(file.hasCompileError);
  Expect.isFalse(file.hasRuntimeError);
  Expect.isTrue(file.hasStaticWarning);
  Expect.isFalse(file.hasCrash);
}

void testParseErrorExpectations() {
  // No errors.
  expectParseErrorExpectations("""
main() {}
""", []);

  // Empty file
  expectParseErrorExpectations("", []);

  // Multiple errors.
  expectParseErrorExpectations("""
int i = "s";
/\/      ^^^
/\/ [analyzer] CompileTimeErrorCode.WRONG_TYPE
/\/ [cfe] Error: Can't assign a string to an int.

num j = "str";
  /\/    ^^^^^
/\/ [analyzer] CompileTimeErrorCode.ALSO_WRONG_TYPE
    /\/ [cfe] Error: Can't assign a string to a num.
""", [
    StaticError(
        line: 1,
        column: 9,
        length: 3,
        code: "CompileTimeErrorCode.WRONG_TYPE",
        message: "Error: Can't assign a string to an int."),
    StaticError(
        line: 6,
        column: 9,
        length: 5,
        code: "CompileTimeErrorCode.ALSO_WRONG_TYPE",
        message: "Error: Can't assign a string to a num.")
  ]);

  // Explicit error location.
  expectParseErrorExpectations("""
/\/ [error line 123, column 45, length 678]
/\/ [analyzer] CompileTimeErrorCode.FIRST
/\/ [cfe] First error.
  /\/   [ error line   23  ,  column   5  ,  length   78  ]
/\/ [analyzer] CompileTimeErrorCode.SECOND
/\/ [cfe] Second error.
/\/[error line 9,column 8,length 7]
/\/ [cfe] Third.
/\/[error line 10,column 9]
/\/ [cfe] No length.
""", [
    StaticError(
        line: 123,
        column: 45,
        length: 678,
        code: "CompileTimeErrorCode.FIRST",
        message: "First error."),
    StaticError(
        line: 23,
        column: 5,
        length: 78,
        code: "CompileTimeErrorCode.SECOND",
        message: "Second error."),
    StaticError(line: 9, column: 8, length: 7, message: "Third."),
    StaticError(line: 10, column: 9, message: "No length.")
  ]);

  // Multi-line error message.
  expectParseErrorExpectations("""
int i = "s";
/\/      ^^^
/\/ [analyzer] CompileTimeErrorCode.WRONG_TYPE
/\/ [cfe] First line.
/\/Second line.
    /\/     Third line.

/\/ The preceding blank line ends the message.
""", [
    StaticError(
        line: 1,
        column: 9,
        length: 3,
        code: "CompileTimeErrorCode.WRONG_TYPE",
        message: "First line.\nSecond line.\nThird line.")
  ]);

  // Multiple errors attached to same line.
  expectParseErrorExpectations("""
main() {}
int i = "s";
/\/      ^^^
/\/ [cfe] First error.
/\/    ^
/\/ [analyzer] ErrorCode.second
/\/  ^^^^^^^
/\/ [cfe] Third error.
""", [
    StaticError(line: 2, column: 9, length: 3, message: "First error."),
    StaticError(line: 2, column: 7, length: 1, code: "ErrorCode.second"),
    StaticError(line: 2, column: 5, length: 7, message: "Third error."),
  ]);

  // Unspecified errors.
  expectParseErrorExpectations("""
int i = "s";
/\/     ^^^
// [analyzer] unspecified
// [cfe] unspecified
int j = "s";
/\/     ^^^
// [analyzer] unspecified
// [cfe] Message.
int k = "s";
/\/     ^^^
// [analyzer] Error.CODE
// [cfe] unspecified
int l = "s";
/\/     ^^^
// [analyzer] unspecified
int m = "s";
/\/     ^^^
// [cfe] unspecified
""", [
    StaticError(
        line: 1,
        column: 8,
        length: 3,
        code: "unspecified",
        message: "unspecified"),
    StaticError(
        line: 5,
        column: 8,
        length: 3,
        code: "unspecified",
        message: "Message."),
    StaticError(
        line: 9,
        column: 8,
        length: 3,
        code: "Error.CODE",
        message: "unspecified"),
    StaticError(line: 13, column: 8, length: 3, code: "unspecified"),
    StaticError(line: 16, column: 8, length: 3, message: "unspecified"),
  ]);

  // Ignore multitest markers.
  expectParseErrorExpectations("""
int i = "s";
/\/      ^^^ /\/# 0: ok
/\/ [analyzer] ErrorCode.BAD_THING /\/# 123: continued
/\/ [cfe] Message.  /\/# named: compile-time error
/\/ More message.  /\/#   another: ok
/\/ [error line 12, column 34, length 56]  /\/# 3: continued
/\/ [cfe] Message.
""", [
    StaticError(
        line: 1,
        column: 9,
        length: 3,
        code: "ErrorCode.BAD_THING",
        message: "Message.\nMore message."),
    StaticError(line: 12, column: 34, length: 56, message: "Message."),
  ]);

  // Must have either a code or a message.
  expectFormatError("""
int i = "s";
/\/      ^^^

var wrong;
""");

  // Location must follow some real code.
  expectFormatError("""
/\/ [error line 123, column 45, length 678]
/\/ [analyzer] CompileTimeErrorCode.FIRST
/\/ ^^^
/\/ [cfe] This doesn't make sense.
""");

  // Location at end without code or message.
  expectFormatError("""
int i = "s";
/\/ ^^^
""");

  // Code cannot follow message.
  expectFormatError("""
int i = "s";
/\/      ^^^
/\/ [cfe] Error message.
/\/ [analyzer] ErrorCode.BAD_THING
""");

  // Analyzer error must look like an error code.
  expectFormatError("""
int i = "s";
/\/      ^^^
/\/ [analyzer] Not error code.
""");

  // A CFE-only error with length one is treated as having no length.
  expectParseErrorExpectations("""
int i = "s";
/\/      ^
/\/ [cfe] Message.

int j = "s";
/\/      ^
/\/ [analyzer] Error.BAD
/\/ [cfe] Message.
""", [
    StaticError(line: 1, column: 9, length: null, message: "Message."),
    StaticError(
        line: 5, column: 9, length: 1, code: "Error.BAD", message: "Message."),
  ]);
}

void testName() {
  // Immediately inside suite.
  var file = TestFile.parse(Path("suite").absolute,
      Path("suite/a_test.dart").absolute.toNativePath(), "");
  Expect.equals("a_test", file.name);

  // Inside subdirectory.
  file = TestFile.parse(Path("suite").absolute,
      Path("suite/a/b/c_test.dart").absolute.toNativePath(), "");
  Expect.equals("a/b/c_test", file.name);

  // Multitest.
  file = file.split(Path("suite/a/b/c_test_00.dart").absolute, "00", "");
  Expect.equals("a/b/c_test/00", file.name);
}

void testMultitest() {
  var file = parseTestFile("", path: "origin.dart");
  Expect.isFalse(file.hasSyntaxError);
  Expect.isFalse(file.hasCompileError);
  Expect.isFalse(file.hasRuntimeError);
  Expect.isFalse(file.hasStaticWarning);

  var a = file.split(Path("a.dart").absolute, "a", "", hasSyntaxError: true);
  Expect.isTrue(a.originPath.toNativePath().endsWith("origin.dart"));
  Expect.isTrue(a.path.toNativePath().endsWith("a.dart"));
  Expect.isTrue(a.hasSyntaxError);
  Expect.isFalse(a.hasCompileError);
  Expect.isFalse(a.hasRuntimeError);
  Expect.isFalse(a.hasStaticWarning);

  var b = file.split(
    Path("b.dart").absolute,
    "b",
    "",
    hasCompileError: true,
  );
  Expect.isTrue(b.originPath.toNativePath().endsWith("origin.dart"));
  Expect.isTrue(b.path.toNativePath().endsWith("b.dart"));
  Expect.isFalse(b.hasSyntaxError);
  Expect.isTrue(b.hasCompileError);
  Expect.isFalse(b.hasRuntimeError);
  Expect.isFalse(b.hasStaticWarning);

  var c = file.split(Path("c.dart").absolute, "c", "", hasRuntimeError: true);
  Expect.isTrue(c.originPath.toNativePath().endsWith("origin.dart"));
  Expect.isTrue(c.path.toNativePath().endsWith("c.dart"));
  Expect.isFalse(c.hasSyntaxError);
  Expect.isFalse(c.hasCompileError);
  Expect.isTrue(c.hasRuntimeError);
  Expect.isFalse(c.hasStaticWarning);

  var d = file.split(Path("d.dart").absolute, "d", "", hasStaticWarning: true);
  Expect.isTrue(d.originPath.toNativePath().endsWith("origin.dart"));
  Expect.isTrue(d.path.toNativePath().endsWith("d.dart"));
  Expect.isFalse(d.hasSyntaxError);
  Expect.isFalse(d.hasCompileError);
  Expect.isFalse(d.hasRuntimeError);
  Expect.isTrue(d.hasStaticWarning);
}

void testShardHash() {
  // Test files with paths should successfully return some kind of integer. We
  // don't want to depend on the hash algorithm, so we can't really be more
  // specific than that.
  var testFile = parseTestFile("", path: "a_test.dart");
  Expect.isTrue(testFile.shardHash is int);

  // VM test files are hard-coded to return hash zero because they don't have a
  // path to base the hash on.
  Expect.equals(0, TestFile.vmUnitTest().shardHash);
}

void expectParseErrorExpectations(String source, List<StaticError> errors) {
  var file = parseTestFile(source);
  Expect.listEquals(errors.map((error) => error.toString()).toList(),
      file.expectedErrors.map((error) => error.toString()).toList());
}

void expectFormatError(String source) {
  Expect.throwsFormatException(() => parseTestFile(source));
}

void expectParseThrows(String source) {
  Expect.throws(() => parseTestFile(source));
}
