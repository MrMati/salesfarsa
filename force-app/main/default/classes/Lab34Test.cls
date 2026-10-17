@IsTest
private class Lab34Test {
    static Datetime moment(Integer hours) { return Datetime.newInstanceGmt(2030,1,15,8,0,0).addHours(hours); }
    @TestSetup static void setup() {
        insert new List<Country_Tax_Rate__c>{new Country_Tax_Rate__c(Country__c='PL',Tax__c=23),new Country_Tax_Rate__c(Country__c='DE',Tax__c=19)};
        Account a=new Account(Name='A — komplet kwalifikacji',Status__c='Active',Is_Provider__c=true);
        Account b=new Account(Name='B — brak drugiej kwalifikacji',Status__c='Active',Is_Provider__c=true);
        Account customer=new Account(Name='Klient testowy');insert new List<Account>{a,b,customer};
        Service__c service=new Service__c(Title__c='Usługa testowa',Price__c=100,Time_Required__c=2,Is_Active__c=true);insert service;
        insert new List<Property__c>{new Property__c(Address__c='Miejsce A',Owner__c=customer.Id),new Property__c(Address__c='Miejsce B',Owner__c=customer.Id)};
        insert new List<Account_Service__c>{new Account_Service__c(Account_Id__c=a.Id,Service_Id__c=service.Id),new Account_Service__c(Account_Id__c=b.Id,Service_Id__c=service.Id)};
        Skill__c s1=new Skill__c(Name='Pierwsza',Code__c='S1');Skill__c s2=new Skill__c(Name='Druga',Code__c='S2');insert new List<Skill__c>{s1,s2};
        insert new List<Service_Skill__c>{new Service_Skill__c(Service__c=service.Id,Skill__c=s1.Id),new Service_Skill__c(Service__c=service.Id,Skill__c=s2.Id)};
        insert new List<Account_Skill__c>{new Account_Skill__c(Account__c=a.Id,Skill__c=s1.Id),new Account_Skill__c(Account__c=a.Id,Skill__c=s2.Id),new Account_Skill__c(Account__c=b.Id,Skill__c=s1.Id)};
    }
    static Id serviceId() {return [SELECT Id FROM Service__c LIMIT 1].Id;}
    static Id providerId() {return [SELECT Id FROM Account WHERE Name LIKE 'A —%' LIMIT 1].Id;}
    static Property__c property(String address) {return [SELECT Id,Total_Cost__c FROM Property__c WHERE Address__c=:address];}
    static Invoice__c bill(Decimal amount,String status,String place) {return new Invoice__c(Amount__c=amount,Country__c='PL',Status__c=status,Property__c=property(place).Id);}
    static Invoice__c booking(Integer start,Integer finish) {
        Invoice__c value=bill(100,'To_Pay','Miejsce A');value.Service__c=serviceId();value.Provider__c=providerId();value.Start__c=moment(start);value.End__c=moment(finish);return value;
    }
    @IsTest static void allSkillsRequired() {
        List<BookingEligibility.ProviderOption> options=InvoiceLabController.getAvailableProviders(serviceId(),moment(0),moment(2));
        Assert.areEqual(1,options.size());Assert.areEqual(providerId(),options[0].value);
    }
    @IsTest static void inactiveOfferOrProviderNotEligible() {
        Account provider=[SELECT Id,Status__c FROM Account WHERE Id=:providerId()];provider.Status__c='Inactive';update provider;
        Assert.areEqual(0,InvoiceLabController.getAvailableProviders(serviceId(),moment(0),moment(2)).size());
        provider.Status__c='Active';update provider;
        Account_Service__c offer=[SELECT Id,Is_Active__c FROM Account_Service__c WHERE Account_Id__c=:provider.Id LIMIT 1];offer.Is_Active__c=false;update offer;
        Assert.areEqual(0,InvoiceLabController.getAvailableProviders(serviceId(),moment(0),moment(2)).size());
    }
    @IsTest static void overlapAndAdjacentIntervals() {
        Invoice__c reservation=booking(0,2);insert reservation;
        Assert.areEqual(0,InvoiceLabController.getAvailableProviders(serviceId(),moment(1),moment(3)).size());
        Assert.areEqual(1,InvoiceLabController.getAvailableProviders(serviceId(),moment(2),moment(4)).size());
        reservation.Status__c='Cancelled';update reservation;
        Assert.areEqual(1,InvoiceLabController.getAvailableProviders(serviceId(),moment(1),moment(3)).size());
    }
    @IsTest static void staleProviderChoiceRejected() {
        insert booking(0,2);
        Database.SaveResult result=Database.insert(booking(1,3),false);
        Assert.isFalse(result.isSuccess());Assert.isTrue(result.getErrors()[0].getMessage().contains('unavailable'));
    }
    @IsTest static void sameBatchOverlapRejected() {
        Database.SaveResult[] results=Database.insert(new List<Invoice__c>{booking(0,2),booking(1,3)},false);
        Assert.isTrue(results[0].isSuccess());Assert.isFalse(results[1].isSuccess());
        Assert.areEqual(1,[SELECT count() FROM Invoice__c]);
    }
    @IsTest static void invalidIntervalsBlocked() {
        Invoice__c value=bill(100,'To_Pay','Miejsce A');value.Start__c=moment(0);value.End__c=moment(0);
        Database.SaveResult result=Database.insert(value,false);Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('later than'));
        value.End__c=null;result=Database.insert(value,false);Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('both service start'));
    }
    @IsTest static void serviceDurationFormulaAndValidation() {
        Service__c service=[SELECT Id,Duration_Minutes__c,Time_Required__c FROM Service__c LIMIT 1];Assert.areEqual(120,service.Duration_Minutes__c);
        service.Time_Required__c=0;Assert.isFalse(Database.update(service,false).isSuccess());
    }
    @IsTest static void taxSimulationDoesNotChangeInvoice() {
        Invoice__c invoice=bill(100,'To_Pay','Miejsce A');insert invoice;
        InvoiceLabController.PreviewContext context=InvoiceLabController.getPreview(invoice.Id);
        Assert.areEqual(100,context.amount);Assert.areEqual('PL',context.country);Assert.areEqual(2,context.rates.size());
        Assert.areEqual(23,[SELECT Tax_Amount__c FROM Invoice__c WHERE Id=:invoice.Id].Tax_Amount__c);
    }
    @IsTest static void duplicatePreviewRateIsRejected() {
        Invoice__c invoice=bill(100,'To_Pay','Miejsce A');insert invoice;
        insert new Country_Tax_Rate__c(Country__c='PL',Tax__c=8);
        Boolean failed=false;try {InvoiceLabController.getPreview(invoice.Id);}catch(AuraHandledException ex) {failed=true;}
        Assert.isTrue(failed);
    }
    @IsTest static void previewMissingInvoiceRejected() {
        Boolean failed=false;try {InvoiceLabController.getPreview(null);}catch(AuraHandledException ex) {failed=true;}
        Assert.isTrue(failed);Assert.areEqual(0,InvoiceLabController.getPropertyInvoiceTotal(null));
    }
    @IsTest static void auraSumAndPaidTotalHaveDifferentMeaning() {
        insert new List<Invoice__c>{bill(100,'To_Pay','Miejsce A'),bill(200,'Paid','Miejsce A'),bill(50,'Cancelled','Miejsce A')};
        Assert.areEqual(430.5,InvoiceLabController.getPropertyInvoiceTotal(property('Miejsce A').Id));
        Assert.areEqual(246,property('Miejsce A').Total_Cost__c);
    }
    @IsTest static void paidTotalTracksStatusAmountAndPropertyMove() {
        Invoice__c invoice=bill(100,'To_Pay','Miejsce A');insert invoice;Assert.areEqual(0,property('Miejsce A').Total_Cost__c);
        invoice.Status__c='Paid';update invoice;Assert.areEqual(123,property('Miejsce A').Total_Cost__c);
        invoice.Amount__c=200;update invoice;Assert.areEqual(246,property('Miejsce A').Total_Cost__c);
        invoice.Property__c=property('Miejsce B').Id;update invoice;
        Assert.areEqual(0,property('Miejsce A').Total_Cost__c);Assert.areEqual(246,property('Miejsce B').Total_Cost__c);
        invoice.Country__c='DE';update invoice;Assert.areEqual(238,property('Miejsce B').Total_Cost__c);
        invoice.Status__c='Cancelled';update invoice;Assert.areEqual(0,property('Miejsce B').Total_Cost__c);
    }
    @IsTest static void paidTotalTracksDelete() {
        Invoice__c invoice=bill(100,'Paid','Miejsce A');insert invoice;Assert.areEqual(123,property('Miejsce A').Total_Cost__c);
        delete invoice;Assert.areEqual(0,property('Miejsce A').Total_Cost__c);
    }
    @IsTest static void paidTotalsBulk200() {
        Id place=property('Miejsce A').Id;List<Invoice__c> values=new List<Invoice__c>();
        for(Integer i=0;i<200;i++) values.add(new Invoice__c(Amount__c=100,Country__c='PL',Property__c=place,Status__c='Paid'));
        Test.startTest();insert values;Test.stopTest();
        Assert.areEqual(24600,property('Miejsce A').Total_Cost__c);
    }
    @IsTest static void quoteFlowMatchesQualifiedCompany() {
        Quote__c request=new Quote__c(Property__c=property('Miejsce A').Id,Service__c=serviceId(),Start__c=moment(0),End__c=moment(2));insert request;
        request=[SELECT Status__c,Provider__c,Match_Explanation__c FROM Quote__c WHERE Id=:request.Id];
        Assert.areEqual('Assigned',request.Status__c);Assert.areEqual(providerId(),request.Provider__c);Assert.isTrue(request.Match_Explanation__c.contains('nie rezerwuje'));
    }
    @IsTest static void quoteFlowUnmatchedThenReassignedOnNewInterval() {
        insert booking(0,2);
        Quote__c request=new Quote__c(Property__c=property('Miejsce A').Id,Service__c=serviceId(),Start__c=moment(1),End__c=moment(3));insert request;
        request=[SELECT Status__c,Provider__c,Start__c,End__c FROM Quote__c WHERE Id=:request.Id];Assert.areEqual('Unmatched',request.Status__c);Assert.isNull(request.Provider__c);
        request.Start__c=moment(2);request.End__c=moment(4);update request;
        Assert.areEqual('Assigned',[SELECT Status__c FROM Quote__c WHERE Id=:request.Id].Status__c);
    }
    @IsTest static void quoteBulk200UsesBulkifiedAction() {
        List<Quote__c> requests=new List<Quote__c>();Id service=serviceId();Id place=property('Miejsce A').Id;
        for(Integer i=0;i<200;i++) requests.add(new Quote__c(Property__c=place,Service__c=service,Start__c=moment(0),End__c=moment(2)));
        Test.startTest();insert requests;Test.stopTest();
        Assert.areEqual(200,[SELECT count() FROM Quote__c WHERE Status__c='Assigned']);
    }
    @IsTest static void invalidRequestAndEmptyCollection() {
        Assert.areEqual(0,BookingEligibility.findProviders(null,null).size());
        Assert.areEqual(0,BookingEligibility.findProviders(new List<BookingEligibility.Request>(),null).size());
        Assert.areEqual(0,InvoiceLabController.getAvailableProviders(null,moment(0),moment(2)).size());
        Assert.areEqual(0,InvoiceLabController.getAvailableProviders(serviceId(),moment(2),moment(0)).size());
        Assert.isFalse(Database.insert(new Quote__c(),false).isSuccess());
        PropertyCostAction.recalculate(new List<PropertyCostAction.Input>());
    }
    @IsTest static void calculatedTaxCannotBeOverwrittenOnUpdate() {
        Invoice__c invoice=bill(100,'To_Pay','Miejsce A');insert invoice;invoice.Tax__c=99;invoice.Tax_Amount__c=999;update invoice;
        invoice=[SELECT Tax__c,Tax_Amount__c FROM Invoice__c WHERE Id=:invoice.Id];Assert.areEqual(23,invoice.Tax__c);Assert.areEqual(23,invoice.Tax_Amount__c);
    }
}
