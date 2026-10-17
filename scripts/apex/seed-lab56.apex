// Run after Data Loader upsert of scripts/data/accounts-2000.csv and earlier seeds.
// Creates an isolated, synthetic dataset. A complete rerun is a no-op; partial data requires review.
List<Property__c> existing=[SELECT Id FROM Property__c WHERE Address__c LIKE '[LAB5-6]%'];
if(!existing.isEmpty()) {
    Assert.areEqual(10,existing.size(),'Partial Lab 5–6 dataset: review before reseeding.');
    System.debug('LAB56: dataset already exists; no records duplicated.');
} else {
    Assert.isTrue([SELECT COUNT() FROM Country_Tax_Rate__c]>=10,'Run seed-labs.apex first.');
    List<Account> firms=[SELECT Id,Name FROM Account WHERE Lab_Key__c LIKE 'LAB56-ACCOUNT-%' ORDER BY Lab_Key__c LIMIT 10];
    Assert.areEqual(10,firms.size(),'Import accounts-2000.csv with Data Loader first.');
    List<Property__c> places=new List<Property__c>();
    List<Service__c> services=new List<Service__c>();
    List<Skill__c> skills=new List<Skill__c>();
    for(Integer i=0;i<10;i++) {
        places.add(new Property__c(Address__c='[LAB5-6] Budynek '+(i+1),City__c=Math.mod(i,2)==0?'Lublin':'Świdnik',Country_Code__c='PL',Owner__c=firms[i].Id,Access_Notes__c='Syntetyczne dane operacyjne'));
        services.add(new Service__c(Title__c='[LAB5-6] Usługa '+(i+1),Service_Code__c='LAB56-SERVICE-'+i,Type__c='Cleaning',Category__c='Cleaning',Price__c=100+10*i,Time_Required__c=1,Is_Active__c=true));
        skills.add(new Skill__c(Name='[LAB5-6] Kwalifikacja '+(i+1),Code__c='LAB56-SKILL-'+i));
    }
    insert places;insert services;insert skills;
    List<Account_Service__c> offers=new List<Account_Service__c>();
    List<Account_Skill__c> possessed=new List<Account_Skill__c>();
    List<Service_Skill__c> required=new List<Service_Skill__c>();
    for(Integer i=0;i<10;i++) {
        offers.add(new Account_Service__c(Account_Id__c=firms[i].Id,Service_Id__c=services[i].Id,Is_Active__c=true));
        possessed.add(new Account_Skill__c(Account__c=firms[i].Id,Skill__c=skills[i].Id));
        required.add(new Service_Skill__c(Service__c=services[i].Id,Skill__c=skills[i].Id));
    }
    insert offers;insert possessed;insert required;
    List<Invoice__c> bills=new List<Invoice__c>();
    for(Integer i=0;i<10;i++) {
        Datetime startAt=Datetime.newInstanceGmt(2026,9,1,8,0,0).addDays(i);
        bills.add(new Invoice__c(Amount__c=100+10*i,Country__c='PL',Property__c=places[i].Id,Service__c=services[i].Id,Provider__c=firms[i].Id,Account_Id__c=firms[i].Id,
            Start__c=startAt,End__c=startAt.addHours(1),Issued_Date__c=startAt.dateGmt(),Due_Date__c=startAt.dateGmt().addDays(14),Status__c=i<6?'Paid':'To_Pay',Reference__c='LAB56-INVOICE-'+i,Notify_Owner__c=false));
    }
    insert bills;
    Map<Id,Invoice__c> saved=new Map<Id,Invoice__c>([SELECT Id,Gross_Amount__c FROM Invoice__c WHERE Id IN :bills]);
    List<Service_Execution__c> executions=new List<Service_Execution__c>();
    List<Payment__c> payments=new List<Payment__c>();
    List<Quote__c> quotes=new List<Quote__c>();
    for(Integer i=0;i<10;i++) {
        executions.add(new Service_Execution__c(Property__c=places[i].Id,Service__c=services[i].Id,Provider__c=firms[i].Id,Invoice__c=bills[i].Id,Status__c='Completed',Completed_At__c=bills[i].End__c,Notes__c='LAB56: wykonanie demonstracyjne'));
        Integer paidIndex=Math.mod(i,6);
        payments.add(new Payment__c(Account_Id__c=firms[paidIndex].Id,Invoice_Id__c=bills[paidIndex].Id,Amount__c=saved.get(bills[paidIndex].Id).Gross_Amount__c/(paidIndex<4?2:1),Date__c=Date.newInstance(2026,9,20),Method__c='Transfer'));
        Datetime future=System.now().addDays(30+i);
        quotes.add(new Quote__c(Property__c=places[i].Id,Service__c=services[i].Id,Account__c=firms[i].Id,Start__c=future,End__c=future.addHours(1),Status__c='New'));
    }
    insert executions;insert payments;insert quotes;
    System.debug('LAB56: 10 records per related object; invoice events will produce audit logs asynchronously, without emails.');
}
// Platform Events are not durable sObject records. Publish ten test messages with
// stable keys; the existing subscriber records actual processing, with email opt-in off.
Set<String> processed=new Set<String>();
for(Invoice_Notification__c log:[SELECT Event_Key__c FROM Invoice_Notification__c WHERE Event_Key__c LIKE 'LAB56-SEED-%']) processed.add(log.Event_Key__c);
List<Invoice_Changed__e> events=new List<Invoice_Changed__e>();
for(Invoice__c invoice:[SELECT Id,OwnerId,Reference__c,Notify_Owner__c FROM Invoice__c WHERE Reference__c LIKE 'LAB56-INVOICE-%']) {
    String key='LAB56-SEED-'+invoice.Reference__c;
    if(!processed.contains(key)) {
        Assert.isFalse(invoice.Notify_Owner__c,'Seed events must not send emails.');
        events.add(new Invoice_Changed__e(Invoice_Id__c=invoice.Id,Owner_Id__c=invoice.OwnerId,Change_Key__c=key,Summary__c='LAB56: test zdarzenia, bez e-maila'));
    }
}
if(!events.isEmpty()) for(Database.SaveResult published:EventBus.publish(events)) Assert.isTrue(published.isSuccess());
