@IsTest
private class Lab56SecurityTest {
    @TestSetup static void actors() {
        List<PermissionSetGroup> groups = [SELECT Id, DeveloperName, Status FROM PermissionSetGroup WHERE DeveloperName IN ('Lab_Coordinator','Lab_Accountant','Lab_Analyst')];
        Assert.areEqual(3, groups.size());
        for (PermissionSetGroup groupRow : groups) {
            if (groupRow.Status != 'Updated') Test.calculatePermissionSetGroup(groupRow.Id);
        }
        Map<String, Id> profiles = new Map<String, Id>();
        for (Profile p : [SELECT Id, Name FROM Profile WHERE Name LIKE 'Lab_%']) profiles.put(p.Name, p.Id);
        List<User> users = new List<User>();
        for (String actor : new List<String>{'Coordinator','Accountant','Analyst'}) {
            users.add(new User(Alias=actor.left(8), LastName='Lab56 '+actor,
                Email='lab56-'+actor.toLowerCase()+'@example.invalid',
                Username='lab56-'+actor.toLowerCase()+'-'+UserInfo.getOrganizationId()+'@example.invalid',
                ProfileId=profiles.get('Lab_'+actor), TimeZoneSidKey='Europe/Warsaw',
                LocaleSidKey='pl_PL', EmailEncodingKey='UTF-8', LanguageLocaleKey='en_US'));
        }
        insert users;
        List<PermissionSetAssignment> grants = new List<PermissionSetAssignment>();
        for (User u : users) for (PermissionSetGroup groupRow : groups) {
            if ('Lab_'+u.LastName.substringAfter('Lab56 ') == groupRow.DeveloperName) {
                grants.add(new PermissionSetAssignment(AssigneeId=u.Id, PermissionSetGroupId=groupRow.Id));
            }
        }
        insert grants;
    }
    private static User actor(String actor) {
        return [SELECT Id FROM User WHERE LastName = :('Lab56 '+actor) LIMIT 1];
    }
    private static void sampleExecution() {
        insert new Country_Tax_Rate__c(Country__c='PL',Tax__c=23);
        Account firm=new Account(Name='Firma bezpieczeństwa');insert firm;
        Service__c service=new Service__c(Title__c='Usługa testowa',Price__c=100,Time_Required__c=1);insert service;
        Property__c place=new Property__c(Address__c='Budynek testowy',Access_Notes__c='Poufne');insert place;
        Invoice__c invoice=new Invoice__c(Amount__c=100,Country__c='PL',Property__c=place.Id,Service__c=service.Id,Provider__c=firm.Id,Status__c='Paid');insert invoice;
        insert new Service_Execution__c(Property__c=place.Id,Service__c=service.Id,Provider__c=firm.Id,Invoice__c=invoice.Id,Status__c='Completed',Completed_At__c=System.now());
    }
    @IsTest static void coordinatorCanOrderButCannotReadPaymentsOrBilling() {
        sampleExecution();
        System.runAs(actor('Coordinator')) {
            Assert.isTrue(Invoice__c.SObjectType.getDescribe().isCreateable());
            Assert.areEqual(123,ServiceCostController.getCosts(null,null).rows[0].averageGross);
            Assert.isTrue(Property__c.Access_Notes__c.getDescribe().isAccessible());
            Assert.isFalse(Payment__c.SObjectType.getDescribe().isAccessible());
            Assert.isFalse(Account.Billing_Email__c.getDescribe().isAccessible());
            Assert.isFalse(Invoice__c.Tax__c.getDescribe().isUpdateable());
            Database.insert(new Property__c(Address__c='Uprawniony koordynator',Access_Notes__c='Dane operacyjne'),AccessLevel.USER_MODE);
            Boolean denied=false;
            try { List<SObject> ignored=Database.query('SELECT Amount__c FROM Payment__c WITH USER_MODE'); }
            catch (QueryException ex) { denied=true; }
            Assert.isTrue(denied,'Brak obiektu musi zablokować zapytanie.');
        }
    }
    @IsTest static void accountantCanRecordPaymentButCannotReadAccessInstructions() {
        sampleExecution();
        System.runAs(actor('Accountant')) {
            Assert.isTrue(Payment__c.SObjectType.getDescribe().isCreateable());
            Assert.areEqual(123,ServiceCostController.getCosts(null,null).rows[0].averageGross);
            Assert.isTrue(Account.Billing_Email__c.getDescribe().isAccessible());
            Assert.isFalse(Property__c.Access_Notes__c.getDescribe().isAccessible());
            Assert.isFalse(Service_Execution__c.SObjectType.getDescribe().isUpdateable());
            Database.insert(new Payment__c(Amount__c=123,Date__c=Date.today(),Method__c='Transfer'),AccessLevel.USER_MODE);
            Boolean denied=false;
            try { List<SObject> ignored=Database.query('SELECT Access_Notes__c FROM Property__c WITH USER_MODE'); }
            catch (QueryException ex) { denied=true; }
            Assert.isTrue(denied,'FLS musi być sprawdzane przez USER_MODE.');
        }
    }
    @IsTest static void analystCanReadCostsButCannotWriteOrReadPrivateFields() {
        sampleExecution();
        System.runAs(actor('Analyst')) {
            Assert.isTrue(Service_Execution__c.SObjectType.getDescribe().isAccessible());
            Assert.isFalse(Invoice__c.SObjectType.getDescribe().isCreateable());
            Assert.isFalse(Invoice__c.SObjectType.getDescribe().isUpdateable());
            Assert.isFalse(Payment__c.SObjectType.getDescribe().isAccessible());
            Assert.isFalse(Invoice__c.Contact_Email__c.getDescribe().isAccessible());
            Assert.isFalse(Property__c.Access_Notes__c.getDescribe().isAccessible());
            Assert.areEqual(123,ServiceCostController.getCosts(null,null).rows[0].averageGross);
            Boolean denied=false;
            try { Database.insert(new Property__c(Address__c='Niedozwolony zapis'),AccessLevel.USER_MODE); }
            catch (Exception ex) { denied=true; }
            Assert.isTrue(denied);
        }
    }
    @IsTest static void actorWithoutGroupHasNoBusinessAccess() {
        User u=actor('Analyst');
        delete [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId=:u.Id AND PermissionSetGroupId != null];
        System.runAs(u) {
            Assert.isFalse(Invoice__c.SObjectType.getDescribe().isAccessible());
            Boolean denied=false;
            try { ServiceCostController.getCosts(null,null); }
            catch (AuraHandledException ex) { denied=true; }
            Assert.isTrue(denied,'Kontroler nie może ominąć CRUD/FLS.');
        }
    }
}
