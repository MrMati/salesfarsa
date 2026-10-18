trigger InvoiceTrigger on Invoice__c (before insert, before update, after insert, after update, after undelete) {
    if (Trigger.isBefore) {
        List<Invoice__c> recalculate=new List<Invoice__c>();
        for(Invoice__c invoice:Trigger.new) {
            if(Trigger.isInsert || invoice.Amount__c!=Trigger.oldMap.get(invoice.Id).Amount__c || invoice.Country__c!=Trigger.oldMap.get(invoice.Id).Country__c) recalculate.add(invoice);
            else {invoice.Tax__c=Trigger.oldMap.get(invoice.Id).Tax__c;invoice.Tax_Amount__c=Trigger.oldMap.get(invoice.Id).Tax_Amount__c;}
        }
        TaxCalculationService.calculateTaxes(recalculate);
        BookingGuard.validate(Trigger.new,Trigger.isUpdate?Trigger.oldMap:null);
    } else {
        if (Trigger.isUndelete) {
            BookingGuard.validate(Trigger.new, null);
            List<PropertyCostAction.Input> inputs = new List<PropertyCostAction.Input>();
            for (Invoice__c invoice : Trigger.new) {
                if (invoice.hasErrors()) continue;
                PropertyCostAction.Input input = new PropertyCostAction.Input();
                input.propertyId = invoice.Property__c;
                inputs.add(input);
            }
            PropertyCostAction.recalculate(inputs);
        }
        InvoiceSharingService.synchronize(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
    }
}
