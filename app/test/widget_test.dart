import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partysync/api.dart';
import 'package:partysync/app_theme.dart';
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

  testWidgets('la sezione admin espone creazione utenti', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSection(
            users: const [],
            busy: false,
            onCreate: () {},
            onEdit: (_) {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('admin-section')), findsOneWidget);
    expect(find.byKey(const Key('create-user')), findsOneWidget);
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
}

void _noop() {}
