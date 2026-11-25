import 'package:intl/intl.dart';

final _eur = NumberFormat.currency(locale: 'it_IT', symbol: '€');
final _data = DateFormat('dd/MM/yyyy');
final _dataOra = DateFormat('dd/MM HH:mm');
final _ora = DateFormat('HH:mm');

String euro(double v) => _eur.format(v);
String dataIt(DateTime? d) => d == null ? '' : _data.format(d);
String dataOraIt(DateTime d) => _dataOra.format(d);
String oraIt(DateTime d) => _ora.format(d);
