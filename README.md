# Salesfarsa — Salesforce, laboratoria 1–6

Wykonane i zweryfikowane 17.10.2026 w połączonym Developer Edition.
Materiał: Maciej Miłosz, „Komponentowe podejście do wytwarzania aplikacji”,
Politechnika Lubelska, 2022. Kontynuacja tej samej aplikacji; Lab 7–8 nie realizowano. Zadanie 6.3 wykonano w wariancie Home + LWC; CRM Analytics jest niedostępne.

Pełna, skumulowana errata: [GitHub Pages](https://mrmati.github.io/salesfarsa/) lub [docs/index.html](docs/index.html) (61 pozycji).
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
sf project deploy start --source-dir force-app --target-org developer --test-level RunSpecifiedTests --tests TaxCalculationServiceTest --tests Lab2ExamplesTest --tests Lab34Test --tests Lab4NotificationTest --tests Lab56SecurityTest --tests ServiceCostControllerTest --wait 10
sf apex run --file scripts/apex/seed-labs.apex --target-org developer
sf apex run --file scripts/apex/seed-lab34.apex --target-org developer
npm ci --ignore-scripts
npm run test:unit -- -- --runInBand
npm run lint
```

Pierwszy etap tworzy model i raporty przed walidacją osadzonego dashboardu na Home.
Drugi dodaje aplikację, Home, profile i grupy. NoTestRun służy tu wyłącznie do wstępnego wdrożenia w Developer Edition i nadania
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
jest komponent Aura sumujący wszystkie faktury brutto.

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
6. Aura sumuje brutto wszystkich faktur, także Cancelled. Total_Cost__c jest sumą
   brutto tylko Paid. Flow aktualizuje sumę przy zmianach statusu, netto, kraju,
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

- Metadata API: 54 metody testowe, 0 błędów. Asynchroniczny raport może doliczać metody @TestSetup; liczbę właściwych testów podaje Metadata API.
- 9 testów LWC, 3 pakiety, wszystkie PASS; ESLint bez błędów.
- Końcowy kontrakt wejść/wyjść providerPicker ponownie sprawdzono w przeglądarce;
  tymczasową fakturę utworzono i usunięto po potwierdzeniu.
- Pokrycie kodu i lista 54 metod z końcowego wdrożenia: `validation/apex-tests.json`.
  Testy obejmują również CRUD/FLS trzech aktorów, średnie kosztów oraz bulk undelete.
- Bulk: 200 faktur, 200 faktur do sumy Paid i 200 zapytań Quote.
- Zalogowana przeglądarka Salesforce: cały Screen Flow do zapisu, LWC DE, Aura,
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
Lab 5 sprawdza CRUD/FLS trzech profili z grupami przez System.runAs + USER_MODE. Nie wykonywano trzech osobnych sesji UI. OWD i hierarchia ról pozostają zakresem Lab 7.


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
| Opłacone koszty według miasta | Suma Property.Total_Cost__c, według miasta |

Cztery raporty Summary używają trzech Custom Report Types: `Lab_Invoices`,
`Lab_Executions`, `Lab_Properties`. Mają zakres wszystkich dat i widocznych danych.
Dynamiczny `Lab_Overview` działa jako **LoggedInUser**, bez stałego konta administratora
jako running user. Trzy wykresy wybierają agregaty ze źródłowych raportów. Raporty i
LWC respektują CRUD/FLS; publiczny wewnętrzny folder daje dostęp do definicji,
nie do ukrytych pól. Nie zmieniano OWD ani hierarchii ról z Lab 7.

LWC liczy średnią brutto faktury **na zakończone wykonanie**, grupując nieruchomość,
firmę i usługę. Wyklucza wykonania bez faktury i faktury Cancelled, pokazuje liczebność
próby. To odrębna miara od średniej opłaconej faktury. Komponent wspiera Home, App Page
oraz stronę rekordu Property; na rekordzie filtruje po bieżącej nieruchomości.
Zapytania używają USER_MODE, a po przekroczeniu 200 grup wyświetlana jest informacja
o ograniczeniu. Dane pieniężne są w jednej walucie orga; nie jest to konwersja walut.

**Ograniczenie zadania 6.3:** dokumentacja w PDF dotyczy CRM Analytics. Ten org ma
0 licencji Analytics Cloud Builder/Explorer i Wave API zwraca
`FUNCTIONALITY_NOT_ENABLED`. Standardowy dashboard raportów nie jest kontenerem
dowolnych LWC. Wykonano działający wariant **dashboard + LWC na Home**; nie osadzono
komponentu w niedostępnym dashboardzie CRM Analytics i nie uruchamiano triala.
Po zmianie danych odśwież raport/dashboard; wyświetlany cache może być starszy.

## Publikacja erraty

GitHub Pages publikuje folder `/docs` z gałęzi `main`:
<https://mrmati.github.io/salesfarsa/>. Strona jest statyczna — nie wymaga bundlera,
zewnętrznych fontów, bibliotek ani konta Salesforce. Edytuj `docs/index.html`, aby
zaktualizować erratę; PDF jest osobnym eksportem do odświeżenia po zmianach treści.

Podsumowania w `validation/` opisują wykonane sprawdzenia z 17.10.2026. Nie są
wynikiem nowego wdrożenia na każdym `git push`. Nie dodajemy do repozytorium surowych
logów, eksportu oryginalnego PDF, plików sesji, `node_modules` ani kolejnych kopii ZIP.
