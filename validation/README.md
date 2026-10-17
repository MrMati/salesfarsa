# Weryfikacja

Snapshot z 17.10.2026 w Developer Edition; zakres Lab 1–6. Pominięto sesje,
identyfikatory orgu, ścieżki maszyny, konfigurację Data Loadera i surowe logi.

| Plik | Zawartość |
| --- | --- |
| `summary.json` | Zakres, liczby testów, kategorie erraty i metadane |
| `apex-tests.json` | 54 właściwe metody testowe, 0 błędów i pokrycie kodu |
| `import.json` | Oficjalny Data Loader, 2000 rekordów; ponowny upsert bez duplikatów |
| `reports.json` | Cztery raporty uruchomione przez Analytics REST, agregaty zgodne z SOQL |
| `browser-checks.json` | Historyczne przejście Lab 3–4 oraz Home/dashboard/LWC z Lab 6 i kontrola erraty |
| `lab56-checks.json` | Dane powiązane, kwoty, uprawnienia aktorów, DML i relacje |
| `probes.json` | Próby oryginalnych fragmentów Lab 1–4, nazwy dawnych logów |
| `runtime-limits.json` | Historyczny odczyt Limits w badanym kontekście |

Metadata API liczy 54 metody testowe; asynchroniczny raport testów może dodatkowo
liczyć cztery metody `@TestSetup`. Dziewięć testów LWC i ESLint przechodzi.
Testy bezpieczeństwa tworzą trzech użytkowników na wdrożonych profilach i grupach,
sprawdzają uprawnione operacje oraz odmowę zapisu i odczytu pól przez USER_MODE.
Nie pozostawiają stałych aktywnych użytkowników i nie zużywają trzech licencji.
Nie wykonywano trzech oddzielnych sesji UI tych aktorów ani konfiguracji ról z Lab 7.

Testy obejmują porcje 200 faktur, 200 Quote, 200 przywróconych faktur i 201+ grup
kosztowych, odrzucenie kolizji po undelete, AVG z dwóch kwot oraz wykluczenia.
Próby z `verify-lab56.apex` wycofują rekordy tymczasowe przez rollback.

Zdarzenia seeda dały rzeczywiste ślady EmailDisabled. Rzeczywistych e-maili nie wysyłano.
Nie wykonywano testu Salesforce Mobile ani wielowątkowego obciążenia blokad.
Task 6.3 wykonano jako natywny dashboard i LWC obok niego na Home. CRM Analytics
ma 0 licencji; nie deklarujemy bezpośredniego osadzenia LWC w jego dashboardzie.
