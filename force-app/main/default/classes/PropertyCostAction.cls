/** System automation: the stored total must include all paid invoices, regardless of caller sharing. */
public without sharing class PropertyCostAction {
    public class Input {
        @InvocableVariable public Id propertyId;
        @InvocableVariable public Id previousPropertyId;
        @InvocableVariable public Id excludingInvoiceId;
    }
    @InvocableMethod(label='Przelicz sumę opłaconych faktur nieruchomości')
    public static void recalculate(List<Input> inputs) {
        Set<Id> properties=new Set<Id>();Set<Id> excluded=new Set<Id>();
        for(Input input:inputs) {
            if(input.propertyId!=null) properties.add(input.propertyId);
            if(input.previousPropertyId!=null) properties.add(input.previousPropertyId);
            if(input.excludingInvoiceId!=null) excluded.add(input.excludingInvoiceId);
        }
        if(properties.isEmpty()) return;
        List<Property__c> records=[SELECT Id,Total_Cost__c FROM Property__c WHERE Id IN :properties FOR UPDATE];
        Map<Id,Decimal> sums=new Map<Id,Decimal>();
        for(AggregateResult row:[SELECT Property__c propertyId,SUM(Gross_Amount__c) total FROM Invoice__c
            WHERE Property__c IN :properties AND Status__c='Paid' AND Id NOT IN :excluded WITH SYSTEM_MODE GROUP BY Property__c]) {
            sums.put((Id)row.get('propertyId'),(Decimal)row.get('total'));
        }
        List<Property__c> changed=new List<Property__c>();
        for(Property__c record:records) {
            Decimal total=sums.containsKey(record.Id)?sums.get(record.Id):0;
            if(record.Total_Cost__c!=total) {record.Total_Cost__c=total;changed.add(record);}
        }
        if(!changed.isEmpty()) Database.update(changed,AccessLevel.SYSTEM_MODE);
    }
}
