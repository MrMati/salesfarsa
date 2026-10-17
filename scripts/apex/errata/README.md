# Próby fragmentów instrukcji

Te skrypty są celowymi reprodukcjami, a nie częścią wdrażanych klas. Nie wykonuj
całego katalogu jako jednego skryptu. Niektóre przykłady powinny zakończyć się
błędem kompilacji lub wykonania. `original-figure-2-2.apex` oraz
`original-soql.apex` potwierdzają, że podejrzane fragmenty działają.

Uruchamianie pojedynczej próby:

```bash
sf apex run --file scripts/apex/errata/original-figure-2-1.apex --target-org developer
```

Zwięzłe wyniki oryginalnych prób: `validation/probes.json` w głównym katalogu.
Kolejność `extends` / `implements` sprawdzono osobno przez walidację Metadata API,
ponieważ kontekst Execute Anonymous ma dodatkowe ograniczenia deklaracji klas.
