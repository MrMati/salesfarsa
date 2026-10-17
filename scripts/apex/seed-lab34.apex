// Synthetic data only. E-mail remains opted out on every demonstration invoice.
if([SELECT count() FROM Account WHERE Name='[LAB3-4] Klient demonstracyjny']==0) {
    Account customer=new Account(Name='[LAB3-4] Klient demonstracyjny',Status__c='Active',Tax_Number__c='DEMO-NIP',Contact_Person__c='Osoba demonstracyjna');
    Account alfa=new Account(Name='[LAB3-4] Alfa — komplet kwalifikacji',Status__c='Active',Is_Provider__c=true,Service_Area__c='Lublin');
    Account beta=new Account(Name='[LAB3-4] Beta — komplet kwalifikacji',Status__c='Active',Is_Provider__c=true,Service_Area__c='Lublin');
    Account gamma=new Account(Name='[LAB3-4] Gamma — brak drugiej kwalifikacji',Status__c='Active',Is_Provider__c=true);
    insert new List<Account>{customer,alfa,beta,gamma};
    Skill__c first=new Skill__c(Name='Obsługa wyposażenia — demo',Code__c='LAB34_A');
    Skill__c second=new Skill__c(Name='Praca w obiektach biurowych — demo',Code__c='LAB34_B');insert new List<Skill__c>{first,second};
    Service__c service=new Service__c(Title__c='Sprzątanie techniczne — Lab 3–4',Service_Code__c='LAB34_CLEAN',Type__c='Cleaning',Category__c='Cleaning',Price__c=150,Time_Required__c=2,Is_Active__c=true,Detailed_Description__c='Usługa demonstracyjna wymagająca dwóch kwalifikacji.');insert service;
    insert new List<Service_Skill__c>{new Service_Skill__c(Service__c=service.Id,Skill__c=first.Id),new Service_Skill__c(Service__c=service.Id,Skill__c=second.Id)};
    insert new List<Account_Skill__c>{new Account_Skill__c(Account__c=alfa.Id,Skill__c=first.Id),new Account_Skill__c(Account__c=alfa.Id,Skill__c=second.Id),new Account_Skill__c(Account__c=beta.Id,Skill__c=first.Id),new Account_Skill__c(Account__c=beta.Id,Skill__c=second.Id),new Account_Skill__c(Account__c=gamma.Id,Skill__c=first.Id)};
    insert new List<Account_Service__c>{new Account_Service__c(Account_Id__c=alfa.Id,Service_Id__c=service.Id),new Account_Service__c(Account_Id__c=beta.Id,Service_Id__c=service.Id),new Account_Service__c(Account_Id__c=gamma.Id,Service_Id__c=service.Id)};
    Property__c property=new Property__c(Address__c='[LAB3-4] Nieruchomość demonstracyjna, Lublin',Owner__c=customer.Id,City__c='Lublin',Postal_Code__c='20-000',Street__c='Demonstracyjna',Building_Number__c='1',Country_Code__c='PL',Area__c=120,Building_Type__c='Office');insert property;
    Datetime startAt=Datetime.newInstanceGmt(Date.today().addDays(2),Time.newInstance(8,0,0,0));
    Invoice__c reserved=new Invoice__c(Amount__c=150,Country__c='PL',Property__c=property.Id,Service__c=service.Id,Account_Id__c=customer.Id,Provider__c=alfa.Id,Start__c=startAt,End__c=startAt.addHours(2),Status__c='To_Pay',Reference__c='LAB34_RESERVATION',Notify_Owner__c=false);
    Invoice__c paid=new Invoice__c(Amount__c=100,Country__c='PL',Property__c=property.Id,Service__c=service.Id,Account_Id__c=customer.Id,Status__c='Paid',Reference__c='LAB34_PAID',Notify_Owner__c=false);
    insert new List<Invoice__c>{reserved,paid};
    insert new Quote__c(Property__c=property.Id,Service__c=service.Id,Account__c=customer.Id,Start__c=startAt,End__c=startAt.addHours(2));
    // Safe live test of the event publisher/subscriber; no actual e-mail is requested.
    reserved.Status__c='Draft';update reserved;reserved.Status__c='To_Pay';update reserved;
}
System.debug('LAB34_SEED_OK');
