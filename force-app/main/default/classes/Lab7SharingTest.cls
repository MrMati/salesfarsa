@IsTest
private class Lab7SharingTest {
    @TestSetup static void users() {
        Map<String,Id> roles=new Map<String,Id>();
        for(UserRole r:[SELECT Id,DeveloperName FROM UserRole WHERE DeveloperName LIKE 'Lab7_%']) roles.put(r.DeveloperName,r.Id);
        Map<String,Id> profiles=new Map<String,Id>();
        for(Profile p:[SELECT Id,Name FROM Profile WHERE Name LIKE 'Lab_%']) profiles.put(p.Name,p.Id);
        Map<String,PermissionSetGroup> groups=new Map<String,PermissionSetGroup>();
        for(PermissionSetGroup g:[SELECT Id,DeveloperName,Status FROM PermissionSetGroup WHERE DeveloperName LIKE 'Lab_%']) {
            if(g.Status!='Updated') Test.calculatePermissionSetGroup(g.Id);
            groups.put(g.DeveloperName,g);
        }
        List<User> people=new List<User>();
        List<String> names=new List<String>{'owner','peer','finance','analyst','manager','noaccess'};
        for(String name:names) {
            String actor=name=='finance'?'Accountant':name=='analyst'||name=='noaccess'?'Analyst':'Coordinator';
            String role=name=='manager'?'Manager':actor;
            people.add(new User(Alias=name.left(8),LastName='Lab7 '+name,Email='lab7-'+name+'@example.invalid',
                Username='lab7-'+name+'-'+UserInfo.getOrganizationId()+'@example.invalid',
                ProfileId=profiles.get('Lab_'+actor),UserRoleId=roles.get('Lab7_'+role),
                TimeZoneSidKey='Europe/Warsaw',LocaleSidKey='pl_PL',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US'));
        }
        insert people;
        List<PermissionSetAssignment> grants=new List<PermissionSetAssignment>();
        for(User u:people) {
            String name=u.LastName.substringAfter('Lab7 ');
            if(name=='noaccess') continue;
            String groupName='Lab_'+(name=='finance'?'Accountant':name=='analyst'?'Analyst':'Coordinator');
            grants.add(new PermissionSetAssignment(AssigneeId=u.Id,PermissionSetGroupId=groups.get(groupName).Id));
        }
        insert grants;
    }
    private static User person(String name) {
        return [SELECT Id,UserRoleId FROM User WHERE LastName=:('Lab7 '+name)];
    }
    private static void rates() {insert new Country_Tax_Rate__c(Country__c='PL',Tax__c=23);}
    private static Invoice__c invoice(Id owner,Id recipient) {
        return new Invoice__c(OwnerId=owner,Amount__c=100,Country__c='PL',Status__c='To_Pay',Shared_With__c=recipient);
    }
    private static Integer visibleInvoice(Id userId,Id invoiceId) {
        Integer visible;
        System.runAs(new User(Id=userId)) {visible=[SELECT COUNT() FROM Invoice__c WHERE Id=:invoiceId WITH USER_MODE];}
        return visible;
    }
    private static Integer visibleProperty(Id userId,Id propertyId) {
        Integer visible;
        System.runAs(new User(Id=userId)) {visible=[SELECT COUNT() FROM Property__c WHERE Id=:propertyId WITH USER_MODE];}
        return visible;
    }
    @IsTest static void privateInvoicesAndHierarchy() {
        rates();Invoice__c bill=invoice(person('owner').Id,null);insert bill;
        Assert.areEqual(1,visibleInvoice(person('owner').Id,bill.Id));
        Assert.areEqual(0,visibleInvoice(person('peer').Id,bill.Id),'A role does not automatically share between peers.');
        Assert.areEqual(0,visibleInvoice(person('finance').Id,bill.Id));
        Assert.areEqual(1,visibleInvoice(person('manager').Id,bill.Id),'Manager inherits access up the hierarchy.');
    }
    @IsTest static void sameRolePropertyRuleAndRoleChange() {
        User peer=person('peer');
        Property__c place=new Property__c(Address__c='Lab7 nieruchomość',OwnerId=person('owner').Id);insert place;
        Assert.areEqual(1,visibleProperty(peer.Id,place.Id),'Configured owner-based rule shares Property within a role.');
        Assert.areEqual(0,visibleProperty(person('finance').Id,place.Id));
        Assert.areEqual(1,visibleProperty(person('manager').Id,place.Id));
        System.runAs(new User(Id=UserInfo.getUserId())) {
            peer.UserRoleId=person('finance').UserRoleId;update peer;
        }
        Assert.areEqual(0,visibleProperty(peer.Id,place.Id),'Leaving the role removes this sharing-rule path.');
    }
    @IsTest static void selectedUserGetsReadButCannotEdit() {
        rates();User owner=person('owner');User peer=person('peer');
        Invoice__c bill=invoice(owner.Id,peer.Id);insert bill;
        Assert.areEqual(1,visibleInvoice(peer.Id,bill.Id));
        System.runAs(peer) {
            Assert.isTrue(Invoice__c.SObjectType.getDescribe().isUpdateable());
            Boolean denied=false;
            try {Database.update(new Invoice__c(Id=bill.Id,Amount__c=999),AccessLevel.USER_MODE);}
            catch(Exception ex) {denied=true;}
            Assert.isTrue(denied,'Object Edit does not turn a Read share into row Edit.');
        }
        Assert.areEqual('Read',[SELECT AccessLevel FROM Invoice__Share WHERE ParentId=:bill.Id AND RowCause='Selected_User__c'].AccessLevel);
    }
    @IsTest static void changingAndClearingRecipientRevokesOnlyManagedShare() {
        rates();User owner=person('owner');User peer=person('peer');User finance=person('finance');User analyst=person('analyst');
        Invoice__c bill=invoice(owner.Id,peer.Id);insert bill;
        insert new Invoice__Share(ParentId=bill.Id,UserOrGroupId=analyst.Id,AccessLevel='Read',RowCause='Manual');
        System.runAs(owner) {
            Database.update(new Invoice__c(Id=bill.Id,Shared_With__c=finance.Id),AccessLevel.USER_MODE);
        }
        Assert.areEqual(0,visibleInvoice(peer.Id,bill.Id));Assert.areEqual(1,visibleInvoice(finance.Id,bill.Id));
        Assert.areEqual(1,visibleInvoice(analyst.Id,bill.Id));
        System.runAs(owner) {Database.update(new Invoice__c(Id=bill.Id,Shared_With__c=null),AccessLevel.USER_MODE);}
        Assert.areEqual(0,visibleInvoice(finance.Id,bill.Id));
        Assert.areEqual(1,visibleInvoice(analyst.Id,bill.Id),'Independent manual share must remain.');
        Assert.areEqual(0,[SELECT COUNT() FROM Invoice__Share WHERE ParentId=:bill.Id AND RowCause='Selected_User__c']);
    }
    @IsTest static void customReasonSurvivesOwnerChangeAndRestore() {
        rates();Invoice__c bill=invoice(person('owner').Id,person('analyst').Id);insert bill;
        bill.OwnerId=person('peer').Id;update bill;
        Assert.areEqual(1,visibleInvoice(person('analyst').Id,bill.Id));
        delete bill;undelete bill;
        Assert.areEqual(1,visibleInvoice(person('analyst').Id,bill.Id));
        Assert.areEqual(1,[SELECT COUNT() FROM Invoice__Share WHERE ParentId=:bill.Id AND RowCause='Selected_User__c']);
    }
    @IsTest static void ownerRecipientNeedsNoRedundantShare() {
        rates();User owner=person('owner');Invoice__c bill=invoice(owner.Id,owner.Id);insert bill;
        Assert.areEqual(0,[SELECT COUNT() FROM Invoice__Share WHERE ParentId=:bill.Id AND RowCause='Selected_User__c']);
        bill.OwnerId=person('peer').Id;update bill;
        Assert.areEqual(1,visibleInvoice(owner.Id,bill.Id));
        Assert.areEqual(1,[SELECT COUNT() FROM Invoice__Share WHERE ParentId=:bill.Id AND RowCause='Selected_User__c']);
    }
    @IsTest static void shareCannotGrantMissingObjectPermission() {
        rates();User noaccess=person('noaccess');Invoice__c bill=invoice(person('owner').Id,noaccess.Id);insert bill;
        System.runAs(noaccess) {
            Assert.isFalse(Invoice__c.SObjectType.getDescribe().isAccessible());
            Boolean denied=false;
            try {List<Invoice__c> rows=[SELECT Id FROM Invoice__c WHERE Id=:bill.Id WITH USER_MODE];}
            catch(QueryException ex) {denied=true;}
            Assert.isTrue(denied);
        }
    }
    @IsTest static void bulk200SharesAreReplacedAndRemoved() {
        rates();Id owner=person('owner').Id;Id peer=person('peer').Id;Id finance=person('finance').Id;
        List<Invoice__c> bills=new List<Invoice__c>();
        for(Integer i=0;i<200;i++) bills.add(invoice(owner,peer));
        Test.startTest();insert bills;
        Set<Id> ids=new Map<Id,Invoice__c>(bills).keySet();
        Assert.areEqual(200,[SELECT COUNT() FROM Invoice__Share WHERE ParentId IN :ids AND UserOrGroupId=:peer AND RowCause='Selected_User__c']);
        for(Invoice__c bill:bills) bill.Shared_With__c=finance;update bills;
        Assert.areEqual(0,[SELECT COUNT() FROM Invoice__Share WHERE ParentId IN :ids AND UserOrGroupId=:peer AND RowCause='Selected_User__c']);
        Assert.areEqual(200,[SELECT COUNT() FROM Invoice__Share WHERE ParentId IN :ids AND UserOrGroupId=:finance AND RowCause='Selected_User__c']);
        for(Invoice__c bill:bills) bill.Shared_With__c=null;update bills;Test.stopTest();
        Assert.areEqual(0,[SELECT COUNT() FROM Invoice__Share WHERE ParentId IN :ids AND RowCause='Selected_User__c']);
    }
    @IsTest static void hiddenReservationStillBlocksProvider() {
        rates();User owner=person('owner');User peer=person('peer');
        Account firm=new Account(Name='Lab7 Firma',OwnerId=peer.Id,Status__c='Active',Is_Provider__c=true);insert firm;
        Service__c service=new Service__c(OwnerId=peer.Id,Title__c='Lab7 Usługa',Is_Active__c=true,Time_Required__c=1);insert service;
        insert new Account_Service__c(Account_Id__c=firm.Id,Service_Id__c=service.Id,Is_Active__c=true);
        Datetime startAt=Datetime.newInstanceGmt(2031,1,1,8,0,0);
        Invoice__c busy=invoice(owner.Id,null);busy.Provider__c=firm.Id;busy.Service__c=service.Id;busy.Start__c=startAt;busy.End__c=startAt.addHours(2);insert busy;
        Assert.areEqual(0,visibleInvoice(peer.Id,busy.Id));
        System.runAs(peer) {
            Assert.areEqual(0,InvoiceLabController.getAvailableProviders(service.Id,startAt,startAt.addHours(1)).size(),'Availability must account for private bookings.');
            Invoice__c conflict=invoice(peer.Id,null);conflict.Provider__c=firm.Id;conflict.Service__c=service.Id;conflict.Start__c=startAt;conflict.End__c=startAt.addHours(1);
            Database.SaveResult rejected=Database.insert(conflict,false,AccessLevel.USER_MODE);
            Assert.isFalse(rejected.isSuccess());
            Assert.isTrue(rejected.getErrors()[0].getMessage().contains('unavailable'),rejected.getErrors()[0].getMessage());
            Assert.areEqual(1,InvoiceLabController.getAvailableProviders(service.Id,startAt.addHours(2),startAt.addHours(3)).size());
        }
    }
    @IsTest static void costAggregateRequiresVisibleInvoiceAsWellAsExecution() {
        rates();User owner=person('owner');User analyst=person('analyst');
        Account firm=new Account(OwnerId=analyst.Id,Name='Koszt prywatny');insert firm;
        Service__c service=new Service__c(OwnerId=analyst.Id,Title__c='Koszt prywatny');insert service;
        Property__c place=new Property__c(OwnerId=analyst.Id,Address__c='Koszt prywatny');insert place;
        Invoice__c bill=invoice(owner.Id,null);insert bill;
        insert new Service_Execution__c(OwnerId=analyst.Id,Property__c=place.Id,Provider__c=firm.Id,
            Service__c=service.Id,Invoice__c=bill.Id,Status__c='Completed',Completed_At__c=System.now());
        System.runAs(analyst) {
            Assert.areEqual(0,ServiceCostController.getCosts(null,null).rows.size(),'A visible execution must not reveal an unshared invoice amount.');
        }
        bill.Shared_With__c=analyst.Id;update bill;
        System.runAs(analyst) {Assert.areEqual(123,ServiceCostController.getCosts(null,null).rows[0].averageGross);}
    }
    @IsTest static void inactiveRecipientIsRejected() {
        User peer=person('peer');
        System.runAs(new User(Id=UserInfo.getUserId())) {peer.IsActive=false;update peer;}
        rates();
        Database.SaveResult result=Database.insert(invoice(person('owner').Id,peer.Id),false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('aktywnego'),result.getErrors()[0].getMessage());
    }
    @IsTest static void globalPaidRollupIsHiddenFromLimitedActors() {
        rates();User analyst=person('analyst');
        Property__c place=new Property__c(OwnerId=analyst.Id,Address__c='Prywatna suma globalna');insert place;
        Invoice__c bill=invoice(person('owner').Id,null);bill.Status__c='Paid';bill.Property__c=place.Id;insert bill;
        Assert.areEqual(123,[SELECT Total_Cost__c FROM Property__c WHERE Id=:place.Id].Total_Cost__c);
        for(String actor:new List<String>{'owner','finance','analyst'}) {
            System.runAs(person(actor)) {Assert.isFalse(Property__c.Total_Cost__c.getDescribe().isAccessible(),'A stored global total cannot be filtered per viewer.');}
        }
        System.runAs(analyst) {
            Boolean denied=false;
            try {List<Property__c> rows=[SELECT Total_Cost__c FROM Property__c WHERE Id=:place.Id WITH USER_MODE];}
            catch(QueryException ex) {denied=true;}
            Assert.isTrue(denied);
            Assert.areEqual(0,[SELECT COUNT() FROM Invoice__c WHERE Property__c=:place.Id WITH USER_MODE]);
        }
        bill.Shared_With__c=analyst.Id;update bill;
        System.runAs(analyst) {Assert.areEqual(123,[SELECT Gross_Amount__c FROM Invoice__c WHERE Id=:bill.Id WITH USER_MODE].Gross_Amount__c);}
    }
}
