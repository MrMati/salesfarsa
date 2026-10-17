@IsTest
private class TaxCalculationServiceTest {
    @TestSetup
    static void setupRates() {
        insert new List<Country_Tax_Rate__c>{
            new Country_Tax_Rate__c(Country__c='PL', Tax__c=23),
            new Country_Tax_Rate__c(Country__c='DE', Tax__c=19),
            new Country_Tax_Rate__c(Country__c='IE', Tax__c=0)
        };
    }
    static Invoice__c invoice(Decimal amount, String country) {
        return new Invoice__c(Amount__c=amount, Country__c=country);
    }
    static void assertFailure(Invoice__c value, String message) {
        Database.SaveResult result = Database.insert(value, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains(message), result.getErrors()[0].getMessage());
    }
    @IsTest static void fixedRateAndRounding() {
        Assert.areEqual(23, TaxCalculationService.calculateFixedTax(invoice(100,'PL')));
        Assert.areEqual(0.12, TaxCalculationService.calculateFixedTax(invoice(0.50,'PL')));
    }
    @IsTest static void fixedRateInvalidInput() {
        for (Invoice__c value : new List<Invoice__c>{null, invoice(null,'PL'), invoice(-1,'PL')}) {
            Boolean thrown=false;
            try { TaxCalculationService.calculateFixedTax(value); }
            catch (TaxCalculationService.TaxInputException ex) { thrown=true; }
            Assert.isTrue(thrown);
        }
    }
    @IsTest static void singlePositiveAndFormula() {
        Invoice__c value=invoice(100,'PL');
        // User-supplied tax values must be replaced by configured values.
        value.Tax__c=99; value.Tax_Amount__c=99;
        insert value;
        value=[SELECT Tax__c, Tax_Amount__c, Gross_Amount__c FROM Invoice__c WHERE Id=:value.Id];
        Assert.areEqual(23,value.Tax__c);
        Assert.areEqual(23,value.Tax_Amount__c);
        Assert.areEqual(123,value.Gross_Amount__c);
    }
    @IsTest static void singleNegativeMissingRate() { assertFailure(invoice(100,'FR'),'No tax rate'); }
    @IsTest static void singleNegativeMissingAmount() { assertFailure(invoice(null,'PL'),'net amount'); }
    @IsTest static void singleNegativeMissingCountry() { assertFailure(invoice(100,null),'country is required'); }
    @IsTest static void singleNegativeAmount() { assertFailure(invoice(-1,'PL'),'net amount'); }
    @IsTest static void duplicateRateIsRejected() {
        insert new Country_Tax_Rate__c(Country__c='PL',Tax__c=8);
        assertFailure(invoice(100,'PL'),'Multiple tax rates');
    }
    @IsTest static void bulkPositive200OneQuery() {
        List<Invoice__c> values=new List<Invoice__c>();
        for (Integer i=0;i<200;i++) values.add(invoice(100,Math.mod(i,2)==0?'PL':'DE'));
        Test.startTest();
        Integer beforeQueries=Limits.getQueries();
        insert values;
        Integer used=Limits.getQueries()-beforeQueries;
        Test.stopTest();
        Assert.areEqual(1,used,'The trigger must query rates once for the entire batch.');
        Set<Id> ids=new Map<Id,Invoice__c>(values).keySet();
        List<Invoice__c> saved=[SELECT Country__c, Tax__c, Tax_Amount__c FROM Invoice__c WHERE Id IN :ids];
        Assert.areEqual(200,saved.size());
        for (Invoice__c value:saved) {
            Decimal expected=value.Country__c == 'PL' ? 23 : 19;
            Assert.areEqual(expected,value.Tax__c);
            Assert.areEqual(expected,value.Tax_Amount__c);
        }
    }
    @IsTest static void bulkNegative200() {
        List<Invoice__c> values=new List<Invoice__c>();
        for(Integer i=0;i<200;i++) values.add(invoice(100,'FR'));
        Test.startTest();
        Database.SaveResult[] results=Database.insert(values,false);
        Test.stopTest();
        Assert.areEqual(200,results.size());
        for(Database.SaveResult result:results) {
            Assert.isFalse(result.isSuccess());
            Assert.isTrue(result.getErrors()[0].getMessage().contains('No tax rate'));
        }
    }
    @IsTest static void mixedBatchPartialSave() {
        List<Invoice__c> values=new List<Invoice__c>{invoice(100,'PL'),invoice(100,'FR'),invoice(null,'DE')};
        Database.SaveResult[] results=Database.insert(values,false);
        Assert.isTrue(results[0].isSuccess());
        Assert.isFalse(results[1].isSuccess());
        Assert.isFalse(results[2].isSuccess());
        Assert.areEqual(1,[SELECT count() FROM Invoice__c]);
    }
    @IsTest static void mixedBatchAllOrNoneRollback() {
        Boolean failed=false;
        try { insert new List<Invoice__c>{invoice(100,'PL'),invoice(100,'FR')}; }
        catch(DmlException ex) { failed=true; }
        Assert.isTrue(failed);
        Assert.areEqual(0,[SELECT count() FROM Invoice__c]);
    }
    @IsTest static void zeroAndHalfUp() {
        List<Invoice__c> values=new List<Invoice__c>{invoice(100,'IE'),invoice(0,'PL'),invoice(0.50,'PL')};
        insert values;
        Map<Id, Invoice__c> saved = new Map<Id, Invoice__c>([
            SELECT Tax_Amount__c FROM Invoice__c WHERE Id IN :new Map<Id, Invoice__c>(values).keySet()
        ]);
        Assert.areEqual(0,saved.get(values[0].Id).Tax_Amount__c);
        Assert.areEqual(0,saved.get(values[1].Id).Tax_Amount__c);
        Assert.areEqual(0.12,saved.get(values[2].Id).Tax_Amount__c);
    }
    @IsTest static void directServiceAndFindRates() {
        Invoice__c value=invoice(100,'DE');
        TaxCalculationService.calculateTax(value);
        Assert.areEqual(19,value.Tax_Amount__c);
        Assert.areEqual(1,TaxCalculationService.findTaxRates(new Set<String>{'DE'}).size());
        Assert.areEqual(0,TaxCalculationService.findTaxRates(null).size());
        Assert.areEqual(0,TaxCalculationService.findTaxRates(new Set<String>()).size());
        TaxCalculationService.calculateTaxes(null);
        TaxCalculationService.calculateTaxes(new List<Invoice__c>());
    }
    @IsTest static void nullServiceInputs() {
        Boolean first=false; Boolean second=false;
        try { TaxCalculationService.calculateTax(null); }
        catch(TaxCalculationService.TaxInputException ex) { first=true; }
        try { TaxCalculationService.calculateTaxes(new List<Invoice__c>{null}); }
        catch(TaxCalculationService.TaxInputException ex) { second=true; }
        Assert.isTrue(first); Assert.isTrue(second);
    }
    @IsTest static void invalidConfiguredRateValidation() {
        Database.SaveResult result=Database.insert(new Country_Tax_Rate__c(Country__c='FR',Tax__c=101),false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('between 0% and 100%'));
    }
    @IsTest static void completedServiceRequiresDetails() {
        Database.SaveResult result=Database.insert(new Service_Execution__c(Status__c='Completed'),false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('requires property'));
    }
    @IsTest static void lab1ModelAndRollup() {
        Account company=new Account(Name='Lab test provider'); insert company;
        Service__c service=new Service__c(Type__c='Cleaning',Price__c=100,Time_Required__c=2); insert service;
        Property__c property=new Property__c(Address__c='Test 1, Lublin',Owner__c=company.Id); insert property;
        Account_Service__c link=new Account_Service__c(Account_Id__c=company.Id,Service_Id__c=service.Id); insert link;
        Assert.areEqual(1,[SELECT Provider_Count__c FROM Service__c WHERE Id=:service.Id].Provider_Count__c);
        Invoice__c bill=invoice(100,'PL');bill.Service__c=service.Id;bill.Property__c=property.Id;bill.Account_Id__c=company.Id;insert bill;
        insert new Payment__c(Invoice_Id__c=bill.Id,Account_Id__c=company.Id,Date__c=Date.today(),Amount__c=123,Method__c='Transfer');
        insert new Service_Execution__c(Property__c=property.Id,Service__c=service.Id,Provider__c=company.Id,Invoice__c=bill.Id,Completed_At__c=Datetime.now(),Status__c='Completed');
        Assert.areEqual(company.Id,[SELECT Provider__c FROM Service_Execution__c LIMIT 1].Provider__c);
        delete link;
        Assert.areEqual(0,[SELECT Provider_Count__c FROM Service__c WHERE Id=:service.Id].Provider_Count__c);
    }
}
