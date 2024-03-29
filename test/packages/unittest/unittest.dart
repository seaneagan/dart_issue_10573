// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for writing dart unit tests.
 *
 * ## Installing ##
 *
 * Use [pub][] to install this package. Add the following to your `pubspec.yaml`
 * file.
 *
 *     dependencies:
 *       unittest: any
 *
 * Then run `pub install`.
 *
 * For more information, see the
 * [unittest package on pub.dartlang.org][pkg].
 *
 * See the [Getting Started](http://pub.dartlang.org/doc)
 * guide for more details.
 *
 * ##Concepts##
 *
 *  * __Tests__: Tests are specified via the top-level function [test], they can be
 *    organized together using [group].
 *  * __Checks__: Test expectations can be specified via [expect]
 *  * __Matchers__: [expect] assertions are written declaratively using the
 *    [Matcher] class.
 *  * __Configuration__: The framework can be adapted by calling [configure] with a
 *    [Configuration]. See the other libraries in the `unittest` package for
 *    alternative implementations of [Configuration] including
 *    `compact_vm_config.dart`, `html_config.dart` and
 *    `html_enhanced_config.dart`.
 *
 * ##Examples##
 *
 * A trivial test:
 *
 *     import 'package:unittest/unittest.dart';
 *     main() {
 *       test('this is a test', () {
 *         int x = 2 + 3;
 *         expect(x, equals(5));
 *       });
 *     }
 *
 * Multiple tests:
 *
 *     import 'package:unittest/unittest.dart';
 *     main() {
 *       test('this is a test', () {
 *         int x = 2 + 3;
 *         expect(x, equals(5));
 *       });
 *       test('this is another test', () {
 *         int x = 2 + 3;
 *         expect(x, equals(5));
 *       });
 *     }
 *
 * Multiple tests, grouped by category:
 *
 *     import 'package:unittest/unittest.dart';
 *     main() {
 *       group('group A', () {
 *         test('test A.1', () {
 *           int x = 2 + 3;
 *           expect(x, equals(5));
 *         });
 *         test('test A.2', () {
 *           int x = 2 + 3;
 *           expect(x, equals(5));
 *         });
 *       });
 *       group('group B', () {
 *         test('this B.1', () {
 *           int x = 2 + 3;
 *           expect(x, equals(5));
 *         });
 *       });
 *     }
 *
 * Asynchronous tests: if callbacks expect between 0 and 2 positional arguments,
 * depending on the suffix of expectAsyncX(). expectAsyncX() will wrap a
 * function into a new callback and will not consider the test complete until
 * that callback is run. A count argument can be provided to specify the number
 * of times the callback should be called (the default is 1).
 *
 *     import 'package:unittest/unittest.dart';
 *     import 'dart:isolate';
 *     main() {
 *       test('callback is executed once', () {
 *         // wrap the callback of an asynchronous call with [expectAsync0] if
 *         // the callback takes 0 arguments...
 *         var timer = Timer.run(expectAsync0(() {
 *           int x = 2 + 3;
 *           expect(x, equals(5));
 *         }));
 *       });
 *
 *       test('callback is executed twice', () {
 *         var callback = expectAsync0(() {
 *           int x = 2 + 3;
 *           expect(x, equals(5));
 *         }, count: 2); // <-- we can indicate multiplicity to [expectAsync0]
 *         Timer.run(callback);
 *         Timer.run(callback);
 *       });
 *     }
 *
 * expectAsyncX() will wrap the callback code in a try/catch handler to handle
 * exceptions (treated as test failures). There may be times when the number of
 * times a callback should be called is non-deterministic. In this case a dummy
 * callback can be created with expectAsync0((){}) and this can be called from
 * the real callback when it is finally complete. In this case the body of the
 * callback should be protected within a call to guardAsync(); this will ensure
 * that exceptions are properly handled.
 *
 * A variation on this is expectAsyncUntilX(), which takes a callback as the
 * first parameter and a predicate function as the second parameter; after each
 * time * the callback is called, the predicate function will be called; if it
 * returns false the test will still be considered incomplete.
 *
 * Test functions can return [Future]s, which provide another way of doing
 * asynchronous tests. The test framework will handle exceptions thrown by
 * the Future, and will advance to the next test when the Future is complete.
 * It is still important to use expectAsync/guardAsync with any parts of the
 * test that may be invoked from a top level context (for example, with
 * Timer.run()], as the Future exception handler may not capture exceptions
 * in such code.
 *
 * Note: due to some language limitations we have to use different functions
 * depending on the number of positional arguments of the callback. In the
 * future, we plan to expose a single `expectAsync` function that can be used
 * regardless of the number of positional arguments. This requires new langauge
 * features or fixes to the current spec (e.g. see
 * [Issue 2706](http://dartbug.com/2706)).
 *
 * Meanwhile, we plan to add this alternative API for callbacks of more than 2
 * arguments or that take named parameters. (this is not implemented yet,
 * but will be coming here soon).
 *
 *     import 'package:unittest/unittest.dart';
 *     import 'dart:isolate';
 *     main() {
 *       test('callback is executed', () {
 *         // indicate ahead of time that an async callback is expected.
 *         var async = startAsync();
 *         Timer.run(() {
 *           // Guard the body of the callback, so errors are propagated
 *           // correctly.
 *           guardAsync(() {
 *             int x = 2 + 3;
 *             expect(x, equals(5));
 *           });
 *           // indicate that the asynchronous callback was invoked.
 *           async.complete();
 *         });
 *       });
 *     }
 *
 * [pub]: http://pub.dartlang.org
 * [pkg]: http://pub.dartlang.org/packages/unittest
 */
library unittest;

import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' show max;
import 'matcher.dart';
export 'matcher.dart';

// TODO(amouravski): We should not need to import mock here, but it's necessary
// to enable dartdoc on the mock library, as it's not picked up normally.
import 'mock.dart';

part 'src/config.dart';
part 'src/test_case.dart';

Configuration _config;

/**
 * [Configuration] used by the unittest library. Note that if a 
 * configuration has not been set, calling this getter will create
 * a default configuration.
 */
Configuration get unittestConfiguration {
  if (_config == null) {
    _config = new Configuration();
  }
  return _config;
}

/**
 * Sets the [Configuration] used by the unittest library.
 *
 * Throws a [StateError] if there is an existing, incompatible value.
 */
void set unittestConfiguration(Configuration value) {
  if(!identical(_config, value)) {
    if(_config != null) {
      throw new StateError('unittestConfiguration has already been set');
    }
    _config = value;
  }
}

/**
 * Can be called by tests to log status. Tests should use this
 * instead of [print].
 */
void logMessage(String message) =>
    _config.onLogMessage(currentTestCase, message);

/** Separator used between group names and test names. */
String groupSep = ' ';

final List<TestCase> _testCases = new List<TestCase>();

/** Tests executed in this suite. */
final List<TestCase> testCases = new UnmodifiableListView<TestCase>(_testCases);

/**
 * The set of tests to run can be restricted by using [solo_test] and
 * [solo_group].
 * As groups can be nested we use a counter to keep track of the nest level
 * of soloing, and a flag to tell if we have seen any solo tests.
 */
int _soloNestingLevel = 0;
bool _soloTestSeen = false;

/**
 * Setup and teardown functions for a group and its parents, the latter
 * for chaining.
 */
class _GroupContext {
  final _GroupContext parent;

  /** Description text of the current test group. */
  final String _name;

  /** Setup function called before each test in a group. */
  Function _testSetup;

  get testSetup => _testSetup;

  get parentSetup => (parent == null) ? null : parent.testSetup;

  set testSetup(Function setup) {
    var preSetup = parentSetup;
    if (preSetup == null) {
      _testSetup = setup;
    } else {
      _testSetup = () {
        var f = preSetup();
        if (f is Future) {
          return f.then((_) => setup());
        } else {
          return setup();
        }
      };
    }
  }

  /** Teardown function called after each test in a group. */
  Function _testTeardown;

  get testTeardown => _testTeardown;

  get parentTeardown => (parent == null) ? null : parent.testTeardown;

  set testTeardown(Function teardown) {
    var postTeardown = parentTeardown;
    if (postTeardown == null) {
      _testTeardown = teardown;
    } else {
      _testTeardown = () {
        var f = teardown();
        if (f is Future) {
          return f.then((_) => postTeardown());
        } else {
          return postTeardown();
        }
      };
    }
  }

  String get fullName => (parent == null || parent == _rootContext)
      ? _name
      : "${parent.fullName}$groupSep$_name";

  _GroupContext([this.parent, this._name = '']) {
    _testSetup = parentSetup;
    _testTeardown = parentTeardown;
  }
}

// We use a 'dummy' context for the top level to eliminate null
// checks when querying the context. This allows us to easily
//  support top-level setUp/tearDown functions as well.
final _rootContext = new _GroupContext();
_GroupContext _currentContext = _rootContext;

int _currentTestCaseIndex = 0;

/** [TestCase] currently being executed. */
TestCase get currentTestCase =>
    (_currentTestCaseIndex >= 0 && _currentTestCaseIndex < testCases.length)
        ? testCases[_currentTestCaseIndex]
        : null;

/** Whether the framework is in an initialized state. */
bool _initialized = false;

String _uncaughtErrorMessage = null;

/** Test case result strings. */
// TODO(gram) we should change these constants to use a different string
// (so that writing 'FAIL' in the middle of a test doesn't
// imply that the test fails). We can't do it without also changing
// the testrunner and test.dart though.
const PASS  = 'pass';
const FAIL  = 'fail';
const ERROR = 'error';

/**
 * A map that can be used to communicate state between a test driver
 * or main() function and the tests, particularly when these two
 * are otherwise independent. For example, a test driver that starts
 * an HTTP server and then runs tests that access that server could use
 * this as a way of communicating the server port to the tests.
 */
Map testState = {};

/**
 * Creates a new test case with the given description and body. The
 * description will include the descriptions of any surrounding group()
 * calls.
 */
void test(String spec, TestFunction body) {
  ensureInitialized();
  if (!_soloTestSeen || _soloNestingLevel > 0) {
    var testcase = new TestCase._internal(testCases.length + 1, _fullSpec(spec),
                                        body);
    _testCases.add(testcase);
  }
}

/** Convenience function for skipping a test. */
void skip_test(String spec, TestFunction body){}

/**
 * Creates a new test case with the given description and body. The
 * description will include the descriptions of any surrounding group()
 * calls.
 *
 * If we use [solo_test] (or [solo_group]) instead of test, then all non-solo
 * tests will be disabled. Note that if we use [solo_group], all tests in
 * the group will be enabled, regardless of whether they use [test] or
 * [solo_test], or whether they are in a nested [group] vs [solo_group]. Put
 * another way, if there are any calls to [solo_test] or [solo_group] in a test
 * file, all tests that are not inside a [solo_group] will be disabled unless
 * they are [solo_test]s.
 *
 * [skip_test] and [skip_group] take precedence over soloing, by virtue of the
 * fact that they are effectively no-ops.
 */
void solo_test(String spec, TestFunction body) {
  ensureInitialized();
  if (!_soloTestSeen) {
    _soloTestSeen = true;
    // This is the first solo-ed test. Discard all tests up to now.
    _testCases.clear();
  }
  ++_soloNestingLevel;
  try {
    test(spec, body);
  } finally {
    --_soloNestingLevel;
  }
}

/** Sentinel value for [_SpreadArgsHelper]. */
class _Sentinel {
  const _Sentinel();
}

/** Simulates spread arguments using named arguments. */
// TODO(sigmund): remove this class and simply use a closure with named
// arguments (if still applicable).
class _SpreadArgsHelper {
  final Function callback;
  final int minExpectedCalls;
  final int maxExpectedCalls;
  final Function isDone;
  final String id;
  int actualCalls = 0;
  final TestCase testCase;
  bool complete;
  static const sentinel = const _Sentinel();

  _SpreadArgsHelper(Function callback, int minExpected, int maxExpected,
      Function isDone, String id)
      : this.callback = callback,
        minExpectedCalls = minExpected,
        maxExpectedCalls = (maxExpected == 0 && minExpected > 0)
            ? minExpected
            : maxExpected,
        this.isDone = isDone,
        this.testCase = currentTestCase,
        this.id = _makeCallbackId(id, callback) {
    ensureInitialized();
    if (testCase == null) {
      throw new StateError("No valid test. Did you forget to run your test "
          "inside a call to test()?");
    }

    if (isDone != null || minExpected > 0) {
      testCase._callbackFunctionsOutstanding++;
      complete = false;
    } else {
      complete = true;
    }
  }

  static String _makeCallbackId(String id, Function callback) {
    // Try to create a reasonable id.
    if (id != null) {
      return "$id ";
    } else {
      // If the callback is not an anonymous closure, try to get the
      // name.
      var fname = callback.toString();
      var prefix = "Function '";
      var pos = fname.indexOf(prefix);
      if (pos > 0) {
        pos += prefix.length;
        var epos = fname.indexOf("'", pos);
        if (epos > 0) {
          return "${fname.substring(pos, epos)} ";
        }
      }
    }
    return '';
  }

  bool shouldCallBack() {
    ++actualCalls;
    if (testCase.isComplete) {
      // Don't run if the test is done. We don't throw here as this is not
      // the current test, but we do mark the old test as having an error
      // if it previously passed.
      if (testCase.result == PASS) {
        testCase.error(
            'Callback ${id}called ($actualCalls) after test case '
            '${testCase.description} has already been marked as '
            '${testCase.result}.', '');
      }
      return false;
    } else if (maxExpectedCalls >= 0 && actualCalls > maxExpectedCalls) {
      throw new TestFailure('Callback ${id}called more times than expected '
                            '($maxExpectedCalls).');
    }
    return true;
  }

  void after() {
    if (!complete) {
      if (minExpectedCalls > 0 && actualCalls < minExpectedCalls) return;
      if (isDone != null && !isDone()) return;

      // Mark this callback as complete and remove it from the testcase
      // oustanding callback count; if that hits zero the testcase is done.
      complete = true;
      testCase._markCallbackComplete();
    }
  }

  invoke0() {
    return _guardAsync(
        () {
          if (shouldCallBack()) {
            return callback();
          }
        },
        after, testCase);
  }

  invoke1(arg1) {
    return _guardAsync(
        () {
          if (shouldCallBack()) {
            return callback(arg1);
          }
        },
        after, testCase);
  }

  invoke2(arg1, arg2) {
    return _guardAsync(
        () {
          if (shouldCallBack()) {
            return callback(arg1, arg2);
          }
        },
        after, testCase);
  }
}

/**
 * Indicate that [callback] is expected to be called a [count] number of times
 * (by default 1). The unittest framework will wait for the callback to run the
 * specified [count] times before it continues with the following test.  Using
 * [expectAsync0] will also ensure that errors that occur within [callback] are
 * tracked and reported. [callback] should take 0 positional arguments (named
 * arguments are not supported). [id] can be used to provide more
 * descriptive error messages if the callback is called more often than
 * expected. [max] can be used to specify an upper bound on the number of
 * calls; if this is exceeded the test will fail (or be marked as in error if
 * it was already complete). A value of 0 for [max] (the default) will set
 * the upper bound to the same value as [count]; i.e. the callback should be
 * called exactly [count] times. A value of -1 for [max] will mean no upper
 * bound.
 */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function expectAsync0(Function callback,
                     {int count: 1, int max: 0, String id}) {
  return new _SpreadArgsHelper(callback, count, max, null, id).invoke0;
}

/** Like [expectAsync0] but [callback] should take 1 positional argument. */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function expectAsync1(Function callback,
                     {int count: 1, int max: 0, String id}) {
  return new _SpreadArgsHelper(callback, count, max, null, id).invoke1;
}

/** Like [expectAsync0] but [callback] should take 2 positional arguments. */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function expectAsync2(Function callback,
                     {int count: 1, int max: 0, String id}) {
  return new _SpreadArgsHelper(callback, count, max, null, id).invoke2;
}

/**
 * Indicate that [callback] is expected to be called until [isDone] returns
 * true. The unittest framework check [isDone] after each callback and only
 * when it returns true will it continue with the following test. Using
 * [expectAsyncUntil0] will also ensure that errors that occur within
 * [callback] are tracked and reported. [callback] should take 0 positional
 * arguments (named arguments are not supported). [id] can be used to
 * identify the callback in error messages (for example if it is called
 * after the test case is complete).
 */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function expectAsyncUntil0(Function callback, Function isDone, {String id}) {
  return new _SpreadArgsHelper(callback, 0, -1, isDone, id).invoke0;
}

/**
 * Like [expectAsyncUntil0] but [callback] should take 1 positional argument.
 */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function expectAsyncUntil1(Function callback, Function isDone, {String id}) {
  return new _SpreadArgsHelper(callback, 0, -1, isDone, id).invoke1;
}

/**
 * Like [expectAsyncUntil0] but [callback] should take 2 positional arguments.
 */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function expectAsyncUntil2(Function callback, Function isDone, {String id}) {
  return new _SpreadArgsHelper(callback, 0, -1, isDone, id).invoke2;
}

/**
 * Wraps the [callback] in a new function and returns that function. The new
 * function will be able to handle exceptions by directing them to the correct
 * test. This is thus similar to expectAsync0. Use it to wrap any callbacks that
 * might optionally be called but may never be called during the test.
 * [callback] should take 0 positional arguments (named arguments are not
 * supported). [id] can be used to identify the callback in error
 * messages (for example if it is called after the test case is complete).
 */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function protectAsync0(Function callback, {String id}) {
  return new _SpreadArgsHelper(callback, 0, -1, null, id).invoke0;
}

/**
 * Like [protectAsync0] but [callback] should take 1 positional argument.
 */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function protectAsync1(Function callback, {String id}) {
  return new _SpreadArgsHelper(callback, 0, -1, null, id).invoke1;
}

/**
 * Like [protectAsync0] but [callback] should take 2 positional arguments.
 */
// TODO(sigmund): deprecate this API when issue 2706 is fixed.
Function protectAsync2(Function callback, {String id}) {
  return new _SpreadArgsHelper(callback, 0, -1, null, id).invoke2;
}

/**
 * Creates a new named group of tests. Calls to group() or test() within the
 * body of the function passed to this will inherit this group's description.
 */
void group(String description, void body()) {
  ensureInitialized();
  _currentContext = new _GroupContext(_currentContext, description);
  try {
    body();
  } catch (e, trace) {
    var stack = (trace == null) ? '' : ': ${trace.toString()}';
    _uncaughtErrorMessage = "${e.toString()}$stack";
  } finally {
    // Now that the group is over, restore the previous one.
    _currentContext = _currentContext.parent;
  }
}

/** Like [skip_test], but for groups. */
void skip_group(String description, void body()) {}

/** Like [solo_test], but for groups. */
void solo_group(String description, void body()) {
  ensureInitialized();
  if (!_soloTestSeen) {
    _soloTestSeen = true;
    // This is the first solo-ed group. Discard all tests up to now.
    _testCases.clear();
  }
  ++_soloNestingLevel;
  try {
    group(description, body);
  } finally {
    --_soloNestingLevel;
  }
}

/**
 * Register a [setUp] function for a test [group]. This function will
 * be called before each test in the group is run.
 * [setUp] and [tearDown] should be called within the [group] before any
 * calls to [test]. The [setupTest] function can be asynchronous; in this
 * case it must return a [Future].
 */
void setUp(Function setupTest) {
  _currentContext.testSetup = setupTest;
}

/**
 * Register a [tearDown] function for a test [group]. This function will
 * be called after each test in the group is run. Note that if groups
 * are nested only the most locally scoped [teardownTest] function will be run.
 * [setUp] and [tearDown] should be called within the [group] before any
 * calls to [test]. The [teardownTest] function can be asynchronous; in this
 * case it must return a [Future].
 */
void tearDown(Function teardownTest) {
  _currentContext.testTeardown = teardownTest;
}

/** Advance to the next test case. */
void _nextTestCase() {
  runAsync(() {
    _currentTestCaseIndex++;
    _nextBatch();
  });
}

/**
 * Utility function that can be used to notify the test framework that an
 *  error was caught outside of this library.
 */
void _reportTestError(String msg, String trace) {
 if (_currentTestCaseIndex < testCases.length) {
    final testCase = testCases[_currentTestCaseIndex];
    testCase.error(msg, trace);
  } else {
    _uncaughtErrorMessage = "$msg: $trace";
  }
}

void rerunTests() {
  _uncaughtErrorMessage = null;
  _initialized = true; // We don't want to reset the test array.
  runTests();
}

/**
 * Filter the tests. [testFilter] can be a [RegExp], a [String] or a
 * predicate function. This is different to enabling/disabling tests
 * in that it removes the tests completely.
 */
void filterTests(testFilter) {
  var filterFunction;
  if (testFilter is String) {
    RegExp re = new RegExp(testFilter);
    filterFunction = (t) => re.hasMatch(t.description);
  } else if (testFilter is RegExp) {
    filterFunction = (t) => testFilter.hasMatch(t.description);
  } else if (testFilter is Function) {
    filterFunction = testFilter;
  }
  _testCases.retainWhere(filterFunction);
}

/** Runs all queued tests, one at a time. */
void runTests() {
  _ensureInitialized(false);
  _currentTestCaseIndex = 0;

  _config.onStart();

  runAsync(() {
    _nextBatch();
  });
}

/**
 * Run [tryBody] guarded in a try-catch block. If an exception is thrown, it is
 * passed to the corresponding test.
 *
 * The value returned by [tryBody] (if any) is returned by [guardAsync].
 */
guardAsync(Function tryBody) {
  return _guardAsync(tryBody, null, currentTestCase);
}

_guardAsync(Function tryBody, Function finallyBody, TestCase testCase) {
  assert(testCase != null);
  try {
    return tryBody();
  } catch (e, trace) {
    _registerException(testCase, e, trace);
  } finally {
    if (finallyBody != null) finallyBody();
  }
}

/**
 * Registers that an exception was caught for the current test.
 */
void registerException(e, [trace]) {
  _registerException(currentTestCase, e, trace);
}

/**
 * Registers that an exception was caught for the current test.
 */
void _registerException(TestCase testCase, e, [trace]) {
  trace = trace == null ? '' : trace.toString();
  String message = (e is TestFailure) ? e.message : 'Caught $e';
  if (testCase.result == null) {
    testCase.fail(message, trace);
  } else {
    testCase.error(message, trace);
  }
}

/**
 * Runs a batch of tests, yielding whenever an asynchronous test starts
 * running. Tests will resume executing when such asynchronous test calls
 * [done] or if it fails with an exception.
 */
void _nextBatch() {
  while (true) {
    if (_currentTestCaseIndex >= testCases.length) {
      _completeTests();
      break;
    }
    final testCase = testCases[_currentTestCaseIndex];
    var f = _guardAsync(testCase._run, null, testCase);
    if (f != null) {
      f.whenComplete(() {
        _nextTestCase(); // Schedule the next test.
      });
      break;
    }
    _currentTestCaseIndex++;
  }
}

/** Publish results on the page and notify controller. */
void _completeTests() {
  if (!_initialized) return;
  int passed = 0;
  int failed = 0;
  int errors = 0;

  for (TestCase t in testCases) {
    switch (t.result) {
      case PASS:  passed++; break;
      case FAIL:  failed++; break;
      case ERROR: errors++; break;
    }
  }
  _config.onSummary(passed, failed, errors, testCases, _uncaughtErrorMessage);
  _config.onDone(passed > 0 && failed == 0 && errors == 0 &&
      _uncaughtErrorMessage == null);
  _initialized = false;
}

String _fullSpec(String spec) {
  var group = '${_currentContext.fullName}';
  if (spec == null) return group;
  return group != '' ? '$group$groupSep$spec' : spec;
}

/**
 * Lazily initializes the test library if not already initialized.
 */
void ensureInitialized() {
  _ensureInitialized(true);
}

void _ensureInitialized(bool configAutoStart) {
  if (_initialized) {
    return;
  }
  _initialized = true;
  // Hook our async guard into the matcher library.
  wrapAsync = (f, [id]) => expectAsync1(f, id: id);

  _uncaughtErrorMessage = null;

  unittestConfiguration.onInit();

  if (configAutoStart && _config.autoStart) {
    // Immediately queue the suite up. It will run after a timeout (i.e. after
    // main() has returned).
    runAsync(runTests);
  }
}

/** Select a solo test by ID. */
void setSoloTest(int id) =>
  _testCases.retainWhere((t) => t.id == id);

/** Enable/disable a test by ID. */
void _setTestEnabledState(int testId, bool state) {
  // Try fast path first.
  if (testCases.length > testId && testCases[testId].id == testId) {
    testCases[testId].enabled = state;
  } else {
    for (var i = 0; i < testCases.length; i++) {
      if (testCases[i].id == testId) {
        testCases[i].enabled = state;
        break;
      }
    }
  }
}

/** Enable a test by ID. */
void enableTest(int testId) => _setTestEnabledState(testId, true);

/** Disable a test by ID. */
void disableTest(int testId) => _setTestEnabledState(testId, false);

/** Signature for a test function. */
typedef dynamic TestFunction();

// Stack formatting utility. Strips extraneous content from a stack trace.
// Stack frame lines are parsed with a regexp, which has been tested
// in Chrome, Firefox and the VM. If a line fails to be parsed it is 
// included in the output to be conservative.
//
// The output stack consists of everything after the call to TestCase._run.
// If we see an 'expect' in the frame we will prune everything above that
// as well.
final _frameRegExp = new RegExp(
    r'^\s*' // Skip leading spaces.
    r'(?:'  // Group of choices for the prefix.
      r'(?:#\d+\s*)|' // Skip VM's #<frameNumber>.
      r'(?:at )|'     // Skip Firefox's 'at '.
      r'(?:))'        // Other environments have nothing here.
    r'(.+)'           // Extract the function/method.
    r'\s*[@\(]'       // Skip space and @ or (.
    r'('              // This group of choices is for the source file.
      r'(?:.+:\/\/.+\/[^:]*)|' // Handle file:// or http:// URLs.
      r'(?:dart:[^:]*)|'  // Handle dart:<lib>.
      r'(?:package:[^:]*)' // Handle package:<path>
    r'):([:\d]+)[\)]?$'); // Get the line number and optional column number.

String _formatStack(stack) {
  var lines;
  if (stack is StackTrace) {
    lines = stack.toString().split('\n');
  } else if (stack is String) {
    lines = stack.split('\n');
  } else {
    return stack.toString();
  }
 
  // Calculate the max width of first column so we can 
  // pad to align the second columns.
  int padding = lines.fold(0, (n, line) {
    var match = _frameRegExp.firstMatch(line);
    if (match == null) return n;
    return max(n, match[1].length + 1);
  });

  // We remove all entries that have a location in unittest.
  // We strip out anything before _nextBatch too.
  var sb = new StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line == '') continue;
    var match = _frameRegExp.firstMatch(line);
    if (match == null) {
      sb.write(line);
      sb.write('\n');
    } else {
      var member = match[1];
      var location = match[2];
      var position = match[3];
      if (member.indexOf('TestCase._runTest') >= 0) {
        // Don't include anything after this.
        break;
      } else if (member.indexOf('expect') >= 0) {
        // It looks like this was an expect() failure;
        // drop all the frames up to here.
        sb.clear();
      } else {
        sb.write(member);
        // Pad second column to a fixed position.
        for (var j = 0; j <= padding - member.length; j++) {
          sb.write(' ');
        }
        sb.write(location);
        sb.write(' ');
        sb.write(position);
        sb.write('\n');
      }
    }
  }
  return sb.toString();
}
