/** Labs 3.6/4.2. One provider performs one service at a time. Intervals are [start,end).
 * Candidate must offer the service and possess ALL required skills. No SOQL in loops.
 */
public without sharing class BookingEligibility {
    public class Request {
        public Id serviceId; public Datetime startAt; public Datetime endAt;
        public Request(Id serviceId, Datetime startAt, Datetime endAt) {
            this.serviceId=serviceId; this.startAt=startAt; this.endAt=endAt;
        }
    }
    public class ProviderOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
        public ProviderOption(Id value,String label) { this.value=value; this.label=label; }
    }
    public static List<List<ProviderOption>> findProviders(List<Request> requests, Set<Id> excludedInvoices) {
        return findProviders(requests, excludedInvoices, AccessLevel.USER_MODE);
    }
    // Internal trigger validation only. Never exposed as an Aura/LWC endpoint.
    public static List<List<ProviderOption>> findProvidersForValidation(List<Request> requests, Set<Id> excludedInvoices) {
        return findProviders(requests, excludedInvoices, AccessLevel.SYSTEM_MODE);
    }
    private static List<List<ProviderOption>> findProviders(List<Request> requests, Set<Id> excludedInvoices, AccessLevel mode) {
        List<List<ProviderOption>> results=new List<List<ProviderOption>>();
        if(requests==null || requests.isEmpty()) return results;
        Set<Id> services=new Set<Id>(); Datetime firstStart;Datetime lastEnd;
        for(Request request:requests) {
            results.add(new List<ProviderOption>());
            if(request==null || request.serviceId==null || request.startAt==null || request.endAt==null || request.endAt<=request.startAt) continue;
            services.add(request.serviceId);
            if(firstStart==null || request.startAt<firstStart) firstStart=request.startAt;
            if(lastEnd==null || request.endAt>lastEnd) lastEnd=request.endAt;
        }
        if(services.isEmpty()) return results;
        Map<String, Object> bindings = new Map<String, Object>{'services' => services};
        List<Account_Service__c> offers = Database.queryWithBinds(
            'SELECT Account_Id__c, Account_Id__r.Name, Service_Id__c FROM Account_Service__c '
            + 'WHERE Service_Id__c IN :services AND Is_Active__c=true '
            + 'AND Account_Id__r.Is_Provider__c=true AND Account_Id__r.Status__c=\'Active\' '
            + 'AND Service_Id__r.Is_Active__c=true ORDER BY Account_Id__r.Name, Account_Id__c', bindings, mode);
        if(offers.isEmpty()) return results;
        Set<Id> accounts=new Set<Id>();for(Account_Service__c offer:offers) accounts.add(offer.Account_Id__c);
        Map<Id,Set<Id>> required=new Map<Id,Set<Id>>();
        for(Service_Skill__c row:(List<Service_Skill__c>)Database.queryWithBinds('SELECT Service__c,Skill__c FROM Service_Skill__c WHERE Service__c IN :services',bindings,mode)) {
            if(!required.containsKey(row.Service__c)) required.put(row.Service__c,new Set<Id>());
            required.get(row.Service__c).add(row.Skill__c);
        }
        bindings.put('accounts', accounts);
        Map<Id,Set<Id>> possessed=new Map<Id,Set<Id>>();
        for(Account_Skill__c row:(List<Account_Skill__c>)Database.queryWithBinds('SELECT Account__c,Skill__c FROM Account_Skill__c WHERE Account__c IN :accounts',bindings,mode)) {
            if(!possessed.containsKey(row.Account__c)) possessed.put(row.Account__c,new Set<Id>());
            possessed.get(row.Account__c).add(row.Skill__c);
        }
        if(excludedInvoices==null) excludedInvoices=new Set<Id>();
        // Hidden bookings still occupy time. Return availability only, never their details.
        List<Invoice__c> busy=[SELECT Provider__c,Start__c,End__c FROM Invoice__c
            WHERE Provider__c IN :accounts AND Start__c<:lastEnd AND End__c>:firstStart
            AND Id NOT IN :excludedInvoices AND (Status__c=null OR Status__c!='Cancelled') WITH SYSTEM_MODE];
        for(Integer i=0;i<requests.size();i++) {
            Request request=requests[i];
            if(request==null || request.serviceId==null || request.startAt==null || request.endAt==null || request.endAt<=request.startAt) continue;
            Set<Id> seen=new Set<Id>();
            for(Account_Service__c offer:offers) {
                if(offer.Service_Id__c!=request.serviceId || seen.contains(offer.Account_Id__c)) continue;
                seen.add(offer.Account_Id__c);
                Set<Id> needs=required.get(request.serviceId);
                Set<Id> has=possessed.get(offer.Account_Id__c);
                if(needs!=null && !needs.isEmpty() && (has==null || !has.containsAll(needs))) continue;
                Boolean free=true;
                for(Invoice__c reservation:busy) {
                    if(reservation.Provider__c==offer.Account_Id__c && reservation.Start__c<request.endAt && reservation.End__c>request.startAt) {free=false;break;}
                }
                if(free) results[i].add(new ProviderOption(offer.Account_Id__c,offer.Account_Id__r.Name));
            }
        }
        return results;
    }
}
