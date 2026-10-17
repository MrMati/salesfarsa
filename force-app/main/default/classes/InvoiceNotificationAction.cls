/** Platform Event subscriber. Recipient/opt-in are re-read from the invoice, never trusted from event input. */
public without sharing class InvoiceNotificationAction {
    public class Input {
        @InvocableVariable(required=true) public String invoiceId;
        @InvocableVariable(required=true) public String eventKey;
        @InvocableVariable public String summary;
    }
    @InvocableMethod(label='Powiadom właściciela faktury i zapisz ślad zdarzenia')
    public static void notifyOwners(List<Input> inputs) {
        Set<Id> ids=new Set<Id>();Set<String> keys=new Set<String>();
        for(Input input:inputs) {
            if(String.isBlank(input.eventKey) || String.isBlank(input.invoiceId)) continue;
            try {ids.add(Id.valueOf(input.invoiceId));keys.add(input.eventKey);}catch(Exception ex) {continue;}
        }
        if(ids.isEmpty()) return;
        Set<String> existing=new Set<String>();
        for(Invoice_Notification__c row:[SELECT Event_Key__c FROM Invoice_Notification__c WHERE Event_Key__c IN :keys WITH SYSTEM_MODE]) existing.add(row.Event_Key__c);
        Map<Id,Invoice__c> invoices=new Map<Id,Invoice__c>([SELECT Id,Name,OwnerId,Notify_Owner__c FROM Invoice__c WHERE Id IN :ids WITH SYSTEM_MODE]);
        Set<Id> owners=new Set<Id>();for(Invoice__c invoice:invoices.values()) owners.add(invoice.OwnerId);
        Map<Id,User> users=new Map<Id,User>([SELECT Id,Email,IsActive FROM User WHERE Id IN :owners WITH SYSTEM_MODE]);
        List<Invoice_Notification__c> logs=new List<Invoice_Notification__c>();
        List<Messaging.SingleEmailMessage> messages=new List<Messaging.SingleEmailMessage>();List<Integer> messageLogIndexes=new List<Integer>();
        for(Input input:inputs) {
            if(String.isBlank(input.eventKey) || existing.contains(input.eventKey)) continue;
            Id invoiceId;try {invoiceId=Id.valueOf(input.invoiceId);}catch(Exception ex) {continue;}
            Invoice__c invoice=invoices.get(invoiceId);if(invoice==null) continue;
            existing.add(input.eventKey);User owner=users.get(invoice.OwnerId);
            Invoice_Notification__c log=new Invoice_Notification__c(Invoice__c=invoice.Id,Event_Key__c=input.eventKey,Summary__c=input.summary,Result__c='EmailDisabled');
            if(owner!=null) log.Recipient__c=owner.Email;
            if(invoice.Notify_Owner__c && owner!=null && owner.IsActive && !String.isBlank(owner.Email)) {
                Messaging.SingleEmailMessage message=new Messaging.SingleEmailMessage();message.setTargetObjectId(owner.Id);message.setSaveAsActivity(false);
                message.setSubject('Zmiana faktury '+invoice.Name);
                message.setPlainTextBody('Zmieniono fakturę '+invoice.Name+'.\n'+(input.summary==null?'':input.summary)+'\nOtwórz aplikację Usługi nieruchomości — Lab.');
                messageLogIndexes.add(logs.size());messages.add(message);log.Result__c='EmailRequested';
            }
            logs.add(log);
        }
        if(!messages.isEmpty()) {
            Messaging.SendEmailResult[] results=Messaging.sendEmail(messages,false);
            for(Integer i=0;i<results.size();i++) logs[messageLogIndexes[i]].Result__c=results[i].isSuccess()?'EmailSent':'EmailError';
        }
        if(!logs.isEmpty()) Database.insert(logs,AccessLevel.SYSTEM_MODE);
    }
}
