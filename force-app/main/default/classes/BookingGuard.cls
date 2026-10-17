/** Revalidate the UI choice under provider locks; reject stale choices and overlaps in one DML batch. */
public with sharing class BookingGuard {
    public static void validate(List<Invoice__c> values,Map<Id,Invoice__c> oldValues) {
        List<Invoice__c> checked=new List<Invoice__c>();List<BookingEligibility.Request> requests=new List<BookingEligibility.Request>();
        Set<Id> providers=new Set<Id>();Set<Id> excluded=new Set<Id>();
        for(Invoice__c value:values) {
            if(value.Status__c=='Cancelled' || value.Provider__c==null || value.Service__c==null || value.Start__c==null || value.End__c==null || value.End__c<=value.Start__c) continue;
            Invoice__c old=oldValues==null?null:oldValues.get(value.Id);
            if(old!=null && old.Provider__c==value.Provider__c && old.Service__c==value.Service__c && old.Start__c==value.Start__c && old.End__c==value.End__c && old.Status__c==value.Status__c) continue;
            checked.add(value);providers.add(value.Provider__c);if(value.Id!=null) excluded.add(value.Id);
            requests.add(new BookingEligibility.Request(value.Service__c,value.Start__c,value.End__c));
        }
        if(checked.isEmpty()) return;
        // Serialize competing reservations for the same provider. Trigger automation owns this lock.
        List<Account> locked=[SELECT Id FROM Account WHERE Id IN :providers FOR UPDATE];
        List<List<BookingEligibility.ProviderOption>> options=BookingEligibility.findProviders(requests,excluded);
        for(Integer i=0;i<checked.size();i++) {
            Boolean allowed=false;
            for(BookingEligibility.ProviderOption option:options[i]) if(option.value==checked[i].Provider__c) allowed=true;
            if(!allowed) {checked[i].addError('Selected provider is unavailable or lacks required skills.');continue;}
            for(Integer j=0;j<i;j++) {
                if(!checked[j].hasErrors() && checked[j].Provider__c==checked[i].Provider__c && checked[j].Start__c<checked[i].End__c && checked[j].End__c>checked[i].Start__c) {
                    checked[i].addError('Overlapping reservations for the same provider in this batch.');break;
                }
            }
        }
    }
}
