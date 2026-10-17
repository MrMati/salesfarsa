// Educational fixtures, NOT a legal VAT schedule. Reruns do not overwrite rates.
Map<String,Decimal> sampleRates=new Map<String,Decimal>{
    'PL'=>23,'DE'=>19,'FR'=>20,'ES'=>21,'IT'=>22,
    'PT'=>23,'NL'=>21,'BE'=>21,'AT'=>20,'CZ'=>21,
    'SK'=>23,'DK'=>25,'SE'=>25,'FI'=>25.5,'IE'=>23
};
Map<String,Country_Tax_Rate__c> existing=new Map<String,Country_Tax_Rate__c>();
for(Country_Tax_Rate__c rate:[SELECT Country__c,Tax__c FROM Country_Tax_Rate__c WHERE Country__c IN :sampleRates.keySet()]) {
    Assert.isFalse(existing.containsKey(rate.Country__c),'Duplicate country config; resolve manually.');
    existing.put(rate.Country__c,rate);
}
List<Country_Tax_Rate__c> rates=new List<Country_Tax_Rate__c>();
for(String country:sampleRates.keySet()) {
    if(!existing.containsKey(country)) rates.add(new Country_Tax_Rate__c(Country__c=country,Tax__c=sampleRates.get(country)));
    else Assert.areEqual(sampleRates.get(country),existing.get(country).Tax__c,'Existing rate differs; not overwritten.');
}
insert rates;
if([SELECT count() FROM Account WHERE Name='[LAB1-2] Wykonawca demonstracyjny']==0) {
    Account provider=new Account(Name='[LAB1-2] Wykonawca demonstracyjny',Status__c='Active');
    Account customer=new Account(Name='[LAB1-2] Klient demonstracyjny',Status__c='Active');
    insert new List<Account>{provider,customer};
    Service__c service=new Service__c(Type__c='Cleaning',Price__c=100,Time_Required__c=2);insert service;
    Property__c property=new Property__c(Address__c='Adres testowy, Lublin',Description__c='Syntetyczne dane do laboratoriów 1–2.',Owner__c=customer.Id,Geolocation__Latitude__s=51.2465,Geolocation__Longitude__s=22.5684);insert property;
    insert new Account_Service__c(Account_Id__c=provider.Id,Service_Id__c=service.Id,Is_Active__c=true);
    Invoice__c polish=new Invoice__c(Amount__c=100,Country__c='PL',Account_Id__c=customer.Id,Property__c=property.Id,Service__c=service.Id);
    Invoice__c german=new Invoice__c(Amount__c=250,Country__c='DE',Account_Id__c=customer.Id,Property__c=property.Id,Service__c=service.Id);
    insert new List<Invoice__c>{polish,german};
    insert new Payment__c(Account_Id__c=customer.Id,Invoice_Id__c=polish.Id,Date__c=Date.today(),Amount__c=123,Method__c='Transfer');
    insert new Service_Execution__c(Property__c=property.Id,Service__c=service.Id,Provider__c=provider.Id,Invoice__c=polish.Id,Completed_At__c=Datetime.now(),Status__c='Completed',Notes__c='Przykład kontrolny do zadań 1.2 i 1.4.');
}
Assert.areEqual(15,[SELECT count() FROM Country_Tax_Rate__c WHERE Country__c IN :sampleRates.keySet()]);
System.debug('LAB_SEED_OK: 15 sample country rates; sample service completion and two invoices.');
