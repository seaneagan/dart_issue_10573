
import 'package:unittest/unittest.dart';
import 'package:http/http.dart' as http;

var uri = 'http://i18ndata.appspot.com/cldr/tags/unconfirmed/main/ru/listPatterns/listPattern/end?depth=-1';
main() => http.read(uri).then((body) => test("issue 10573", () => expect(body, '"{0} и {1}"')));
