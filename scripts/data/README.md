# Dane Lab 5–6

`accounts-2000.csv` zawiera 2000 syntetycznych firm, a `accounts.sdl` mapowanie
oficjalnego Salesforce Data Loadera. Nie zawierają Id ani danych logowania.

Po wdrożeniu metadanych wybierz w Data Loaderze **Upsert → Account → Lab_Key__c**,
wskaż CSV i mapowanie. Użyj OAuth do własnego orga. Konto importujące potrzebuje
uprawnień do Account i importowanych pól, w tym nowego Lab_Key__c.

Wykonany import: Data Loader 67.0.0, Java 21, tryb batch, Bulk API 2.0. Pierwszy
przebieg utworzył 2000 rekordów; drugi zaktualizował 2000, nie tworząc nowych.
Oba zakończyły się bez błędów. Konfiguracja prywatnej sesji, klucz szyfrujący,
pliki success/error i binaria narzędzia pozostają poza repozytorium.

Po imporcie wykonaj `scripts/apex/seed-lab56.apex`, a po przetworzeniu zdarzeń
`verify-lab56.apex`. Pierwszy skrypt tworzy po 10 rekordów zależnych i publikuje
10 Platform Events z wyłączonymi wiadomościami. Pełna powtórka nie dubluje danych;
częściowo usunięty zestaw wymaga przeglądu. Drugi skrypt sprawdza dane i kwoty,
a rekordy prób CRUD/upsert/merge/undelete wycofuje w całości przez rollback.

Użyte prefiksy `[LAB5-6]` i `LAB56-` wydzielają zestaw od wcześniejszych ćwiczeń.
