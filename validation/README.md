# Weryfikacja

Snapshot Lab 1–6 z 17.10.2026, rozszerzony i ponownie sprawdzony po Lab 7
18.10.2026 w Developer Edition. Pominięto sesje, identyfikatory orgu, dane logowania,
ścieżki maszyny i surowe logi.

| Plik | Zawartość |
| --- | --- |
| `summary.json` | Aktualny zakres, liczby testów, kategorie erraty i metadane |
| `apex-tests.json` | 66 właściwych metod testowych, 0 błędów i pokrycie kodu |
| `lab7-sharing.json` | Odczyt rzeczywistego OWD, hierarchii i liczebności danych; scenariusze dostępu |
| `import.json` | Historyczny Data Loader, 2000 rekordów; ponowny upsert bez duplikatów |
| `reports.json` | Cztery uruchomione raporty, agregaty zgodne z SOQL; po Lab 7 raport kosztów bazuje na Invoice Paid |
| `browser-checks.json` | Historyczne przejścia Lab 3–6, nowy lookup na fakturze oraz bieżąca kontrola erraty |
| `lab56-checks.json` | Wcześniejsze dane, kwoty, uprawnienia aktorów, DML i relacje |
| `probes.json` | Historyczne próby oryginalnych fragmentów Lab 1–4 |
| `runtime-limits.json` | Historyczny odczyt Limits w badanym kontekście |

Metadata API liczy 66 metod testowych; raport asynchroniczny może dodatkowo
liczyć pięć `@TestSetup`. Dziewięć testów LWC i ESLint przechodzi.

Dwanaście testów Lab 7 używa rzeczywistych wdrożonych ról, owner-based sharing rules,
minimalnych profili i Permission Set Groups. Pokazują różnicę pomiędzy prywatną
fakturą a Property udostępnioną w roli, zmianę roli, dziedziczenie przełożonego,
udostępnienie wskazanemu User, Read bez Edit, zmianę/wyczyszczenie odbiorcy,
niezależny Manual, Owner transfer, undelete, inactive User i 200 udziałów.

Testy wykluczają też obejście rezerwacji ukrytą fakturą oraz odczyt jej kosztu przez
widoczne wykonanie. Globalne Total_Cost__c jest ukryte przed trzema ograniczonymi
grupami aktorów; ich raport kosztów liczy widoczne Invoice Paid. Sam udział rekordu
nie omija CRUD ani FLS. Testowi użytkownicy i rekordy są wycofywani przez platformę;
nie pozostawiono stałych kont ani dodatkowych zajętych licencji.

UI na Lab 7 sprawdzono jako aktualny administrator, aby potwierdzić pole lookup.
Dowodami prywatności są USER_MODE i nieadministracyjni użytkownicy w testach,
a nie widok administratora. Nie deklarujemy trzech osobnych sesji UI aktorów,
Salesforce Mobile ani wielowątkowego testu obciążeniowego.

Po zmianie OWD `verify-lab56.apex` ponownie przeszedł kontrolę danych i próby DML;
rekordy tymczasowe wycofał przez rollback. Rzeczywistych e-maili nie wysyłano.
Zadanie 6.3 pozostaje wariantem natywny dashboard + LWC na Home, bez niedostępnego
CRM Analytics. Zakres nie obejmuje Lab 8.
