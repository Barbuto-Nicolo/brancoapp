/// Fixture ANONIMIZZATE: stessa struttura e stessi "difetti" del foglio reale
/// (righe corte, "/", segnaposto "____", numeri al posto di testo, seriali per
/// le date, intestazioni con spazi finali), ma nomi e recapiti inventati.
library;

import 'package:lupetti_app/data/parsers/cell_utils.dart';

int s(int y, int m, int d) => dateToSerial(DateTime.utc(y, m, d));

final fxDati = <List<Object?>>[
  [], // riga vuota sopra l'intestazione: l'intestazione NON è la riga 1
  ['Lupetto/a', 'Anno', 'Cod. Cens.', 'Nato/a a', 'il', 'C.F.', 'Residenza', 'Madre',
    'Recapito ', '@ Mail', 'Padre', 'Recapito', '@ Mail '],
  ['Mario Rossi', '4° anno', 1000001, 'Ferrara', s(2015, 5, 19), 'XXXXXX00X00X000X',
    'Via Prova 1, Ferrara', 'Anna Rossi', 3000000001, 'anna@example.test', 'Luca Rossi',
    3000000002, 'luca@example.test'],
  // Mail madre "/", telefono padre vuoto in mezzo alla riga.
  ['Giulia Bianchi', '3° anno', 1000002, '', s(2016, 6, 16), '', 'Via Prova 2', 'Paola Bianchi',
    3000000003, '/', 'Stefano Bianchi', '', 'stefano@example.test'],
  // Segnaposto: riga CORTA (Sheets taglia le celle vuote in coda).
  ['Diego ____'],
  ['Elena Verdi', '2° anno', '', '', s(2017, 5, 10), '', 'Via Prova 3', 'Chiara Verdi', 3000000004,
    'chiara@example.test'],
  [], // riga vuota in mezzo
];

final fxCensimenti = <List<Object?>>[
  ['Lupetto/a', 'Anno', 'dati cens.', 'sanitaria', 'Censimento', 'Data', 'Quota SanFra', 'in data',
    'Quota VdB', 'in data  ', 'Note'],
  ['Mario Rossi', '4° anno', 'non richiesto', false, 'non pagato', '', '/', '', '/'],
  ['Giulia Bianchi', '3° anno', 'non richiesto', true, 'pagato', s(2026, 10, 5), 'non pagato', '',
    'pagato', s(2026, 10, 20), 'Paga a rate'],
  ['Diego ____', '', '', false],
  ['Elena Verdi', '2° anno', 'non richiesto', false, 'non pagato', '', '/', '', '/'],
];

final fxPrede = <List<Object?>>[
  ['Lupetto/a', 'Caccia per', 'Prede', 'Con chi', 'Stato', 'Specialità già acquisite',
    'Specialità 1', 'Impegno', 'Con chi  ', 'Stato  ', 'Specialità 2', 'Impegno ', 'Con chi ',
    'Stato ', 'Specialità 3', 'Impegno  ', 'Con chi   ', 'Stato   ', 'Colonna 1'],
  ['Mario Rossi', 'Lupo Anziano*', '', '/', 'Non assegnata', 'Musicista, Atleta, Cuoco '],
  ['Giulia Bianchi', 'Lupo Anziano', 'Preda X', 'Akela', 'Assegnata', '', 'Fotografo',
    'Scattare 5 foto', 'Bagheera', 'In corso'],
  ['Diego ____'],
  ['Elena Verdi', 'Lupo della Rupe', '', '/', 'Non assegnata', 'Atleta'],
  // Lupetto presente SOLO in questo tab e in Sestiglie.
  ['Linda Neri', 'Lupo della Rupe', '', '/', 'Non assegnata', 'Disegnatore'],
];

final fxSestiglie = <List<Object?>>[
  ['Lupetto/a', 2024, 2025, 2026, 2027],
  ['Mario Rossi', 'Neri', 'Fulvi', 'Fulvi', 'Pezzati'],
  ['Giulia Bianchi', '/', 'Pezzati', 'Pezzati', 'Bianchi'],
  ['Diego Ciccolini', '', '', '', 'Grigi'], // nome completo: NON coincide con "Diego ____"
  ['Elena Verdi', '/', '/', 'Grigi', 'Fulvi'],
  ['Linda Neri', '/', '/', 'Neri', 'Neri'],
];

/// Bilancio come nella copia: importi numerici, totale in fondo senza descrizione.
final fxBilancio = <List<Object?>>[
  ['Dettagli spese', 'Categoria', 'Costo', 'Data della transazione', 'Pagato da', 'Note'],
  ['Conto iniziale', 'Sede', 235, '', '', 'Contanti'],
  ['Colori', 'Materiale', -18, '', 'Akela'],
  ['Quaderni ', 'Attività', -25, s(2026, 11, 3), 'Bagheera'],
  ['Quaderni', 'Attività', -7.5, s(2026, 11, 3), 'Raksha'],
  ['Quote Caccia', '/', 73, '', 'Bagheera'],
  [],
  [],
  ['', '', 257.5], // totale (formula): va ignorato
];

/// Come nel foglio reale: importi formattati come valuta (se arrivassero come testo).
final fxBilancioValuta = <List<Object?>>[
  ['Dettagli spese', 'Categoria', 'Costo', 'Data della transazione', 'Pagato da', 'Note'],
  ['Tazze', 'Attività', '-€ 50,00', '10/10/2026', 'Ikki'],
  ['Offerta', '/', '€ 1.234,50', '', 'Akela'],
  ['', '', '€ 1.184,50'],
];
