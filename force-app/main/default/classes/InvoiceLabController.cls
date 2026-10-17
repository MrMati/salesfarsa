public with sharing class InvoiceLabController {
    public class TaxOption {
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public Decimal rate { get; set; }
        public TaxOption(String country,Decimal rate) {this.country=country;this.rate=rate;}
    }
    public class PreviewContext {
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public List<TaxOption> rates { get; set; }
    }
    @AuraEnabled(cacheable=true)
    public static PreviewContext getPreview(Id invoiceId) {
        List<Invoice__c> rows=[SELECT Amount__c,Country__c FROM Invoice__c WHERE Id=:invoiceId WITH USER_MODE];
        if(rows.isEmpty()) throw new AuraHandledException('Nie znaleziono faktury lub brak dostępu.');
        PreviewContext result=new PreviewContext();result.amount=rows[0].Amount__c;result.country=rows[0].Country__c;result.rates=new List<TaxOption>();
        Set<String> seen=new Set<String>();
        for(Country_Tax_Rate__c rate:[SELECT Country__c,Tax__c FROM Country_Tax_Rate__c WITH USER_MODE ORDER BY Country__c]) {
            if(seen.contains(rate.Country__c)) throw new AuraHandledException('Powielona konfiguracja stawki kraju '+rate.Country__c+'.');
            seen.add(rate.Country__c);result.rates.add(new TaxOption(rate.Country__c,rate.Tax__c));
        }
        return result;
    }
    @AuraEnabled(cacheable=true)
    public static Decimal getPropertyInvoiceTotal(Id propertyId) {
        if(propertyId==null) return 0;
        List<Property__c> visible=[SELECT Id FROM Property__c WHERE Id=:propertyId WITH USER_MODE];
        if(visible.isEmpty()) throw new AuraHandledException('Brak dostępu do nieruchomości.');
        AggregateResult result=[SELECT SUM(Gross_Amount__c) total FROM Invoice__c WHERE Property__c=:propertyId WITH USER_MODE];
        Decimal total=(Decimal)result.get('total');return total==null?0:total;
    }
    @AuraEnabled
    public static List<BookingEligibility.ProviderOption> getAvailableProviders(Id serviceId,Datetime startAt,Datetime endAt) {
        return BookingEligibility.findProviders(new List<BookingEligibility.Request>{new BookingEligibility.Request(serviceId,startAt,endAt)},null)[0];
    }
}
