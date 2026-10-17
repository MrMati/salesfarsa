# Weryfikacja

Snapshot sprawdzeń z 17.10.2026, Developer Edition. Dane sesji, identyfikatory orgu,
ścieżki maszyny i surowe logi pominięto.

| Plik | Zawartość |
| --- | --- |
| `summary.json` | Zakres, liczby testów, kategorie erraty i wersje narzędzi |
| `apex-tests.json` | 45 metod testowych i pokrycie kodu |
| `browser-checks.json` | Przejście Screen Flow, Dynamic Forms, LWC/Aura i kontrola HTML |
| `probes.json` | Wyniki prób oryginalnych fragmentów, pod kluczami nazw dawnych logów |
| `runtime-limits.json` | Odczyt Limits w badanym kontekście, nie uniwersalna specyfikacja |

Asynchroniczny raport Salesforce liczył dodatkowo 2 metody `@TestSetup` — stąd
47 pozycji w niektórych komunikatach, przy 45 właściwych metodach testowych.
Komponenty LWC mają 6 testów; `npm run lint` przechodzi.

Testy serwerowe obejmowały 200 faktur, 200 rekordów do agregacji Paid i 200 Quote.
Przeglądarka przeszła całe zamówienie do rzeczywistego zapisu. Ostatnią dodatkową
fakturę sprawdzającą kontrakt komponentu Flow usunięto po potwierdzeniu.

Rzeczywiste zmiany faktur wygenerowały Platform Event i ślady EmailDisabled.
Pozytywną gałąź e-mail sprawdzono w testach Apex; nie dostarczano rzeczywistych
wiadomości. Nie wykonywano audytu wszystkich profili, testu Salesforce Mobile ani
wielowątkowego testu obciążeniowego.
