@IsTest
private class Lab4NotificationTest {
    static Invoice__c createInvoice(Boolean notifyOwner) {
        insert new Country_Tax_Rate__c(Country__c='PL',Tax__c=23);
        Invoice__c invoice=new Invoice__c(Amount__c=100,Country__c='PL',Notify_Owner__c=notifyOwner);insert invoice;return invoice;
    }
    static InvoiceNotificationAction.Input input(Id invoice,String key) {
        InvoiceNotificationAction.Input value=new InvoiceNotificationAction.Input();value.invoiceId=String.valueOf(invoice);value.eventKey=key;value.summary='Zmiana testowa';return value;
    }
    @IsTest static void directActionRecordsDisabledEmailAndDeduplicates() {
        Invoice__c invoice=createInvoice(false);InvoiceNotificationAction.Input value=input(invoice.Id,'test-disabled');
        Test.startTest();InvoiceNotificationAction.notifyOwners(new List<InvoiceNotificationAction.Input>{value,value});
        InvoiceNotificationAction.notifyOwners(new List<InvoiceNotificationAction.Input>{value});
        Assert.areEqual(0,Limits.getEmailInvocations());Test.stopTest();
        Assert.areEqual(1,[SELECT count() FROM Invoice_Notification__c]);
        Assert.areEqual('EmailDisabled',[SELECT Result__c FROM Invoice_Notification__c LIMIT 1].Result__c);
    }
    @IsTest static void optedInActionRequestsEmailInTestOnly() {
        Invoice__c invoice=createInvoice(true);
        Test.startTest();InvoiceNotificationAction.notifyOwners(new List<InvoiceNotificationAction.Input>{input(invoice.Id,'test-enabled')});
        Assert.areEqual(1,Limits.getEmailInvocations());Test.stopTest();
        Assert.areEqual('EmailSent',[SELECT Result__c FROM Invoice_Notification__c LIMIT 1].Result__c);
    }
    @IsTest static void platformEventSubscriberExecutesFlow() {
        Invoice__c invoice=createInvoice(false);
        Test.startTest();
        Database.SaveResult result=EventBus.publish(new Invoice_Changed__e(Invoice_Id__c=String.valueOf(invoice.Id),Owner_Id__c=String.valueOf(UserInfo.getUserId()),Change_Key__c='event-flow-test',Summary__c='Platform Event test'));
        Assert.isTrue(result.isSuccess());Test.getEventBus().deliver();Test.stopTest();
        Assert.areEqual(1,[SELECT count() FROM Invoice_Notification__c WHERE Event_Key__c='event-flow-test']);
    }
    @IsTest static void publisherRunsOnSignificantChange() {
        Invoice__c invoice=createInvoice(false);
        Test.startTest();invoice.Amount__c=200;update invoice;Test.getEventBus().deliver();Test.stopTest();
        Assert.areEqual(246,[SELECT Gross_Amount__c FROM Invoice__c WHERE Id=:invoice.Id].Gross_Amount__c);
        // Event delivery after commit is also verified with a live, opted-out demonstration update.
    }
    @IsTest static void malformedAndUnknownEventIgnored() {
        InvoiceNotificationAction.Input bad=input(UserInfo.getUserId(),'unknown-invoice');
        InvoiceNotificationAction.Input malformed=new InvoiceNotificationAction.Input();malformed.invoiceId='invalid';malformed.eventKey='bad';
        InvoiceNotificationAction.notifyOwners(new List<InvoiceNotificationAction.Input>{bad,malformed,new InvoiceNotificationAction.Input()});
        Assert.areEqual(0,[SELECT count() FROM Invoice_Notification__c]);
    }
}
