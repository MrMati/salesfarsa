# Salesfarsa — Salesforce, laboratoria 1–7

Lab 1–6 zweryfikowano 17.10.2026, Lab 7 — 18.10.2026 w połączonym Developer Edition.
Materiał: Maciej Miłosz, „Komponentowe podejście do wytwarzania aplikacji”,
Politechnika Lubelska, 2022. Kontynuacja tej samej aplikacji; Lab 8 nie realizowano. Zadanie 6.3 wykonano w wariancie Home + LWC; CRM Analytics jest niedostępne.

Pełna, skumulowana errata: [GitHub Pages](https://mrmati.github.io/salesfarsa/) lub [docs/index.html](docs/index.html) (73 pozycje).
[PDF](docs/errata.pdf) pomija długi załącznik kodu. HTML zawiera historyczny załącznik kodu Lab 1–4; kompletne bieżące źródła są w projekcie.
Repozytorium nie zawiera katalogów logowania, cookies, session IDs ani tokenów.

## Układ repozytorium

- `force-app/` — metadane, Apex, LWC, Aura, Flow i testy.
- `scripts/apex/` — dane demonstracyjne i próby z erraty.
- `config/` — definicja Scratch Org.
- `docs/` — samodzielna errata HTML i PDF, publikowane w GitHub Pages.
- `validation/` — zwięzłe, pozbawione danych logowania wyniki weryfikacji.

## Uruchomienie w Developer Edition

Wymagane: Node.js oraz Salesforce CLI. W folderze tego projektu:

```bash
git clone https://github.com/MrMati/salesfarsa.git
cd salesfarsa
sf org login web --instance-url https://login.salesforce.com --alias developer --set-default
sf project deploy start --source-dir force-app/main/default/objects --source-dir force-app/main/default/classes --source-dir force-app/main/default/triggers --source-dir force-app/main/default/flows --source-dir force-app/main/default/lwc --source-dir force-app/main/default/aura --source-dir force-app/main/default/reportTypes --source-dir force-app/main/default/reports --source-dir force-app/main/default/dashboards --target-org developer --test-level NoTestRun --wait 10
sf project deploy start --source-dir force-app --target-org developer --test-level NoTestRun --wait 10
sf org assign permset --name Property_Services_Labs --target-org developer
sf project deploy start --source-dir force-app --target-org developer --test-level RunSpecifiedTests --tests TaxCalculationServiceTest --tests Lab2ExamplesTest --tests Lab34Test --tests Lab4NotificationTest --tests Lab56SecurityTest --tests ServiceCostControllerTest --tests Lab7SharingTest --wait 10
sf apex run --file scripts/apex/seed-labs.apex --target-org developer
sf apex run --file scripts/apex/seed-lab34.apex --target-org developer
npm ci --ignore-scripts
npm run test:unit -- -- --runInBand
npm run lint
```

Pierwszy etap tworzy model i raporty przed walidacją osadzonego dashboardu na Home.
Drugi dodaje aplikację, Home, profile, grupy, role i reguły udostępniania. Po zmianie OWD platforma może wymagać zakończenia przeliczania udziałów przed wdrożeniem reguł; jeżeli zgłosi sharing operation already in progress, powtórz wdrożenie reguł po ukończeniu tej operacji. NoTestRun służy tu wyłącznie do wstępnego wdrożenia w Developer Edition i nadania
uprawnień do nowych pól. Końcowe wdrożenie wykonuje rzeczywiste testy.
W chmurowej sesji dodawano `SFDX_DISABLE_DNS_CHECK=true` przed komendami sf,
ponieważ lokalny test DNS CLI nie obsługiwał proxy. HTTPS i weryfikacja TLS
pozostały włączone. Na zwykłym komputerze to ustawienie nie powinno być potrzebne.

Strony przypisano profilowi Admin w aplikacji Property_Services_Labs, dla form factor
Large. Dla innego profilu aktywuj strony w App Builder albo dostosuj
profileActionOverrides. Plik Admin.profile-meta.xml zmienia tylko przypisanie layoutu
Account; nie zastępuje całości profilu ani jego uprawnień.

## Co otworzyć

App Launcher → **Usługi nieruchomości — Lab** → **Zamów usługę**.
Wybierz usługę, nieruchomość, kraj i termin, następnie firmę. Formularz zapisuje fakturę
z wykonawcą i wyliczonym podatkiem. Na fakturze jest symulator LWC. Na nieruchomości
jest komponent Aura sumujący widoczne faktury brutto.

Przy danych demonstracyjnych:

- `[LAB3-4] Alfa` ma komplet kwalifikacji, ale zajęty pierwszy termin.
- `[LAB3-4] Beta` ma komplet i jest dostępna; Quote rekomenduje tę firmę.
- `[LAB3-4] Gamma` nie ma drugiej wymaganej kwalifikacji.
- Po przejściu UI w tej sesji suma faktur nieruchomości to 492 PLN brutto,
  a Total_Cost__c opłaconych to 123. Formularz utworzył netto 150, podatek 34.50.
- Skrypty seed nie powielają kompletnej demonstracji. Nie naprawiają części danych
  ręcznie usuniętych po utworzeniu. verify-lab34.apex dotyczy dokładnego stanu po
  wykonanym tutaj przejściu UI; po dodaniu własnych faktur trzeba zmienić oczekiwania.

## Przyjęte reguły biznesowe

1. Amount__c = netto; Tax__c = Percent, w Apex 23 oznacza 23%; podatek zaokrąglany
   HALF_UP do dwóch miejsc. Gross_Amount__c = netto + podatek. Symulacja kraju
   zmienia tylko stawkę, nie walutę i nie zapis faktury.
2. Trigger działa przed insert oraz update. Zmiana kwoty lub kraju przelicza podatek.
   Inne edycje zachowują historycznie zapisane Tax i Tax_Amount; próba ręcznego
   nadpisania tych pól jest odwracana przez serwer.
3. Statusy faktury: Draft, To_Pay, Paid, Cancelled. Tax__c na Dynamic Forms widoczne
   tylko dla To_Pay. Layout ma Tax Readonly. Admin posiada jednak EditReadonlyFields
   i może widzieć edycję readonly; nie odbierano tego uprawnienia całemu profilowi.
4. Jedna firma realizuje jedną usługę naraz. Przedziały są [start,end), więc usługi mogą
   stykać się końcem/początkiem. Cancelled zwalnia termin. Wybrana firma jest ponownie
   sprawdzana przy zapisie pod blokadą rekordu; wykrywane są też kolizje jednej porcji.
5. Firma musi być aktywna, mieć aktywną ofertę i WSZYSTKIE kwalifikacje usługi.
   Quote wybiera pierwszą alfabetycznie, potem po Id; sam nie rezerwuje czasu.
6. Aura sumuje brutto widocznych faktur, także Cancelled. Total_Cost__c jest globalną sumą
   brutto tylko Paid, udostępnioną administracji. Flow aktualizuje sumę przy zmianach statusu, netto, kraju,
   nieruchomości (starej i nowej) i usunięciu faktury.

## Aktywne Flow

- Lab3_Service_Order — Screen Flow, dwie strony wprowadzania + potwierdzenie/błąd.
- Lab4_Property_Paid_Total — zmiany/create faktur, wywołanie agregacji Paid.
- Lab4_Property_Total_On_Delete — przed delete, agregacja z wykluczeniem usuwanych Id.
- Lab4_Quote_Match — kwalifikacje i dostępność; zapis rekomendacji lub Unmatched.
- Lab4_Invoice_Change_Publisher — istotna zmiana faktury, utworzenie Invoice_Changed__e.
- Lab4_Invoice_Change_Subscriber — odebrany event, deduplikacja i powiadomienie.

Process Builder z zadania 4.1 zastąpiono wspieranym Record-Triggered Flow;
nie deklarujemy wykonania ćwiczenia w starym kreatorze.

## Powiadomienia

Invoice_Changed__e ma PublishAfterCommit. Klucz pochodzi z Flow.InterviewGuid.
Subscriber ponownie odczytuje rzeczywistego właściciela i Notify_Owner__c z faktury;
nie ufa odbiorcy przesłanemu w evencie. Invoice_Notification__c przechowuje ślad
z unikalnym kluczem, co zapobiega ponownemu obsłużeniu tego samego zdarzenia.

Notify_Owner__c jest domyślnie false. Podczas demonstracji nie wysyłano rzeczywistych
e-maili; przetwarzane zdarzenia mają EmailDisabled. Użytkownik może świadomie włączyć
powiadomienia na konkretnej fakturze; następna istotna zmiana uruchomi żądanie wysyłki
do właściciela User. Contact_Email__c i Billing_Email__c nie są odbiorcami tego procesu.
Testy sprawdzają dodatnią gałąź Messaging.sendEmail w trybie testowym Salesforce,
który nie dostarcza wiadomości. EmailSent oznacza przyjęcie żądania, nie dowód SMTP.

## Weryfikacja

- Metadata API: 66 metod testowych, 0 błędów. Asynchroniczny raport może doliczać metody @TestSetup; liczbę właściwych testów podaje Metadata API.
- 9 testów LWC, 3 pakiety, wszystkie PASS; ESLint bez błędów.
- Etap Lab 3–4 (17.10): kontrakt wejść/wyjść providerPicker sprawdzono w przeglądarce;
  tymczasową fakturę utworzono i usunięto po potwierdzeniu.
- Pokrycie kodu i lista 66 metod z końcowego wdrożenia: `validation/apex-tests.json`.
  Testy obejmują również CRUD/FLS trzech aktorów, średnie kosztów oraz bulk undelete.
- Bulk: 200 faktur, 200 faktur do sumy Paid i 200 zapytań Quote.
- Etap Lab 3–4 (17.10), zalogowana przeglądarka: Screen Flow do zapisu, LWC DE, Aura,
  Tax__c widoczne dla To_Pay i ukryte przy Paid.
- Rzeczywiste zdarzenia po zapisie odebrane przez subscriber i zarejestrowane bez e-maili.

Dowody w [`validation/`](validation/). Testy używają własnych danych, bez SeeAllData=true.
Błędne skrypty w scripts/apex/errata odtwarzają przykłady PDF; nie są wdrażanymi klasami.

## Granice

Stawki są edukacyjne, bez dat obowiązywania i kategorii podatkowych. Quote nie konwertuje
się automatycznie na Invoice i nie reaguje sam na późniejszą rezerwację innego użytkownika.
After undelete ponownie sprawdza rezerwację i przelicza sumę Paid. Nie dodano harmonogramu wielu ekip ani automatycznego salda
Account. Minimum_Notice_Hours__c i Cancellation_Notice_Hours__c są polami informacyjnymi.

Interfejs sprawdzono w przeglądarce desktopowej; erratę osobno na telefonowej szerokości.
Nie testowano natywnej aplikacji Salesforce Mobile ani wielowątkowego obciążenia blokad.
Lab 5 sprawdza CRUD/FLS trzech profili z grupami przez System.runAs + USER_MODE. Nie wykonywano trzech osobnych sesji UI. Lab 7 wprowadza prywatne OWD, hierarchię ról i reguły udostępniania.


## Laboratoria 5–6

Trzej aktorzy mają osobne minimalne profile i grupy o nazwach `Lab_Coordinator`,
`Lab_Accountant`, `Lab_Analyst`. Nie przypisuj im pełnego `Property_Services_Labs`:
uprawnienia sumują się, więc zepsułoby to ograniczenia sprawdzane w Lab 5.

| Aktor | Uprawnienia procesu | Celowo bez dostępu |
| --- | --- | --- |
| Koordynator usług | Katalog, nieruchomości, zamówienia, faktury, Quote, wykonania | Payment, finansowe pola Account |
| Księgowość | Odczyt wykonania, rozliczenia, płatności, finansowe pola Account | Instrukcje wejścia do budynku, edycja wykonania |
| Analityk kosztów | Odczyt nieruchomości, faktur i wykonań, raporty | Zapis, płatności, prywatne notatki i kontakt z faktur |

Grupy składają się z `Lab_Catalog_Read`, `Lab_Reports` i odpowiednio
`Lab_Operations`, `Lab_Finance` lub `Lab_Analytics_Read`. Testy tworzą własnych
użytkowników na tych profilach i przypisują grupy, a następnie sprawdzają dozwolone
zapisy oraz odmowę operacji i odczytu pól. Minimalny profil bez grupy nie ma dostępu.
Org ma dwie licencje Salesforce, jedną zajmuje administrator. Nie zostawiono trzech
stałych aktywnych użytkowników; testowy `runAs` pomija limit licencji.

Po wdrożeniu i wykonaniu wcześniejszych seedów:

1. W oficjalnym [Data Loaderze](https://github.com/forcedotcom/dataloader/releases/tag/v67.0.0)
   wybierz **Upsert → Account → Lab_Key__c**, wczytaj
   `scripts/data/accounts-2000.csv` i mapowanie `scripts/data/accounts.sdl`.
   Zaloguj się własnym OAuth. Konfigurację sesji i pliki wynikowe trzymaj poza repo.
2. Uruchom `sf apex run --file scripts/apex/seed-lab56.apex --target-org developer`.
3. Po przetworzeniu zdarzeń uruchom
   `sf apex run --file scripts/apex/verify-lab56.apex --target-org developer`.

W tej sesji wykonano oficjalny Data Loader 67.0.0 w trybie batch na Java 21,
przez Bulk API 2.0. Pierwszy przebieg: 2000 utworzonych, 0 błędów. Powtórka:
2000 aktualizacji, 0 nowych, 0 błędów. Klucz zewnętrzny zapobiega duplikowaniu.
Plik CSV jest syntetyczny, bez prawdziwych adresów e-mail.

Seed dodaje po 10 nieruchomości, usług, kwalifikacji, ofert, powiązań kwalifikacji,
faktur, płatności, wykonań i zapytań. Zachowuje wcześniejsze 15 stawek krajów.
Dla Platform Event publikuje 10 testowych zdarzeń; subscriber zapisuje ślady
EmailDisabled. Nie są to ręcznie wpisane logi symulujące odbiór. Wysłanie e-maili
pozostaje wyłączone. Kompletna powtórka seeda nie dubluje danych; częściowo usunięty
zestaw wymaga przeglądu i nie jest automatycznie naprawiany.

Kwoty kontrolne zestawu `[LAB5-6]`: faktury 1783,50 brutto, Paid 922,50,
płatności 922,50. `verify-lab56.apex` sprawdza też relacje, Id15/18, insert/update,
upsert według External ID, delete/undelete, merge Account i częściowy sukces DML.
Wszystkie rekordy tymczasowych prób są wycofywane przez rollback.

## Raporty i strona główna

W aplikacji **Usługi nieruchomości — Lab** otwórz **Home**. Na stronie znajduje się
natywny dashboard i LWC **Średni koszt wykonanej usługi**. Zakładki Reports/Dashboards
prowadzą do folderu **Laboratoria — usługi nieruchomości**.

| Raport | Pytanie i miara |
| --- | --- |
| Realizacja usług — koordynator | Liczba wykonań według statusu |
| Należności i rozliczenia — księgowość | Suma brutto faktur według statusu, terminy w szczegółach |
| Średnia faktura opłacona — analityk | AVG brutto faktury Paid, według firmy |
| Opłacone faktury — nieruchomości | Suma brutto widocznych faktur Paid, według nieruchomości |

Wdrożono trzy Custom Report Types: `Lab_Invoices`,
`Lab_Executions`, `Lab_Properties`. Po Lab 7 raporty aktorów korzystają z Invoice/Execution;
typ Property z globalnym rollupem pozostaje do zastosowań administracyjnych.
Raporty mają zakres wszystkich dat i widocznych danych.
Dynamiczny `Lab_Overview` działa jako **LoggedInUser**, bez stałego konta administratora
jako running user. Trzy wykresy wybierają agregaty ze źródłowych raportów. Raporty i
LWC respektują CRUD/FLS; publiczny wewnętrzny folder daje dostęp do definicji,
nie do ukrytych pól. W Lab 7 zastosowano prywatne OWD i hierarchię ról; raporty i LWC pokazują dostępny użytkownikowi wycinek.

LWC liczy średnią brutto faktury **na zakończone wykonanie**, grupując nieruchomość,
firmę i usługę. Wyklucza wykonania bez faktury i faktury Cancelled, pokazuje liczebność
próby. To odrębna miara od średniej opłaconej faktury. Komponent wspiera Home, App Page
oraz stronę rekordu Property; na rekordzie filtruje po bieżącej nieruchomości.
Zapytania używają USER_MODE, a po przekroczeniu 200 grup wyświetlana jest informacja
o ograniczeniu. Dane pieniężne są w jednej walucie orga; nie jest to konwersja walut.
Po Lab 7 globalne Property.Total_Cost__c jest ukryte dla ograniczonych aktorów.
Ich raport kosztów liczy sumę wyłącznie z widocznych faktur Paid, grupując po
nieruchomości; administrator nadal widzi oryginalny rollup Lab 4.

**Ograniczenie zadania 6.3:** dokumentacja w PDF dotyczy CRM Analytics. Ten org ma
0 licencji Analytics Cloud Builder/Explorer i Wave API zwraca
`FUNCTIONALITY_NOT_ENABLED`. Standardowy dashboard raportów nie jest kontenerem
dowolnych LWC. Wykonano działający wariant **dashboard + LWC na Home**; nie osadzono
komponentu w niedostępnym dashboardzie CRM Analytics i nie uruchamiano triala.
Po zmianie danych odśwież raport/dashboard; wyświetlany cache może być starszy.

## Laboratorium 7 — widoczność rekordów

Cztery role tworzą hierarchię: **Lab7_Manager** nad trzema równorzędnymi rolami
**Lab7_Coordinator**, **Lab7_Accountant**, **Lab7_Analyst**. Rola odpowiada za zakres
rekordów; profil i Permission Set Group nadal ograniczają obiekty, pola i operacje.
Administrator z View All Data nie jest reprezentatywnym użytkownikiem do testowania
prywatności. Testy używają rzeczywistych minimalnych profili bez tego uprawnienia.

Wszystkie obiekty danych z właścicielem mają **Private** wewnętrznie i zewnętrznie,
a trzy junction objects nadal **ControlledByParent**. Włączone dziedziczenie ról
na obiektach custom daje przełożonemu dostęp do rekordów podwładnych. Zmiana OWD
Account wymagała także Private dla standardowych Case i Opportunity, które wcześniej
miały szerszą widoczność. Contact nie jest częścią modelu aplikacji i nie był zmieniany.
Nie dodano aktorom uprawnień do Case, Contact ani Opportunity.

Wyjątki od prywatnego OWD są jawne i węższe od dawnych publicznych ustawień:

| Mechanizm | Zakres i poziom |
| --- | --- |
| Cztery owner-based sharing rules Property | Właściciel i odbiorcy dokładnie w tej samej roli; Edit dla koordynatora/kierownika, Read dla księgowości/analityka |
| Criteria-based Account | Tylko Active + Is_Provider; Read dla wewnętrznych ról pod Lab7_Manager |
| Criteria-based Service | Tylko aktywne usługi; Read dla tych ról |
| Criteria-based Skill | Tylko kwalifikacje z kodem; Read |
| Criteria-based Country_Tax_Rate | Stawki >= 0; Read |

Reguły katalogowe nie udostępniają faktur, płatności, Quote ani wykonań. Odczyt obu
masterów umożliwia odczyt ofert i kwalifikacji z junction objects. W każdym przypadku
CRUD/FLS nadal obowiązuje. Reguła Property nie udostępnia automatycznie faktur danej
nieruchomości — relacja jest Lookup, a nie Master-Detail.

### Udostępnienie faktury przez pole — 7.3

`Invoice__c.Shared_With__c` wskazuje aktywnego User. Pole jest na layoucie i Dynamic
Forms; edytują je koordynator oraz księgowość, analityk ma tylko odczyt.
`InvoiceSharingService`, uruchamiany przez trigger, utrzymuje **Read** w
`Invoice__Share` z własnym RowCause **Selected_User__c**.

- Insert / zmiana pola nadaje odczyt nowemu użytkownikowi i usuwa poprzedni udział
  tego mechanizmu. Wyczyszczenie usuwa go całkowicie.
- Manual, Owner i Rule to odrębne źródła dostępu i nie są kasowane. Zmiana pola
  nie gwarantuje utraty dostępu, jeśli użytkownik ma inny udział albo jest przełożonym.
- Własny powód udziału zachowuje go przy przeniesieniu właściciela; undelete
  odtwarza wymagany stan. Udział właściciela nie jest powielany.
- Nieaktywny odbiorca jest blokowany walidacją. Błąd nadania udziału wycofuje zapis
  faktury, żeby nie pozostawić niespełnionej deklaracji w polu.
- Udział nie nadaje CRUD/FLS i nie udostępnia automatycznie rodziców ani wykonania
  usługi. Samo wskazanie użytkownika bez dostępu do Invoice nie daje mu obiektu.

To kontrolowana delegacja odczytu przez edytorów pola. Nie jest to twierdzenie,
że każdy zwykły edytor rekordu ma prawo do standardowego Manual Sharing.

### Reguły systemowe po włączeniu Private

Cudze faktury nadal zajmują termin. UI pobiera katalog z USER_MODE, a ukryte
rezerwacje są używane wewnętrznie tylko do decyzji dostępny/niedostępny. Walidacja
triggera działa na pełnych danych, z blokadą wykonawcy; nie oddaje danych cudzej
faktury. Dostęp do klas systemowych nie jest wystawiony jako nowy endpoint LWC.
Konfiguracja podatku jest odczytywana w kontekście automatyzacji.

Agregacja średnich wymaga widoczności zarówno Service_Execution, jak i powiązanej
Invoice. Jawny semi-join do Invoice w USER_MODE zapobiega ujawnieniu kwoty przez
widoczne wykonanie połączone z prywatną fakturą. Denial test obejmuje ten przypadek.
Globalny rollup Property.Total_Cost__c pozostaje wskaźnikiem administracyjnym: trzy
procesowe permission sety jawnie odmawiają odczytu tego pola. Raport
Lab_Property_Costs został przepisany na widoczne Invoice Paid, ponieważ zapisana
suma globalna nie może bezpiecznie zastąpić sumy zależnej od użytkownika.

`Lab7SharingTest` sprawdza prywatność między rolami i osobami tej samej roli,
dziedziczenie przełożonego, zmianę roli, nieruchomości współdzielone w roli,
nadanie/zamianę/wycofanie udziału faktury, niezależny Manual, zmianę właściciela,
undelete, 200 udziałów, inactive User, CRUD oraz ukryte rezerwacje i koszt faktury.
Użytkownicy są tworzeni tylko w testach i wycofywani; nie zostają nowe stałe konta
ani dodatkowe zajęte licencje. Nie deklarujemy trzech osobnych sesji UI aktorów.

## Publikacja erraty

GitHub Pages publikuje folder `/docs` z gałęzi `main`:
<https://mrmati.github.io/salesfarsa/>. Strona jest statyczna — nie wymaga bundlera,
zewnętrznych fontów, bibliotek ani konta Salesforce. Edytuj `docs/index.html`, aby
zaktualizować erratę; PDF jest osobnym eksportem do odświeżenia po zmianach treści.

Podsumowania w `validation/` opisują wykonane sprawdzenia z 17–18.10.2026. Nie są
wynikiem nowego wdrożenia na każdym `git push`. Nie dodajemy do repozytorium surowych
logów, eksportu oryginalnego PDF, plików sesji, `node_modules` ani kolejnych kopii ZIP.
