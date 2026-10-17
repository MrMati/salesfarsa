@IsTest
private class ServiceCostControllerTest {
    @TestSetup static void data() {
        insert new Country_Tax_Rate__c(Country__c='PL',Tax__c=23);
        Account firm=new Account(Name='Firma kosztowa');insert firm;
        Property__c property=new Property__c(Address__c='Budynek kosztowy');insert property;
        Service__c service=new Service__c(Title__c='Mycie',Price__c=100,Time_Required__c=1);insert service;
        List<Invoice__c> invoices=new List<Invoice__c>();
        for(Integer i=0;i<4;i++) invoices.add(new Invoice__c(Amount__c=(i+1)*100,Country__c='PL',Property__c=property.Id,Service__c=service.Id,Provider__c=firm.Id,Status__c=i==3?'Cancelled':'Paid'));
        insert invoices;
        List<Service_Execution__c> executions=new List<Service_Execution__c>();
        for(Integer i=0;i<4;i++) executions.add(new Service_Execution__c(Property__c=property.Id,Provider__c=firm.Id,Service__c=service.Id,Invoice__c=invoices[i].Id,Status__c=i==2?'Planned':'Completed',Completed_At__c=System.now()));
        insert executions;
        insert new Service_Execution__c(Property__c=property.Id,Provider__c=firm.Id,Service__c=service.Id,Status__c='Completed',Completed_At__c=System.now());
    }
    @IsTest static void averagesOnlyCompletedBilledExecutions() {
        ServiceCostController.CostResult result=ServiceCostController.getCosts(null,null);
        Assert.areEqual(1,result.rows.size());
        Assert.areEqual(2,result.rows[0].executions);
        Assert.areEqual(184.50,result.rows[0].averageGross,'(123 + 246) / 2; planned, cancelled and unbilled excluded.');
        Assert.isFalse(result.truncated);
        Assert.areEqual(UserInfo.getDefaultCurrency(),result.currencyCode);
        Assert.areEqual('Mycie',result.rows[0].serviceName);
    }
    @IsTest static void filtersBothDimensionsWithoutLeakingOtherGroups() {
        Account firm=[SELECT Id FROM Account LIMIT 1];Property__c place=[SELECT Id FROM Property__c LIMIT 1];
        Assert.areEqual(1,ServiceCostController.getCosts(place.Id,firm.Id).rows.size());
        Account other=new Account(Name='Inna firma');insert other;
        Assert.areEqual(0,ServiceCostController.getCosts(place.Id,other.Id).rows.size());
        Property__c otherPlace=new Property__c(Address__c='Inny budynek');insert otherPlace;
        Assert.areEqual(0,ServiceCostController.getCosts(otherPlace.Id,firm.Id).rows.size());
        Service__c service=[SELECT Id,Name,Title__c FROM Service__c LIMIT 1];
        service.Title__c=null;update service;
        Assert.areEqual(service.Name,ServiceCostController.getCosts(place.Id,firm.Id).rows[0].serviceName);
    }
    @IsTest static void reportsTruncationInsteadOfHidingLimit() {
        Account firm=[SELECT Id FROM Account LIMIT 1];Service__c service=[SELECT Id FROM Service__c LIMIT 1];Invoice__c invoice=[SELECT Id FROM Invoice__c WHERE Status__c='Paid' LIMIT 1];
        List<Property__c> properties=new List<Property__c>();
        for(Integer i=0;i<201;i++) properties.add(new Property__c(Address__c='Grupa '+i));
        insert properties;
        List<Service_Execution__c> executions=new List<Service_Execution__c>();
        for(Property__c place:properties) executions.add(new Service_Execution__c(Property__c=place.Id,Provider__c=firm.Id,Service__c=service.Id,Invoice__c=invoice.Id,Status__c='Completed',Completed_At__c=System.now()));
        insert executions;
        Test.startTest();ServiceCostController.CostResult result=ServiceCostController.getCosts(null,null);Test.stopTest();
        Assert.areEqual(200,result.rows.size());Assert.isTrue(result.truncated);
    }
}
