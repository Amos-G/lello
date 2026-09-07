import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partysync/api.dart';
import 'package:partysync/app_theme.dart';
import 'package:partysync/content_pages.dart';
import 'package:partysync/expenses_page.dart';
import 'package:partysync/main.dart';
import 'package:partysync/models.dart';
import 'package:partysync/security.dart';
import 'package:partysync/settings_page.dart';

void main() {
  test('il tema mantiene la palette originale senza container azzurri', () {
    final theme = buildAppTheme();
    expect(theme.colorScheme.primary, sunset);
    expect(theme.colorScheme.primaryContainer, sunsetSoft);
    expect(theme.colorScheme.secondaryContainer, sageSoft);
    expect(theme.floatingActionButtonTheme.backgroundColor, sunset);
  });

  test('normalizza sempre gli ID PostgreSQL come String', () {
    final item = Elemento.fromJson({
      'id': 42,
      'nome': 'Ghiaccio',
      'chi_porta_utente_id': 7,
      'chi_porta_username': 'Anna',
      'completato': false,
    });
    expect(item.id, '42');
    expect(item.assigneeUserId, '7');
  });

  test('mantiene la lista selezionata solo se ancora disponibile', () {
    const lists = [
      PartyList(
        id: '10',
        nome: 'A',
        creatorId: '1',
        creatorUsername: 'amos',
        participantCount: 2,
      ),
      PartyList(
        id: '20',
        nome: 'B',
        creatorId: '1',
        creatorUsername: 'amos',
        participantCount: 3,
      ),
    ];
    expect(resolveSelectedListId(lists, '20'), '20');
    expect(resolveSelectedListId(lists, '99'), '10');
    expect(resolveSelectedListId(const [], '20'), isNull);
  });

  test('selezione partecipanti non muta il set di partenza', () {
    final original = {'1', '2'};
    final changed = toggleParticipantSelection(original, '2', false);
    expect(original, {'1', '2'});
    expect(changed, {'1'});
  });

  test('visibilità amministrativa richiede amos superadmin', () {
    const amos = AppUser(
      id: '1',
      username: 'amos',
      ruolo: 'superadmin',
      totpEnabled: false,
    );
    const other = AppUser(
      id: '2',
      username: 'mario',
      ruolo: 'superadmin',
      totpEnabled: false,
    );
    expect(amos.isAmosAdmin, isTrue);
    expect(other.isAmosAdmin, isFalse);
    expect(
      const AppUser(
        id: '3',
        username: 'amos',
        ruolo: 'guida',
        totpEnabled: false,
      ).isAmosAdmin,
      isFalse,
    );
  });

  testWidgets('la sezione admin espone creazione utenti ed eliminazione utenti', (tester) async {
    AdminUser? deletedUser;
    const testAdminUsers = [
      AdminUser(
        id: 'u-1',
        username: 'amos',
        ruolo: 'superadmin',
        totpEnabled: true,
      ),
      AdminUser(
        id: 'u-2',
        username: 'giovanni',
        ruolo: 'guida',
        totpEnabled: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSection(
            users: testAdminUsers,
            busy: false,
            onCreate: () {},
            onEdit: (_) {},
            onDelete: (user) => deletedUser = user,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('admin-section')), findsOneWidget);
    expect(find.byKey(const Key('create-user')), findsOneWidget);

    // amos superadmin non ha il pulsante di eliminazione
    expect(find.byKey(const Key('delete-user-u-1')), findsNothing);
    // giovanni ha il pulsante di eliminazione
    expect(find.byKey(const Key('delete-user-u-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-user-u-2')));
    expect(deletedUser?.username, equals('giovanni'));
  });

  testWidgets('il selettore spesa consente una selezione mirata', (
    tester,
  ) async {
    var selected = {'1', '2'};
    const people = [
      ExpenseParticipant(
        userId: '1',
        username: 'Anna',
        paidCents: 0,
        shareCents: 0,
        balanceCents: 0,
      ),
      ExpenseParticipant(
        userId: '2',
        username: 'Luca',
        paidCents: 0,
        shareCents: 0,
        balanceCents: 0,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ParticipantSelector(
              participants: people,
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Luca'));
    await tester.pump();
    expect(selected, {'1'});
  });

  testWidgets('la sezione inviti abilita la scelta quando ci sono utenti', (
    tester,
  ) async {
    var invited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteTile(
            availableCount: 2,
            busy: false,
            onInvite: () => invited = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('invite-section')), findsOneWidget);
    expect(find.text('2 disponibili'), findsOneWidget);
    await tester.tap(find.text('Invita partecipante'));
    expect(invited, isTrue);
  });

  testWidgets('solo il debitore vede il pagamento parziale', (tester) async {
    const obligation = Obligation(
      fromUserId: '2',
      fromUsername: 'Luca',
      toUserId: '1',
      toUsername: 'Anna',
      amountCents: 1000,
    );
    const report = SpeseReport(
      spese: [],
      payments: [],
      participants: [],
      obligations: [obligation],
      totalCents: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpensesPage(
            api: Api(),
            listId: '10',
            currentUserId: '2',
            report: report,
            reload: () async {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('pay-obligation')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pay-obligation')));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('payment-amount')), '4,50');
    expect(find.text('4,50'), findsOneWidget);
  });

  testWidgets('un utente diverso non vede il pulsante di pagamento', (
    tester,
  ) async {
    const obligation = Obligation(
      fromUserId: '2',
      fromUsername: 'Luca',
      toUserId: '1',
      toUsername: 'Anna',
      amountCents: 1000,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObligationCard(
            obligation: obligation,
            currentUserId: '3',
            onPay: _noop,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('pay-obligation')), findsNothing);
  });

  group('Sicurezza & Validazione', () {
    test(
      'validazione username rifiuta valori non conformi e accetta quelli validi',
      () {
        expect(UsernameValidationResult.validate('').isValid, isFalse);
        expect(UsernameValidationResult.validate('ab').isValid, isFalse);
        expect(UsernameValidationResult.validate('a' * 31).isValid, isFalse);
        expect(
          UsernameValidationResult.validate('utente con spazi').isValid,
          isFalse,
        );
        expect(
          UsernameValidationResult.validate('utente@email').isValid,
          isFalse,
        );
        expect(
          UsernameValidationResult.validate('utente_valido-123.test').isValid,
          isTrue,
        );
      },
    );

    test(
      'validazione password impone complessità minima di 8 caratteri, maiuscola, minuscola, numero e simbolo',
      () {
        // Troppo corta
        expect(PasswordValidationResult.validate('Ab1!').isValid, isFalse);
        // Senza maiuscola
        expect(PasswordValidationResult.validate('ab123456!').isValid, isFalse);
        // Senza minuscola
        expect(PasswordValidationResult.validate('AB123456!').isValid, isFalse);
        // Senza numero
        expect(PasswordValidationResult.validate('Abcdefgh!').isValid, isFalse);
        // Senza simbolo
        expect(PasswordValidationResult.validate('Abcdefgh1').isValid, isFalse);
        // Password comune nota
        expect(
          PasswordValidationResult.validate('password123!').isValid,
          isFalse,
        );
        expect(PasswordValidationResult.validate('lello123!').isValid, isFalse);
        // Contiene lo username
        expect(
          PasswordValidationResult.validate(
            'Marco_12345!',
            username: 'marco',
          ).isValid,
          isFalse,
        );
        // Password valida e robusta
        expect(
          PasswordValidationResult.validate(
            'Str0ngP@ssw0rd!',
            username: 'mario',
          ).isValid,
          isTrue,
        );
      },
    );

    test(
      'permesso di invito subordinato ad approvazione per guide e followers',
      () {
        const admin = AppUser(
          id: '1',
          username: 'amos',
          ruolo: 'superadmin',
          totpEnabled: false,
        );
        const guidaNonApprovata = AppUser(
          id: '2',
          username: 'luca',
          ruolo: 'guida',
          totpEnabled: false,
          canInviteUsers: false,
        );
        const guidaApprovata = AppUser(
          id: '3',
          username: 'giulia',
          ruolo: 'guida',
          totpEnabled: false,
          canInviteUsers: true,
        );
        const follower = AppUser(
          id: '4',
          username: 'marco',
          ruolo: 'follower',
          totpEnabled: false,
          canInviteUsers: true, // Follower non può mai invitare nuovi utenti
        );

        expect(admin.canInviteNewUsers, isTrue);
        expect(guidaNonApprovata.canInviteNewUsers, isFalse);
        expect(guidaApprovata.canInviteNewUsers, isTrue);
        expect(follower.canInviteNewUsers, isFalse);
      },
    );
  });

  testWidgets(
    'LoginPage consente il passaggio alla registrazione con codice invito',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(api: Api(), onLogin: () {}),
        ),
      );

      expect(find.text('Hai un codice di invito? Registrati'), findsOneWidget);
      expect(find.text('Codice invito'), findsNothing);

      await tester.tap(find.text('Hai un codice di invito? Registrati'));
      await tester.pump();

      expect(find.text('Registrazione su invito'), findsOneWidget);
      expect(find.text('Codice invito'), findsOneWidget);
      expect(find.text('Conferma password'), findsOneWidget);
      expect(find.text('Requisiti password:'), findsOneWidget);
      expect(find.text('Completa registrazione'), findsOneWidget);
      expect(find.text('Hai già un account? Accedi'), findsOneWidget);
    },
  );

  group('Gestione Inviti e Liste', () {
    const listPropria = PartyList(
      id: '1',
      nome: 'Festa di Amos',
      creatorId: 'user-1',
      creatorUsername: 'amos',
      participantCount: 2,
    );
    const listInvitata1 = PartyList(
      id: '2',
      nome: 'Festa di Luca',
      creatorId: 'user-2',
      creatorUsername: 'luca',
      participantCount: 3,
    );
    const listInvitata2 = PartyList(
      id: '3',
      nome: 'Festa di Marco',
      creatorId: 'user-3',
      creatorUsername: 'marco',
      participantCount: 5,
    );

    test('filtro inviti accetta e rifiuta distingue correttamente le liste', () {
      final all = [listPropria, listInvitata1, listInvitata2];
      final accepted = {'2'};
      final rejected = {'3'};

      final visible = filterAcceptedLists(all, 'user-1', accepted, rejected);
      expect(visible.map((l) => l.id).toList(), ['1', '2']);

      final pending = findPendingInvites(all, 'user-1', accepted, rejected);
      expect(pending, isEmpty);

      // Nuovo invito non ancora gestito
      const listNuova = PartyList(
        id: '4',
        nome: 'Festa Nuova',
        creatorId: 'user-4',
        creatorUsername: 'anna',
        participantCount: 2,
      );
      final withNew = [...all, listNuova];
      final pendingNew = findPendingInvites(withNew, 'user-1', accepted, rejected);
      expect(pendingNew.length, 1);
      expect(pendingNew.first.id, '4');
    });

    test('regole di eliminazione liste per admin e guide', () {
      const admin = AppUser(
        id: 'admin-1',
        username: 'amos',
        ruolo: 'superadmin',
        totpEnabled: false,
      );
      const guida = AppUser(
        id: 'guida-1',
        username: 'mario',
        ruolo: 'guida',
        totpEnabled: false,
      );
      const listDiMario = PartyList(
        id: '10',
        nome: 'Lista Escursione',
        creatorId: 'guida-1',
        creatorUsername: 'mario',
        participantCount: 4,
      );
      const listDiAltro = PartyList(
        id: '20',
        nome: 'Lista Altra',
        creatorId: 'altro-99',
        creatorUsername: 'giovanni',
        participantCount: 2,
      );

      // Admin può eliminare qualsiasi lista
      expect(admin.canDeleteList(listDiMario), isTrue);
      expect(admin.canDeleteList(listDiAltro), isTrue);

      // Guida può eliminare solo la propria lista
      expect(guida.canDeleteList(listDiMario), isTrue);
      expect(guida.canDeleteList(listDiAltro), isFalse);
    });

    testWidgets('impostazioni mostra Elimina per admin o per guida se creatrice', (tester) async {
      const guida = AppUser(
        id: 'guida-1',
        username: 'mario',
        ruolo: 'guida',
        totpEnabled: false,
      );
      const listPropria = PartyList(
        id: '10',
        nome: 'Lista Escursione',
        creatorId: 'guida-1',
        creatorUsername: 'mario',
        participantCount: 4,
      );
      const listAltra = PartyList(
        id: '20',
        nome: 'Lista Altra',
        creatorId: 'altro-99',
        creatorUsername: 'giovanni',
        participantCount: 2,
      );

      // Guida con lista propria -> vede pulsante Elimina
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              api: Api(),
              user: guida,
              lists: const [listPropria],
              selectedList: listPropria,
              participants: const [],
              selectList: (_) async {},
              refreshLists: () async {},
              reloadSelected: () async {},
              onLogout: () {},
            ),
          ),
        ),
      );
      expect(find.text('Elimina'), findsOneWidget);

      // Guida con lista creata da altri -> NON vede pulsante Elimina
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              api: Api(),
              user: guida,
              lists: const [listAltra],
              selectedList: listAltra,
              participants: const [],
              selectList: (_) async {},
              refreshLists: () async {},
              reloadSelected: () async {},
              onLogout: () {},
            ),
          ),
        ),
      );
      expect(find.text('Elimina'), findsNothing);
    });

    testWidgets('dialog invito mostra opzioni Accetta e Rifiuta', (tester) async {
      const list = PartyList(
        id: '100',
        nome: 'Compleanno Giulia',
        creatorId: 'user-5',
        creatorUsername: 'giulia',
        participantCount: 8,
      );

      bool? accepted;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    accepted = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Nuovo invito a una lista'),
                        content: Text('${list.creatorUsername} ti ha invitato alla lista ${list.nome}'),
                        actions: [
                          TextButton(
                            key: const Key('decline-invite'),
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Rifiuta'),
                          ),
                          FilledButton(
                            key: const Key('accept-invite'),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Accetta'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Mostra Invito'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mostra Invito'));
      await tester.pumpAndSettle();

      expect(find.text('Nuovo invito a una lista'), findsOneWidget);
      expect(find.text('giulia ti ha invitato alla lista Compleanno Giulia'), findsOneWidget);
      expect(find.byKey(const Key('decline-invite')), findsOneWidget);
      expect(find.byKey(const Key('accept-invite')), findsOneWidget);

      await tester.tap(find.byKey(const Key('accept-invite')));
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
    });
  });

  group('Gestione Spese con Esclusione Partecipanti e Saldi', () {
    const p1 = ExpenseParticipant(
      userId: 'user-1',
      username: 'Amos',
      paidCents: 2000,
      shareCents: 1000,
      balanceCents: 1000,
    );
    const p2 = ExpenseParticipant(
      userId: 'user-2',
      username: 'Luca',
      paidCents: 0,
      shareCents: 1000,
      balanceCents: -1000,
    );
    final spesaPropria = Spesa(
      id: 's-1',
      userId: 'user-1',
      username: 'Amos',
      descrizione: 'Pizza',
      importoCents: 2000,
      participantIds: const ['user-1', 'user-2'],
      createdAt: _fixedDate,
    );
    final spesaAltro = Spesa(
      id: 's-2',
      userId: 'user-2',
      username: 'Luca',
      descrizione: 'Bibite',
      importoCents: 1000,
      participantIds: const ['user-1', 'user-2'],
      createdAt: _fixedDate,
    );
    const obligation = Obligation(
      fromUserId: 'user-2',
      fromUsername: 'Luca',
      toUserId: 'user-1',
      toUsername: 'Amos',
      amountCents: 1000,
    );

    testWidgets('mostra pulsanti Aggiungi spesa e Registra saldo', (tester) async {
      final report = SpeseReport(
        spese: [spesaPropria, spesaAltro],
        payments: const [],
        participants: const [p1, p2],
        obligations: const [obligation],
        totalCents: 3000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpensesPage(
              api: Api(),
              listId: '10',
              currentUserId: 'user-1',
              report: report,
              reload: () async {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('add-expense')), findsOneWidget);
      expect(find.byKey(const Key('add-settlement')), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Bibite'), findsOneWidget);

      // Solo la propria spesa (s-1) mostra il pulsante di eliminazione per user-1
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('dialog nuova spesa permette switch per escludere partecipanti', (
      tester,
    ) async {
      final report = SpeseReport(
        spese: const [],
        payments: const [],
        participants: const [p1, p2],
        obligations: const [],
        totalCents: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpensesPage(
              api: Api(),
              listId: '10',
              currentUserId: 'user-1',
              report: report,
              reload: () async {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      expect(find.text('Nuova spesa'), findsOneWidget);
      expect(find.text('Riguarda tutti i partecipanti'), findsOneWidget);

      // Toccando lo switch si espande il selettore dei partecipanti
      await tester.tap(find.text('Riguarda tutti i partecipanti'));
      await tester.pumpAndSettle();

      expect(find.text('Seleziona i partecipanti inclusi:'), findsOneWidget);
      expect(find.byKey(const Key('participant-selector')), findsOneWidget);
    });

    testWidgets('PrivateListPage composer presenta campo input, gap e pulsante con dimensioni coerenti', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: PrivateListPage(
              account: 'testuser',
              items: [],
              labels: EtichetteReport(defaultLabel: 'Da Assegnare', labels: []),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Nuovo item privato'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      final textFieldRect = tester.getRect(find.byType(TextField));
      final buttonRect = tester.getRect(find.byType(IconButton));

      // Verifica presenza del gap tra TextField e IconButton
      expect(buttonRect.left, greaterThan(textFieldRect.right));
      // Verifica altezza coerente (50px)
      expect(buttonRect.height, equals(50));
      expect(buttonRect.width, equals(50));
    });

    testWidgets('SettingsPage supporta selectedList null per superadmin senza liste', (tester) async {
      const superUser = AppUser(
        id: '1',
        username: 'amos',
        ruolo: 'superadmin',
        totpEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SettingsPage(
              api: Api(),
              user: superUser,
              lists: const [],
              selectedList: null,
              participants: const [],
              selectList: (_) async {},
              refreshLists: () async {},
              reloadSelected: () async {},
              onLogout: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nessuna lista attiva'), findsOneWidget);
      expect(find.text('Gestione utenti'), findsOneWidget);
      expect(find.text('Profilo e sicurezza'), findsOneWidget);
      expect(find.text('Esci', skipOffstage: false), findsOneWidget);
    });
  });
}

final _fixedDate = DateTime.parse('2026-09-07T12:00:00Z');
void _noop() {}


